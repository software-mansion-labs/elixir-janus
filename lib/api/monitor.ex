defmodule Janus.API.Monitor do
  alias Janus.Connection

  %{
    janus_error_handle_not_found: 459,
    janus_error_invalid_element_type: 467,
    janus_error_invalid_json: 454,
    janus_error_invalid_json_object: 455,
    janus_error_invalid_request_path: 457,
    janus_error_jsep_invalid_sdp: 465,
    janus_error_jsep_unknown_type: 464,
    janus_error_missing_mandatory_element: 456,
    janus_error_missing_request: 452,
    janus_error_not_accepting_sessions: 472,
    janus_error_plugin_attach: 461,
    janus_error_plugin_detach: 463,
    janus_error_plugin_message: 462,
    janus_error_plugin_not_found: 460,
    janus_error_session_conflict: 468,
    janus_error_session_not_found: 458,
    janus_error_token_not_found: 470,
    janus_error_transport_specific: 450,
    janus_error_tricke_invalid_stream: 466,
    janus_error_unauthorized: 403,
    janus_error_unauthorized_plugin: 405,
    janus_error_unexpected_answer: 469,
    janus_error_unknown: 490,
    janus_error_unknown_request: 453,
    janus_error_webrtc_state: 471
  }

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

  @spec list_sessions(GenServer.server(), binary | nil) ::
          {:error, atom} | {:ok, list(non_neg_integer())}
  def list_sessions(connection, admin_secret \\ nil) do
    message =
      %{janus: "list_sessions"}
      |> add_optional_param(:admin_secret, admin_secret)

    with {:ok,
          %{
            "janus" => "success",
            "sessions" => list
          }} <-
           Connection.call(connection, message) do
      {:ok, list}
    end
  end

  @spec list_handles(GenServer.server(), non_neg_integer, binary | nil) ::
          {:error, atom} | {:ok, list(non_neg_integer())}
  def list_handles(connection, session_id, admin_secret \\ nil) do
    message =
      %{
        janus: "list_handles",
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
  end

  @spec handle_info(GenServer.server(), non_neg_integer, non_neg_integer, binary | nil) ::
          {:error, :atom} | {:ok, handle_info}
  def handle_info(connection, session_id, handle_id, admin_secret \\ nil) do
    message =
      %{
        janus: "handle_info",
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
