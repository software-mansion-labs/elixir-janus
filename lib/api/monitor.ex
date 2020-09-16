defmodule Janus.API.Monitor do
  @moduledoc """
  Provides functionality to request information from Monitor's API.

  ## Important
  All functions require valid connection to Monitor API instead of regular Janus API.
  """
  alias Janus.Session
  alias Janus.Connection
  alias Janus.API.Errors

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

  @info_accepted_keys [
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

  @doc """
  Requests list of all existing sessions.

  ## Arguments
  * `connection` - valid connection with Monitor API.
  * `admin_secret` - secret added to API request if authorization is required.
  """
  @spec list_sessions(GenServer.server(), binary | nil) ::
          {:error, atom} | {:ok, list(Session.session_id_t())}
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
    else
      {:error, _reason} = error ->
        Errors.handle(error)
    end
  end

  @doc """
  Requests list of all handles currently active within given session.

  ## Arguments
  * `connection` - valid connection with Monitor API.
  * `session_id` - targeted session's id.
  * `admin_secret` - secret added to API request if authorization is required.
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
    else
      {:error, _reason} = error ->
        Errors.handle(error)
    end
  end

  @doc """
  Requests information about specific handle.

  ## Arguments
  * `connection` - valid connection with Monitor API.
  * `session_id` - session id of targeted handler.
  * `handle_id` - targeted handler's id.
  * `admin_secret` - secret added to API request if authorization is required.
  """
  @spec handle_info(
          GenServer.server(),
          Session.session_id_t(),
          Session.plugin_handle_id(),
          binary | nil
        ) ::
          {:error, atom} | {:ok, handle_info}
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
      {:ok, take_accepted_keys_as_atoms(info)}
    else
      {:error, _reason} = error ->
        Errors.handle(error)
    end
  end

  # This would be beneficial in future PRs
  defp add_optional_param(map, key, value)
  defp add_optional_param(map, _key, nil), do: map
  defp add_optional_param(map, key, value), do: Map.put(map, key, value)

  defp take_accepted_keys_as_atoms(map) do
    for {key, value} <- Map.take(map, @info_accepted_keys), into: %{} do
      key = key |> String.replace("-", "_") |> String.to_atom()
      {key, value}
    end
  end
end
