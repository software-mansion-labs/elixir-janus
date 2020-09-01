defmodule Janus.API.Monitor do
  alias Janus.Session
  alias Janus.Connection
  alias Janus.API

  @type handle_info :: %{
          session_id: non_neg_integer,
          session_last_activity: non_neg_integer,
          session_transport: binary,
          handle_id: non_neg_integer,
          opaque_id: binary,
          loop_running: boolean,
          created: non_neg_integer,
          current_time: non_neg_integer,
          plugin: binary,
          plugin_specific: map,
          flags: map,
          agent_created: non_neg_integer,
          ice_mode: binary,
          ice_role: binary,
          sdps: map,
          queued_packets: 0,
          streams: list
        }

  @doc """
  Requests gateway to list all existing sessions.
  """
  @spec list_sessions(GenServer.server(), binary | nil) ::
          {:error, atom} | {:ok, list(non_neg_integer())}
  def list_sessions(connection, admin_secret \\ nil) do
    message =
      %{janus: :list_sessions}
      |> add_optional_param(:admin_secret, admin_secret)

    with {:ok,
          %{
            "janus" => "success",
            "sessions" => list
          }} <-
           Connection.call(connection, message) do
      {:ok, list}
    end
    |> API.handle_api_error()
  end

  @doc """
  Requests gateway to list all handles currently active within given session.
  """
  @spec list_handles(GenServer.server(), Session.session_id_t(), binary | nil) ::
          {:error, atom} | {:ok, list(non_neg_integer())}
  def list_handles(connection, session_id, admin_secret \\ nil) do
    message =
      %{
        janus: :list_handles,
        session_id: session_id
      }
      |> add_optional_param(:admin_secret, admin_secret)

    with {:ok,
          %{
            "janus" => "success",
            "handles" => list
          }} <-
           Connection.call(connection, message) do
      {:ok, list}
    end
    |> API.handle_api_error()
  end

  @doc """
  Requests gateway to get information about given handle.
  """
  @spec handle_info(
          GenServer.server(),
          Session.session_id_t(),
          Session.plugin_handle_id(),
          binary | nil
        ) ::
          {:error, :atom} | {:ok, handle_info}
  def handle_info(connection, session_id, handle_id, admin_secret \\ nil) do
    message =
      %{
        janus: :handle_info,
        session_id: session_id,
        handle_id: handle_id
      }
      |> add_optional_param(:admin_secret, admin_secret)

    with {:ok,
          %{
            "janus" => "success",
            "info" => info
          }} <-
           Connection.call(connection, message) do
      accepted_keys = [
        "session_id",
        "session_last_activity",
        "session_transport",
        "handle_id",
        "opaque_id",
        "loop-running",
        "created",
        "current_time",
        "plugin",
        "plugin_specific",
        "flags",
        "agent-created",
        "ice-mode",
        "ice-role",
        "sdps",
        "queued-packets",
        "streams"
      ]

      {:ok, take_string_keys_turn_to_atom(info, accepted_keys)}
    end
    |> API.handle_api_error()
  end

  # This would be beneficial in future PRs
  defp add_optional_param(map, key, value)
  defp add_optional_param(map, _key, nil), do: map
  defp add_optional_param(map, key, value), do: Map.put(map, key, value)

  defp take_string_keys_turn_to_atom(map, accepted_keys) do
    for {key, value} <- Map.take(map, accepted_keys), into: %{} do
      key = key |> String.replace("-", "_") |> String.to_atom()
      {key, value}
    end
  end
end
