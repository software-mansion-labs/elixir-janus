defmodule Janus.API.MonitorTest do
  use ExUnit.Case, async: false
  alias Janus.Connection
  alias Janus.MockTransport
  alias Janus.API.Monitor
  import Mox

  defmodule DummyHandler do
    use Janus.Handler
  end

  @session_id 1
  @handle_id 1
  @secret "secret"

  @request_result_pairs [
    # list sessions
    {
      %{
        janus: :list_sessions,
        admin_secret: @secret
      },
      %{
        "janus" => "success",
        "sessions" => [1, 2, 3]
      }
    },
    # list session's handles
    {
      %{
        janus: :list_handles,
        session_id: @session_id,
        admin_secret: @secret
      },
      %{
        "janus" => "success",
        "session_id" => @session_id,
        "handles" => [1, 2, 3]
      }
    },
    # get handle's info
    {
      %{
        janus: :handle_info,
        session_id: @session_id,
        handle_id: @handle_id,
        admin_secret: @secret
      },
      %{
        "janus" => "success",
        "session_id" => @session_id,
        "handle_id" => @handle_id,
        "info" => %{}
      }
    }
  ]

  @error_request_result_pairs [
    {
      %{
        janus: :list_sessions,
        admin_secret: @secret
      },
      %{
        "janus" => "error",
        "error" => %{"code" => 403, "reason" => "unauthorized"}
      }
    },
    {
      %{
        janus: :list_handles,
        session_id: @session_id,
        admin_secret: @secret
      },
      %{
        "janus" => "error",
        "error" => %{"code" => 403, "reason" => "unauthorized"}
      }
    },
    {
      %{
        janus: :handle_info,
        session_id: @session_id,
        handle_id: @handle_id,
        admin_secret: @secret
      },
      %{
        "janus" => "error",
        "error" => %{"code" => 403, "reason" => "unauthorized"}
      }
    }
  ]

  setup :set_mox_global

  setup do
    stub(DateTimeMock, :utc_now, &DateTime.utc_now/0)

    {:ok, connection} =
      Connection.start_link(MockTransport, @request_result_pairs, DummyHandler, {})

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
        Connection.start_link(MockTransport, @error_request_result_pairs, DummyHandler, {})

      assert {:error, _error} = Monitor.list_sessions(connection, @secret)
      assert {:error, _error} = Monitor.list_handles(connection, @session_id, @secret)
      assert {:error, _error} = Monitor.handle_info(connection, @session_id, @handle_id, @secret)
    end
  end
end
