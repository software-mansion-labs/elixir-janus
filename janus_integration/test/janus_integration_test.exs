defmodule Janus.Integration.Test do
  use ExUnit.Case
  alias Janus.Connection
  alias Janus.Session
  alias Janus.API.Monitor
  alias Janus.Transport.WS
  alias Janus.Transport.WS.Adapters.WebSockex

  @secret "janusoverlord"

  describe "Connection should" do
    setup do
      url = Application.fetch_env!(:janus_integration, :config)[:gateway_ws_url]
      %{url: url}
    end

    test "connect with the gateway", %{url: url} do
      assert {:ok, connection} = Connection.start_link(WS, {url, WebSockex, []}, DummyHandler, {})
    end

    test "send message and receive response", %{url: url} do
      assert {:ok, connection} = Connection.start_link(WS, {url, WebSockex, []}, DummyHandler, {})

      assert {:ok, %{"id" => _id}} = Connection.call(connection, %{janus: :create})
    end
  end

  describe "Session should" do
    setup do
      url = Application.fetch_env!(:janus_integration, :config)[:gateway_ws_url]
      assert {:ok, connection} = Connection.start_link(WS, {url, WebSockex, []}, DummyHandler, {})
      %{connection: connection}
    end

    test "request gateway to create new session", %{connection: connection} do
      assert {:ok, session} = Session.start_link(connection)

      assert Session.get_session_id(session) |> is_integer
    end

    test "request gateway to create plugin handle", %{connection: connection} do
      assert {:ok, session} = Session.start_link(connection)
      assert {:ok, handle_id} = Session.session_attach(session, "janus.plugin.videoroom")
      assert is_integer(handle_id)
    end
  end

  describe "Monitor api should" do
    setup do
      [gateway_ws_url: url, gateway_ws_admin_url: admin_url] =
        Application.fetch_env!(:janus_integration, :config)

      {:ok, connection} =
        Connection.start_link(WS, {url, WebSockex, [admin_api?: false]}, DummyHandler, {})

      {:ok, admin_connection} =
        Connection.start_link(WS, {admin_url, WebSockex, [admin_api?: true]}, DummyHandler, {})

      %{admin_connection: admin_connection, connection: connection}
    end

    test "return list of sessions and  sessions' handles", %{
      admin_connection: admin_connection,
      connection: connection
    } do
      # create session and handle
      assert {:ok, session} = Session.start_link(connection)
      assert {:ok, handle} = Session.session_attach(session, "janus.plugin.videoroom")
      session_id = Session.get_session_id(session)

      assert {:ok, handles} = Monitor.list_handles(admin_connection, session_id, @secret)
      assert [handle] = handles

      assert {:ok, sessions} = Monitor.list_sessions(admin_connection, @secret)
      assert [session_id] = sessions
    end

    test "return handle info", %{admin_connection: admin_connection, connection: connection} do
      assert {:ok, session} = Session.start_link(connection)
      session_id = Session.get_session_id(session)
      assert {:ok, handle_id} = Session.session_attach(session, "janus.plugin.videoroom")

      assert {:ok, info} = Monitor.handle_info(admin_connection, session_id, handle_id, @secret)

      assert %{handle_id: ^handle_id, session_id: ^session_id} = info
    end
  end
end
