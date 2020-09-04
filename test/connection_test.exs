defmodule Janus.ConnectionTest do
  use ExUnit.Case, async: true
  alias Janus.Connection
  alias Janus.Connection.Transaction

  alias Janus.Handler.Stub.{ValidHandler, BrokenHandler}
  alias Janus.Transport.Stub.{ValidTransport, BrokenTransport}

  import Janus.Connection
  import Janus.Test.Macro
  import Mock
  import Mox
  import ExUnit.CaptureLog

  @tag :tag
  @receive_timeout 20_000
  @receive_refute 2_000
  @now %DateTime{
    year: 2000,
    month: 2,
    day: 29,
    zone_abbr: "CET",
    hour: 23,
    minute: 0,
    second: 7,
    utc_offset: 3600,
    std_offset: 0,
    time_zone: "Etc/UTC"
  }

  setup do
    table = Transaction.init_transaction_call_table(__MODULE__)
    stub(DateTimeMock, :utc_now, fn -> @now end)
    [table: table]
  end

  describe "Connection should call handler's" do
    # check if all callbacks are called for their respective events
    test_callback(:created)
    test_callback(:attached)
    test_callback(:webrtc_up)
    test_callback(:audio_receiving)
    test_callback(:video_receiving)
    test_callback(:timeout)
  end

  describe "cleanup should" do
    test "keep valid transaction", %{table: table} do
      timeout = 20_000_000

      transaction = Transaction.insert_transaction(table, self(), timeout, @now)
      Connection.handle_info(:cleanup, state(pending_calls_table: table, cleanup_interval: 500))
      assert {:ok, _} = Transaction.transaction_status(table, transaction, @now)
      assert_receive :cleanup, @receive_timeout
    end

    test "flush expired transaction", %{table: table} do
      past = @now |> DateTime.add(-20_000, :second)
      transaction = Transaction.insert_transaction(table, self(), 0, past)

      Connection.handle_info(:cleanup, state(pending_calls_table: table, cleanup_interval: 500))
      assert {:error, :unknown_transaction} = Transaction.transaction_status(table, transaction)
      assert_receive :cleanup, @receive_timeout
    end
  end

  describe "handle info should" do
    test "respond to valid transaction", %{table: table} do
      timeout = 20_000_000
      transaction = Transaction.insert_transaction(table, from(), timeout, @now)
      response = %{"janus" => "ack"}
      message = Map.merge(response, %{"transaction" => transaction})

      Connection.handle_info(
        message,
        state(
          pending_calls_table: table,
          transport_module: ValidTransport
        )
      )

      assert_receive response, @receive_timeout

      assert {:error, :unknown_transaction} = Transaction.transaction_status(table, transaction)
    end

    test "not respond to expired transaction", %{table: table} do
      past = @now |> DateTime.add(-20_000, :second)
      transaction = Transaction.insert_transaction(table, from(), 0, past)
      response = %{"janus" => "ack"}
      message = Map.merge(response, %{"transaction" => transaction})

      Connection.handle_info(
        message,
        state(
          pending_calls_table: table,
          transport_module: ValidTransport
        )
      )

      refute_receive response, @receive_refute
      assert {:error, :unknown_transaction} = Transaction.transaction_status(table, transaction)
    end

    test "batched response", %{table: table} do
      batch_size = 5
      timeout = 20_000_000
      janus_response = %{"janus" => "success"}

      transactions =
        for _ <- 1..batch_size, do: Transaction.insert_transaction(table, from(), timeout)

      messages =
        for t <- transactions, do: Map.merge(janus_response, %{"data" => t, "transaction" => t})

      Connection.handle_info(
        messages,
        state(
          pending_calls_table: table,
          transport_module: ValidTransport
        )
      )

      for t <- transactions, do: assert_next_receive(t, @receive_timeout)
    end
  end

  describe "init should" do
    test "fail if transport's connect fails" do
      assert {:stop, {:connect, "transport"}} =
               Connection.init({BrokenTransport, [], ValidHandler, []})
    end

    test "fail if handler's init fails" do
      assert {:stop, {:handler, "handler"}} =
               Connection.init({ValidTransport, [], BrokenHandler, []})
    end

    test "initialize state" do
      cleanup_timeout = 0

      assert {:ok,
              state(
                transport_module: ValidTransport,
                transport_state: "transport",
                handler_module: ValidHandler,
                handler_state: "handler",
                pending_calls_table: table
              )} = Connection.init({ValidTransport, [], ValidHandler, []}, cleanup_timeout)

      assert_receive :cleanup, @receive_timeout
      assert table in :ets.all()
    end
  end

  describe "call should" do
    defmodule ValidTransportMock do
      def send(_, _, _), do: {}
    end

    test "send transaction through transport and add transaction to transaction store", %{
      table: table
    } do
      with_mock(ValidTransportMock, send: fn _payload, _timeout, _state -> {:ok, "dummy"} end) do
        timeout = 5000
        payload = %{payload: 'data'}

        logs =
          capture_log(fn ->
            Connection.handle_call(
              {:call, payload, timeout},
              self(),
              state(
                transport_module: ValidTransportMock,
                transport_state: [],
                pending_calls_table: table
              )
            )
          end)

        transaction = Regex.run(~r/"\S*"/, logs) |> to_string |> String.replace(~s("), "")

        assert [{^transaction, _, _}] = :ets.lookup(table, transaction)
        assert logs =~ inspect(payload)
        assert_called(ValidTransportMock.send(:_, :_, :_))
      end
    end

    test "raise an error after timeout" do
      {:ok, pid} =
        Connection.start_link(
          ValidTransport,
          [],
          ValidHandler,
          []
        )

      DateTimeMock
      |> allow(self(), pid)

      catch_exit(Connection.call(pid, %{}, 500))
    end
  end

  defp from(), do: {self(), @tag}
end
