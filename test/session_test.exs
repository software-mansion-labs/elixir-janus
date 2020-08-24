defmodule Janus.SessionTest do
  use ExUnit.Case
  alias Janus.{Session, Connection}

  @session_id 1
  @default_connection_id 0

  setup do
    # Fake transport will send back any message received to given pid
    transport_args =  {@default_connection_id, self()}
    {:ok, connection} = Connection.start_link(FakeTransport, transport_args, FakeHandler, [], [])

    %{connection: connection}
  end

  describe "Session should" do
    test "be created without error", %{connection: conn} do
      assert {:ok, sesison} = Session.start_link(@session_id, conn)
    end

    test "execute message by applying session_id to it", %{connection: conn} do
      {:ok, session} = Session.start_link(@session_id, conn)

      assert %{"session_id" => @session_id, "janus" => "keepalive"} =
               Session.execute_request(session, %{"janus" => "keepalive"})
    end

    test "send keep-alive message via connection after timeout given by connection module", %{
      connection: conn
    } do
      {:ok, _session} = Session.start_link(@session_id, conn)

      timeout = FakeTransport.keepalive_timeout()

      assert_receive {:message, %{"janus" => "keepalive", "session_id" => @session_id},
                      @default_connection_id},
                     2 * timeout
    end

    test "replaces old connection with a new one", %{connection: conn} do
      {:ok, session} = Session.start_link(@session_id, conn)

      new_connection_id = 1

      transport_args = {new_connection_id, self()}

      {:ok, connection} =
        Connection.start_link(FakeTransport, transport_args, FakeHandler, [], [])

      Session.update_connection(session, connection)
      timeout = FakeTransport.keepalive_timeout()

      assert_receive {:message, _, ^new_connection_id}, 2 * timeout
      refute_receive {:message, _, @default_connection_id}, 2 * timeout
    end
  end
end
