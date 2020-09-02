defmodule Janus.API.Errors do
  @moduledoc false

  @errors %{
    403 => :janus_error_unauthorized,
    405 => :janus_error_unauthorized_plugin,
    490 => :janus_error_unknown,
    450 => :janus_error_transport_specific,
    452 => :janus_error_missing_request,
    453 => :janus_error_unknown_request,
    454 => :janus_error_invalid_json,
    455 => :janus_error_invalid_json_object,
    456 => :janus_error_missing_mandatory_element,
    457 => :janus_error_invalid_request_path,
    458 => :janus_error_session_not_found,
    459 => :janus_error_handle_not_found,
    460 => :janus_error_plugin_not_found,
    461 => :janus_error_plugin_attach,
    462 => :janus_error_plugin_message,
    463 => :janus_error_plugin_detach,
    464 => :janus_error_jsep_unknown_type,
    465 => :janus_error_jsep_invalid_sdp,
    466 => :janus_error_tricke_invalid_stream,
    467 => :janus_error_invalid_element_type,
    468 => :janus_error_session_conflict,
    469 => :janus_error_unexpected_answer,
    470 => :janus_error_token_not_found,
    471 => :janus_error_webrtc_state,
    472 => :janus_error_not_accepting_sessions
  }
  # This function handles error that is sent by Janus
  # Source: https://github.com/meetecho/janus-gateway/blob/master/apierror.h#L20
  @spec handle(any()) :: {:error, {atom(), integer(), String.t()}}
  def handle(%{"janus" => "error", "error" => %{"code" => code, "reason" => reason}}) do
    error = @errors[code]
    {:error, {error, code, reason}}
  end

  def handle({:error, {:gateway, code, reason}}) do
    error = @errors[code]
    {:error, {error, code, reason}}
  end
end
