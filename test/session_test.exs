defmodule Janus.SessionTest do
  use ExUnit.Case, async: false

  import Mox
  alias Janus.{Session, Connection}
  alias Janus.Support.FakeHandler
  @timeout 100
  @session_id 1
  @request_response_pairs [
    {
      %{
        janus: :create
      },
      %{
        "janus" => "success",
        "data" => %{"id" => @session_id}
      }
    },
    {
      %{
        janus: :test,
        session_id: @session_id
      },
      %{
        "janus" => "success",
        "session_id" => @session_id,
        "data" => %{"session_id" => @session_id}
      }
    },
    {
      %{
        janus: :async_test,
        session_id: @session_id
      },
      %{
        "janus" => "event",
        "session_id" => @session_id,
        "plugindata" => %{
          "plugin" => "janus.plugin.videoroom",
          "data" => %{"session_id" => @session_id}
        },
        "jsep" => "jsep",
        "sender" => 213
      }
    },
    {
      %{
        janus: :ack,
        session_id: @session_id
      },
      %{
        "janus" => "ack"
      }
    },
    {
      %{
        janus: :keepalive,
        session_id: @session_id
      },
      %{
        "janus" => "ack"
      }
    }
  ]

  setup :set_mox_global

  setup do
    stub(DateTimeMock, :utc_now, &DateTime.utc_now/0)

    {:ok, connection} =
      Connection.start(Janus.Mock.Transport, @request_response_pairs, FakeHandler, {})

    on_exit(fn -> Process.exit(connection, :kill) end)

    %{connection: connection}
  end

  describe "Session should" do
    test "be created without error", %{connection: conn} do
      assert {:ok, session} = Session.start_link(conn, @timeout)
    end

    test "apply session_id to executed request", %{connection: conn} do
      {:ok, session} = Session.start_link(conn, @timeout)

      assert {:ok, %{"session_id" => @session_id}} =
               Session.execute_request(session, %{janus: :test})
    end

    test "ignore ack", %{connection: conn} do
      {:ok, session} = Session.start(conn, @timeout)
      Process.monitor(session)

      assert {timeout, _} = catch_exit(Session.execute_async_request(session, %{janus: :ack}, 10))

      assert {:timeout,
              {GenServer, :call,
               [_, {:call, %{janus: :ack, session_id: 1}, 10, :async_request}, _]}} = timeout

      assert_receive {:DOWN, _, :process, _, message_timeout}
      assert message_timeout == timeout
    end

    # TODO: Add a test for receiving two messages: ACK, then reply and the other way around

    test "apply session_id to executed async request", %{connection: conn} do
      {:ok, session} = Session.start_link(conn, @timeout)

      assert {:ok, %{"session_id" => @session_id, "jsep" => "jsep", "sender" => 213}} =
               Session.execute_async_request(session, %{janus: :async_test})
    end

    test "send keep-alive message via connection after keep-alive interval given by connection module",
         %{
           connection: conn
         } do
      Application.put_env(:elixir_janus, Janus.Mock.Transport, keepalive_interval: 100)

      {:ok, _session} = Session.start_link(conn, @timeout)

      interval = Janus.Mock.Transport.keepalive_interval()
      :erlang.trace(conn, true, [:receive])

      assert_receive {:trace, ^conn, :receive, %{"janus" => "ack"}}, 2 * interval
    end

    test "stop on connection exit", %{connection: conn} do
      {:ok, session} = Session.start(conn, @timeout)
      Process.monitor(session)
      Process.exit(conn, :kill)

      assert_receive {:DOWN, _ref, :process, ^session, {:connection, :killed}}, 5000
    end
  end
end
