defmodule Janus.SessionTest do
  use ExUnit.Case
  alias Janus.{Session, Connection}

  @session_id 1
  @default_connection_id 0
  @timeout 100

  setup do
    # Fake transport will send back any message received to given pid
    transport_args = {@default_connection_id}
    {:ok, connection} = Connection.start_link(FakeTransport, transport_args, FakeHandler, [], [])

    %{connection: connection}
  end

  describe "Session should" do
    test "be created without error", %{connection: conn} do
      assert {:ok, sesison} = Session.start_link(conn, @timeout)
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
      {:ok, _session} = Session.start_link(conn, @timeout)

      interval = FakeTransport.keepalive_interval()
      :erlang.trace(conn, true, [:receive])

      assert_receive {:trace, ^conn, :receive, %{"janus" => "ack"}}, 2 * interval
    end
  end
end
