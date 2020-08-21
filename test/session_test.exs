defmodule SessionTest do
  use ExUnit.Case

  @session_id 1
  @default_connection_id 0

  setup do
    # Fake transport will send back any message received to given pid
    {:ok, connection} =
      Janus.Connection.start_link(
        FakeTransport,
        {@default_connection_id, self()},
        FakeHandler,
        [],
        []
      )

    %{connection: connection}
  end

  describe "Session should" do
    test "be created without error", %{connection: conn} do
      assert {:ok, sesison} = Janus.Session.start_link(@session_id, conn, [])
    end

    test "apply session_id and other fields to message", %{connection: conn} do
      {:ok, session} = Janus.Session.start_link(@session_id, conn, [])

      assert %{"session_id" => @session_id} = Janus.Session.apply_fields(%{}, session)

      assert %{"session_id" => @session_id, "handle_id" => 0} =
               Janus.Session.apply_fields(%{}, session, handle_id: 0)
    end

    test "send keep-alive message via connection after timeout given by connection module", %{
      connection: conn
    } do
      {:ok, _session} = Janus.Session.start_link(@session_id, conn, [])

      {true, timeout} = FakeTransport.needs_keep_alive?()

      assert_receive {:message, %{"janus" => "keepalive", "session_id" => @session_id},
                      @default_connection_id},
                     2 * timeout
    end

    test "replaces old connection with a new one", %{connection: conn} do
      {:ok, session} = Janus.Session.start_link(@session_id, conn, [])

      new_connection_id = 1

      {:ok, connection} =
        Janus.Connection.start_link(
          FakeTransport,
          {new_connection_id, self()},
          FakeHandler,
          [],
          []
        )

      Janus.Session.update_connection(session, connection)
      {true, timeout} = FakeTransport.needs_keep_alive?()

      assert_receive {:message, _, ^new_connection_id}, 2 * timeout
      refute_receive {:message, _, @default_connection_id}, 2 * timeout
    end
  end
end
