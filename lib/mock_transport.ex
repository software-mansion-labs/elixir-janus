defmodule Janus.MockTransport do
  @moduledoc """
  Allows to mock transport module in a predictable way.

  One has to pass list of tuples representing request-response pairs to `c:connect/1` callback which will put them in returned state.
  For each `c:send/3` invocation `#{inspect(__MODULE__)}` will try to match on the first occurrence of given request and return
  corresponding response. The matched tuple is then removed returned state.

  The module takes into consideration that each request will have `:transaction` field added by `Janus.Connection` module,
  therefore it will extract `:transaction` field and put it to the corresponding response.

  ## Example

  ```elixir
  defmodule Test do
    alias Janus.{Connection, Session}

    defmodule Handler, do: use Janus.Handler

    @request_response_pairs [
      {
        %{
          janus: :create
        },
        %{
          "janus" => "success",
          "data" => %{"id" => "session id"}
        }
      }
    ]

  def test() do
    {:ok, conn} = Connection.start_link(
      Janus.MockTransport,
      @request_response_pairs,
      Handler,
      {}
    )

    # session module will send `create` request on start
    # then mock transport will match on this request and
    # respond with a success response containing session id
    {:ok, session} = Session.start_link(conn)
    end
  end
  ```

  ## Keep alive interval

  To mock `c:keepalive_interval/0` callback one has to set proper config variable.
  ```elixir
  config :elixir_janus, Janus.MockTransport, keepalive_interval: 100
  ```
  """

  @behaviour Janus.Transport

  require Record

  @typedoc """
  Tuple element containing request and response maps.

  Response map should be compatible with formats handled by `Janus.Connection`, otherwise
  it will not be handled by mentioned module and will crash `Janus.Connection` process.
  """
  @type request_response_pair :: {request :: map(), response :: map()}

  @impl true
  def connect(pairs) do
    {:ok, %{pairs: pairs}}
  end

  @impl true
  def send(%{transaction: transaction} = payload, _timeout, %{pairs: pairs} = state) do
    payload_without_transaction = Map.delete(payload, :transaction)

    {response, pairs} = get_response(payload_without_transaction, pairs)

    send(self(), Map.put(response, "transaction", transaction))

    {:ok, %{state | pairs: pairs}}
  end

  @impl true
  def send(payload, _timeout, %{pairs: pairs} = state) do
    {response, pairs} = get_response(payload, pairs)
    send(self(), response)

    {:ok, %{state | pairs: pairs}}
  end

  @impl true
  def handle_info(message, state) do
    {:ok, message, state}
  end

  @impl true
  def keepalive_interval() do
    case Application.get_env(:elixir_janus, __MODULE__, nil) do
      nil -> nil
      [keepalive_interval: interval] -> interval
    end
  end

  defp get_response(payload, pairs) do
    case List.keytake(pairs, payload, 0) do
      nil ->
        raise ArgumentError,
              "#{inspect(__MODULE__)}: payload's corresponding response has not been found, got: #{
                inspect(payload)
              }"

      {{_, response}, pairs} ->
        {response, pairs}
    end
  end
end
