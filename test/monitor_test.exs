defmodule Janus.API.MonitorTest do
  use ExUnit.Case
  alias Janus.Connection
  alias Janus.API.Monitor
  alias Janus.Transport.Stub.FakeTransport

  import Mox

  defmodule DummyHandler do
    use Janus.Handler
  end

  @session_id FakeTransport.default_session_id()
  @handle_id 1
  @secret "secret"

  setup :set_mox_global

  setup do
    stub(DateTimeMock, :utc_now, &DateTime.utc_now/0)

    {:ok, connection} =
      Connection.start_link(FakeTransport, [fail_admin_api: false], DummyHandler, {})

    %{connection: connection}
  end

  describe "Monitor should" do
    test "return list of sessions", %{connection: connection} do
      assert {:ok, sessions} = Monitor.list_sessions(connection, @secret)
      assert is_list(sessions)
    end

    test "return list of session's handles", %{connection: connection} do
      assert {:ok, handles} = Monitor.list_handles(connection, @session_id, @secret)
      assert is_list(handles)
    end

    test "return handle info", %{connection: connection} do
      assert {:ok, info} = Monitor.handle_info(connection, @session_id, @handle_id, @secret)
      assert is_map(info)
    end

    test "handle errors returned by connection" do
      {:ok, connection} =
        Connection.start_link(FakeTransport, [fail_admin_api: true], DummyHandler, {})

      assert {:error, _error} = Monitor.list_sessions(connection, @secret)
      assert {:error, _error} = Monitor.list_handles(connection, @session_id, @secret)
      assert {:error, _error} = Monitor.handle_info(connection, @session_id, @handle_id, @secret)
    end
  end
end
