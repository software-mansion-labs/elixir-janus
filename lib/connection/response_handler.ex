defmodule Janus.Connection.ResponseHandler do
  require Logger

  alias Janus.Connection.Transaction

  def handle_response(response, transaction, pending_calls_table) do
    transaction_status = Transaction.transaction_status(pending_calls_table, transaction)

    case transaction_status do
      {:ok, from} ->
        GenServer.reply(from, response)
        :ets.delete(pending_calls_table, transaction)

      {:error, :outdated} ->
        :ets.delete(pending_calls_table, transaction)
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
