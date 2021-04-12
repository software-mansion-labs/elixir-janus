defmodule Janus.ConnectionTest do
  use ExUnit.Case, async: true
  alias Janus.Connection
  alias Janus.Connection.Transaction
  alias Janus.Mock.Transport, as: MockTransport
  alias Janus.Support.{ValidHandler, BrokenHandler, BrokenTransport}

  import Janus.Connection
  import Janus.Support.Macro
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

    state =
      state(
        pending_calls_table: table,
        transport_module: MockTransport
      )

    [table: table, state: state]
  end

  setup_all do
    conn_args = %{
      transport_module: MockTransport,
      transport_args: [],
      handler_module: ValidHandler,
      handler_args: []
    }

    [conn_args: conn_args]
  end

  describe "Connection should call handler's" do
    # check if all callbacks are called for their respective events
    test_callback(:created)
    test_callback(:attached)
    test_callback(:webrtc_up, 0)
    test_callback(:webrtc_up, 1)
    test_callback(:webrtc_down, 0)
    test_callback(:webrtc_down, 1)
    test_callback(:slow_link, 0)
    test_callback(:slow_link, 1)
    test_callback(:audio_receiving)
    test_callback(:video_receiving, 0)
    test_callback(:video_receiving, 1)
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
      transaction = Transaction.insert_transaction(table, self(), 0, :sync_request, past)

      Connection.handle_info(:cleanup, state(pending_calls_table: table, cleanup_interval: 500))
      assert {:error, :unknown_transaction} = Transaction.transaction_status(table, transaction)
      assert_receive :cleanup, @receive_timeout
    end
  end

  describe "handle info should" do
    test "respond to valid transaction", %{table: table, state: state} do
      timeout = 20_000_000
      transaction = Transaction.insert_transaction(table, from(), timeout, @now)
      response = %{"janus" => "ack"}
      message = Map.merge(response, %{"transaction" => transaction})

      Connection.handle_info(message, state)

      assert_receive response, @receive_timeout
      assert {:error, :unknown_transaction} = Transaction.transaction_status(table, transaction)
    end

    test "not respond to expired transaction", %{table: table, state: state} do
      past = @now |> DateTime.add(-20_000, :second)
      transaction = Transaction.insert_transaction(table, from(), 0, :sync_request, past)
      response = %{"janus" => "ack"}
      message = Map.merge(response, %{"transaction" => transaction})

      Connection.handle_info(message, state)

      refute_receive ^response, @receive_refute
      assert {:error, :unknown_transaction} = Transaction.transaction_status(table, transaction)
    end

    test "batched response", %{table: table, state: state} do
      batch_size = 5
      timeout = 20_000_000
      janus_response = %{"janus" => "success"}

      transactions =
        for _ <- 1..batch_size,
            do: Transaction.insert_transaction(table, from(), timeout, :sync_request)

      messages =
        for t <- transactions, do: Map.merge(janus_response, %{"data" => t, "transaction" => t})

      Connection.handle_info(messages, state)

      for t <- transactions, do: assert_next_receive(t, @receive_timeout)
    end
  end

  describe "init should" do
    test "fail if transport's connect fails", %{conn_args: conn_args} do
      conn_args = %{conn_args | transport_module: BrokenTransport}
      assert {:stop, {:connect, "transport"}} = Connection.init(conn_args)
    end

    test "fail if handler's init fails", %{conn_args: conn_args} do
      conn_args = %{conn_args | handler_module: BrokenHandler}
      assert {:stop, {:handler, "handler"}} = Connection.init(conn_args)
    end

    test "initialize state", %{conn_args: conn_args} do
      cleanup_interval = 0
      conn_args = Map.put(conn_args, :cleanup_interval, cleanup_interval)

      assert {:ok,
              state(
                transport_module: MockTransport,
                transport_state: %{pairs: ''},
                handler_module: ValidHandler,
                handler_state: {},
                pending_calls_table: table
              )} = Connection.init(conn_args)

      assert_receive :cleanup, @receive_timeout
      assert table in :ets.all()
    end
  end

  describe "call should" do
    defmodule ValidTransportMock do
      def send(_, _, _), do: {}
    end

    test "send transaction through transport and add transaction to transaction store", %{
      table: table,
      state: state
    } do
      # TODO: replace this mock with MockTransports' length of response queue when implemented
      with_mock(ValidTransportMock, send: fn _payload, _timeout, _state -> {:ok, "dummy"} end) do
        timeout = 5000
        payload = %{payload: 'data'}

        logs =
          capture_log(fn ->
            Connection.handle_call(
              {:call, payload, timeout, :sync_request},
              self(),
              state(state, transport_module: ValidTransportMock)
            )
          end)

        transaction = Regex.run(~r/"\S*"/, logs) |> to_string |> String.replace(~s("), "")

        assert [{^transaction, _, _, _}] = :ets.lookup(table, transaction)
        assert logs =~ inspect(payload)
        assert_called(ValidTransportMock.send(:_, :_, :_))
      end
    end

    test "raise an error after timeout" do
      {:ok, pid} =
        Connection.start_link(
          MockTransport,
          [{%{}, %{}}],
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
