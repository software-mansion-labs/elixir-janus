defmodule Janus.Mock.Transport do
  @moduledoc """
  Allows to mock transport module in a predictable way.

  One has to pass list of tuples representing request-response pairs to `c:connect/1` callback which will put them in the returned state.
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
      Janus.Mock.Transport,
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
  config :elixir_janus, Janus.Mock.Transport, keepalive_interval: 100
  ```
  """

  @behaviour Janus.Transport

  @impl true
  def connect(pairs) do
    Janus.Mock.assert_pairs_shape(pairs)
    {:ok, %{pairs: pairs}}
  end

  @impl true
  def send(payload, _timeout, %{pairs: pairs} = state) do
    {transaction, payload} = Map.pop(payload, :transaction)

    {response, pairs} = Janus.Mock.get_response(payload, pairs)

    response =
      if not is_nil(transaction) do
        Map.put(response, "transaction", transaction)
      else
        response
      end

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
end
