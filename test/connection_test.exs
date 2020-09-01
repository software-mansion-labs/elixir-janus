defmodule Janus.ConnectionTest do
  use ExUnit.Case
  alias Janus.Connection
  alias Janus.ConnectionTest.Stub.{ValidHandler, BrokenHandler, ValidTransport, BrokenTransport}
  alias Janus.Connection.Transaction
  import Janus.Connection
  import Janus.HandlerTest.CallbackHelper
  import Mock

  import ExUnit.CaptureLog

  @receive_timeout 20_000

  describe "Connection should call handler's" do
    # check if all callbacks are called for their respective events
    test_callback(:created)
    test_callback(:attached)
    test_callback(:webrtc_up)
    test_callback(:audio_receiving)
    test_callback(:video_receiving)
    test_callback(:timeout)
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
    test "send transaction through transport and add transaction to transaction store" do
      with_mock(ValidTransport, send: fn _payload, _timeout, _state -> {:ok, "dummy"} end) do
        timeout = 5000
        table = Transaction.init_transaction_call_table()
        payload = %{payload: 'data'}

        logs =
          capture_log(fn ->
            Connection.handle_call(
              {:call, payload, timeout},
              self(),
              state(
                transport_module: ValidTransport,
                transport_state: [],
                pending_calls_table: table
              )
            )
          end)

        transaction = Regex.run(~r/"\S*"/, logs) |> to_string |> String.replace(~s("), "")

        assert [{^transaction, _, _}] = :ets.lookup(table, transaction)
        assert logs =~ inspect(payload)
        assert_called(ValidTransport.send(:_, :_, :_))
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

      catch_exit(Connection.call(pid, %{}, 500))
    end
  end
end
