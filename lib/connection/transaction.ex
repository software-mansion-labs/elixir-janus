defmodule Janus.Connection.Transaction do
  @moduledoc false

  @transaction_length 32
  @insert_tries 5

  require Logger
  # We use duplicate_bag as we ensure key uniqueness by ourselves and it is faster.
  # See https://www.phoenixframework.org/blog/the-road-to-2-million-websocket-connections
  @spec init_transaction_call_table(atom()) :: :ets.tab()
  def init_transaction_call_table(pending_calls_table \\ :pending_calls) do
    :ets.new(pending_calls_table, [:duplicate_bag, :private])
  end

  @spec insert_transaction(
          :ets.tab(),
          GenServer.from(),
          integer,
          DateTime.t(),
          integer,
          (non_neg_integer -> binary)
        ) :: binary

  def insert_transaction(
        pending_calls_table,
        from,
        timeout,
        timestamp \\ DateTime.utc_now(),
        tries \\ @insert_tries,
        transaction_generator \\ &:crypto.strong_rand_bytes/1
      )

  def insert_transaction(
        pending_calls_table,
        from,
        timeout,
        timestamp,
        tries,
        transaction_generator
      )
      when tries > 0 do
    transaction = generate_transaction!(transaction_generator)
    expires = expires_at(timestamp, timeout)

    if :ets.insert_new(pending_calls_table, {transaction, from, expires}) do
      transaction
    else
      "[#{__MODULE__} #{inspect(self())}] Generated already existing transaction: #{transaction}"
      |> Logger.warn()

      insert_transaction(
        pending_calls_table,
        from,
        timeout,
        timestamp,
        tries - 1,
        transaction_generator
      )
    end
  end

  def insert_transaction(_pending_calls_table, _from, _timeout, _timestamp, 0, _generator),
    do: raise("Could not insert transaction")

  defp expires_at(timestamp, timeout) do
    timestamp
    |> DateTime.add(timeout, :millisecond)
    |> DateTime.to_unix(:millisecond)
  end

  # Generates a transaction ID for the payload and ensures that it is unused
  @spec generate_transaction!((non_neg_integer -> binary)) :: binary
  defp generate_transaction!(transaction_generator) do
    transaction_generator.(@transaction_length) |> Base.encode64()
  end

  @spec transaction_status(:ets.tab(), binary, DateTime.t()) ::
          {:error, :outdated | :unknown_transaction} | {:ok, GenServer.from()}
  def transaction_status(pending_calls_table, transaction, timestamp \\ DateTime.utc_now()) do
    case :ets.lookup(pending_calls_table, transaction) do
      [{_transaction, from, expires_at}] ->
        if timestamp |> DateTime.to_unix(:millisecond) > expires_at do
          {:error, :outdated}
        else
          {:ok, from}
        end

      [] ->
        {:error, :unknown_transaction}
    end
  end

  @spec cleanup_old_transactions(:ets.tab(), DateTime.t()) :: boolean
  def cleanup_old_transactions(pending_calls_table, timestamp \\ DateTime.utc_now()) do
    require Ex2ms
    timestamp = timestamp |> DateTime.to_unix(:millisecond)

    match_spec =
      Ex2ms.fun do
        {_transaction, _from, expires_at} -> expires_at < ^timestamp
      end

    case :ets.select_delete(pending_calls_table, match_spec) do
      0 ->
        Logger.debug("[#{__MODULE__} #{inspect(self())}] Cleanup: no outdated transactions found")
        false

      count ->
        "[#{__MODULE__} #{inspect(self())}] Cleanup: cleaned up #{count} outdated transaction(s)"
        |> Logger.warn()

        true
    end
  end

  @spec handle_transaction({:ok, any} | {:error, any}, binary, :ets.tab()) :: :ok
  def handle_transaction(response, transaction, pending_calls_table) do
    transaction_status = transaction_status(pending_calls_table, transaction)

    case transaction_status do
      {:ok, from} ->
        GenServer.reply(from, response)
        :ets.delete(pending_calls_table, transaction)

      {:error, :outdated} ->
        :ets.delete(pending_calls_table, transaction)

      {:error, :unknown_transaction} ->
        # NOOP
        nil
    end

    call_result =
      case response do
        {:ok, _} -> "OK"
        {:error, _} -> "ERROR"
      end

    log_transaction_status(transaction_status, transaction, response, call_result)
  end

  defp log_transaction_status({:ok, _from}, transaction, data, call_result) do
    "[#{__MODULE__} #{inspect(self())}] Call #{call_result}: transaction = #{inspect(transaction)}, data = #{
      inspect(data)
    }"
    |> Logger.debug()
  end

  defp log_transaction_status({:error, reason}, transaction, data, call_result) do
    "[#{__MODULE__} #{inspect(self())}] Received #{call_result} reply to the #{reason} call: transaction = #{
      inspect(transaction)
    }, data = #{inspect(data)}"
    |> Logger.warn()
  end
end
