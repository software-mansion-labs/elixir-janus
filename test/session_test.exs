defmodule Janus.SessionTest do
  use ExUnit.Case

  import Mox
  alias Janus.{Session, Connection}
  alias Janus.Handler.Stub.FakeHandler
  alias Janus.Transport.Stub.FakeTransport
  @default_connection_id 0
  @timeout 1_000

  setup do
    DateTimeMock
    |> stub(:utc_now, fn -> DateTime.utc_now() end)

    transport_args = {@default_connection_id}
    {:ok, connection} = Connection.start(FakeTransport, transport_args, FakeHandler, [], [])

    set_mox_global()

    %{connection: connection}
  end

  describe "Session should" do
    test "be created without error", %{connection: conn} do
      assert {:ok, session} = Session.start_link(conn, @timeout)
    end

    test "apply session_id to executed request", %{connection: conn} do
      {:ok, session} = Session.start_link(conn, @timeout)

      session_id = FakeTransport.default_session_id()

      assert {:ok, %{"session_id" => ^session_id}} =
               Session.execute_request(session, %{janus: :test})
    end

    test "send keep-alive message via connection after keep-alive interval given by connection module",
         %{
           connection: conn
         } do
      {:ok, session} = Session.start_link(conn, @timeout)

      interval = FakeTransport.keepalive_interval()
      :erlang.trace(conn, true, [:receive])

      assert_receive {:trace, ^conn, :receive, %{"janus" => "ack"}}, 2 * interval
    end

    @tag :capture_log
    test "stop on connection exit", %{connection: conn} do
      {:ok, session} = Session.start(conn, @timeout)

      Process.monitor(session)
      Process.exit(conn, :kill)

      assert_receive {:DOWN, _ref, :process, ^session, {:connection, :killed}}, 5000
    end
  end
end
