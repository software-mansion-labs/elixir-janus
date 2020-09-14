defmodule Janus.MockTransport do
  @moduledoc """
  Allows to mock transport module in a predictable way.

  User has to pass list of tuples to `c:connect/1` callback that will represent
  request and its expected response in form of `t:request_result_pair/0`.
  For each send callback invoked module will try to find first tuple to contain
  given request and return corresponding response. Given tuple will then be deleted from list
  of request-response pairs.

  `Janus.Connection` adds `transaction` field to every request, `#{inspect(__MODULE__)}` will
  extract it and add it back again to given response map.


  `c:keepalive_interval` can be configured via config variable e.g.
  ```elixir
  config :elixir_janus, Janus.MockTransport, keepalive_interval: 100
  ```
  """

  @behaviour Janus.Transport

  @type request_result_pair :: {request :: map(), response :: map()}

  @impl true
  def connect(results) do
    {:ok, results}
  end

  @impl true
  def send(payload, _timeout, results) do
    transaction = payload.transaction
    payload_without_transaction = Map.delete(payload, :transaction)
    {{_, response}, results} = List.keytake(results, payload_without_transaction, 0)

    send(self(), Map.put(response, "transaction", transaction))

    {:ok, results}
  end

  @impl true
  def handle_info(message, responses) do
    {:ok, message, responses}
  end

  @impl true
  def keepalive_interval() do
    case Application.get_env(:elixir_janus, __MODULE__, nil) do
      nil -> nil
      [keepalive_interval: interval] -> interval
    end
  end
end
