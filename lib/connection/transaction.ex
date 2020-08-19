defmodule Janus.Connection.Transaction do
  @moduledoc false

  require Logger
  @spec init_transaction_call_table() :: :ets.tab()
  def init_transaction_call_table() do
    :ets.new(:pending_calls, [:duplicate_bag, :private])
  end

  # Generates a transaction ID for the payload and ensures that it is unused
  @spec generate_transaction!(:ets.tab()) :: binary
  def generate_transaction!(pending_calls_table) do
    transaction = :crypto.strong_rand_bytes(32) |> Base.encode64()

    case :ets.lookup(pending_calls_table, transaction) do
      [] ->
        transaction

      _ ->
        generate_transaction!(pending_calls_table)
    end
  end

  @spec insert_transaction(:ets.tab(), binary, GenServer.from(), integer) :: true
  def insert_transaction(pending_calls_table, transaction, from, timeout) do
    expires_at =
      DateTime.utc_now()
      |> DateTime.add(timeout, :millisecond)
      |> DateTime.to_unix(:millisecond)

    # Maybe insert new instead
    :ets.insert(pending_calls_table, {transaction, from, expires_at})
  end

  @spec transaction_status(:ets.tab(), binary) ::
          {:error, :outdated | :unknown} | {:ok, GenServer.from()}
  def transaction_status(pending_calls_table, transaction) do
    case :ets.lookup(pending_calls_table, transaction) do
      [{_transaction, from, expires_at}] ->
        if DateTime.utc_now() |> DateTime.to_unix(:millisecond) > expires_at do
          {:error, :outdated}
        else
          {:ok, from}
        end

      [] ->
        {:error, :unknown}
    end
  end

  @spec cleanup_old_transactions(:ets.tab()) :: :ok
  def cleanup_old_transactions(pending_calls_table) do
    require Ex2ms
    now = DateTime.utc_now() |> DateTime.to_unix(:millisecond)

    match_spec =
      Ex2ms.fun do
        {_transaction, _from, expires_at} -> expires_at > ^now
      end

    case :ets.select_delete(pending_calls_table, match_spec) do
      0 ->
        Logger.debug("[#{__MODULE__} #{inspect(self())}] Cleanup: no outdated transactions found")

      count ->
        "[#{__MODULE__} #{inspect(self())}] Cleanup: cleaned up #{count} outdated transaction(s)"
        |> Logger.debug()
    end
  end
end
