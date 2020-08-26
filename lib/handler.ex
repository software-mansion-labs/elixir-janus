defmodule Janus.Handler do
  alias Janus.Interface

  @type state :: any

  @callback init(any) :: {:ok, state} | {:error, any}
  @callback handle_created(
              Interface.session_id(),
              Interface.transport(),
              Interface.emitter(),
              DateTime.t(),
              state
            ) :: {:noreply, state}
  # FIXME handle events
  @callback handle_timeout(Interface.session_id(), state) :: {:noreply, state}
  @callback handle_attached(
              Interface.session_id(),
              Interface.plugin(),
              Interface.plugin_handle_id(),
              Interface.emitter(),
              Interface.opaque_id(),
              DateTime.t(),
              state
            ) :: {:noreply, state}
  # FIXME handle events
  @callback handle_detached(Interface.session_id(), Interface.plugin_handle_id(), state) ::
              {:noreply, state}
  @callback handle_webrtc_up(
              Interface.session_id(),
              Interface.plugin_handle_id(),
              Interface.emitter(),
              Interface.opaque_id(),
              DateTime.t(),
              state
            ) :: {:noreply, state}
  @callback handle_webrtc_down(
              Interface.session_id(),
              Interface.plugin_handle_id(),
              Interface.emitter(),
              Interface.opaque_id(),
              DateTime.t(),
              state
            ) :: {:noreply, state}
  @callback handle_audio_receiving(
              Interface.session_id(),
              Interface.plugin_handle_id(),
              Interface.emitter(),
              Interface.opaque_id(),
              boolean,
              DateTime.t(),
              state
            ) :: {:noreply, state}
  @callback handle_video_receiving(
              Interface.session_id(),
              Interface.plugin_handle_id(),
              Interface.emitter(),
              Interface.opaque_id(),
              boolean,
              DateTime.t(),
              state
            ) :: {:noreply, state}

  defmacro __using__(_) do
    quote location: :keep do
      @behaviour Janus.Handler

      # Default implementations

      def init(_args), do: {:ok, nil}

      # FIXME handle events
      def handle_timeout(_session_id, state), do: {:noreply, state}

      def handle_created(_session_id, _transport, _emitter, _timestamp, state),
        do: {:noreply, state}

      def handle_attached(
            _session_id,
            _plugin,
            _plugin_handle_id,
            _emitter,
            _opaque_id,
            _timestamp,
            state
          ),
          do: {:noreply, state}

      # FIXME handle events
      def handle_detached(_session_id, _plugin_handle_id, state), do: {:noreply, state}

      def handle_webrtc_up(
            _session_id,
            _plugin_handle_id,
            _emitter,
            _opaque_id,
            _timestamp,
            state
          ),
          do: {:noreply, state}

      def handle_webrtc_down(
            _session_id,
            _plugin_handle_id,
            _emitter,
            _opaque_id,
            _timestamp,
            state
          ),
          do: {:noreply, state}

      def handle_audio_receiving(
            _session_id,
            _plugin_handle_id,
            _emitter,
            _opaque_id,
            _receiving,
            _timestamp,
            state
          ),
          do: {:noreply, state}

      def handle_video_receiving(
            _session_id,
            _plugin_handle_id,
            _emitter,
            _opaque_id,
            _receiving,
            _timestamp,
            state
          ),
          do: {:noreply, state}

      defoverridable init: 1,
                     handle_created: 5,
                     handle_timeout: 2,
                     handle_attached: 7,
                     handle_detached: 3,
                     handle_webrtc_up: 6,
                     handle_audio_receiving: 7,
                     handle_video_receiving: 7
    end
  end
end
