defmodule Janus.Handler do
  alias Janus.Session

  @type opaque_id :: String.t()
  @type emitter :: String.t()
  @type transport :: map

  @type state :: any

  @callback init(any) :: {:ok, state} | {:error, any}
  @callback handle_created(
              Session.session_id_t(),
              transport(),
              emitter(),
              DateTime.t(),
              state
            ) :: {:noreply, state}
  # FIXME handle events
  @callback handle_timeout(Session.session_id_t(), state) :: {:noreply, state}
  @callback handle_attached(
              Session.session_id_t(),
              Session.plugin_t(),
              Session.plugin_handle_id(),
              emitter(),
              opaque_id(),
              DateTime.t(),
              state
            ) :: {:noreply, state}
  # FIXME handle events
  @callback handle_detached(Session.session_id_t(), Session.plugin_handle_id(), state) ::
              {:noreply, state}
  @callback handle_webrtc_up(
              Session.session_id_t(),
              Session.plugin_handle_id(),
              emitter(),
              opaque_id(),
              DateTime.t(),
              state
            ) :: {:noreply, state}
  @callback handle_webrtc_down(
              Session.session_id_t(),
              Session.plugin_handle_id(),
              emitter(),
              opaque_id(),
              DateTime.t(),
              state
            ) :: {:noreply, state}
  @callback handle_audio_receiving(
              Session.session_id_t(),
              Session.plugin_handle_id(),
              emitter(),
              opaque_id(),
              boolean,
              DateTime.t(),
              state
            ) :: {:noreply, state}
  @callback handle_video_receiving(
              Session.session_id_t(),
              Session.plugin_handle_id(),
              emitter(),
              opaque_id(),
              boolean,
              DateTime.t(),
              state
            ) :: {:noreply, state}

  defmacro __using__(_) do
    quote do
      @behaviour Janus.Handler

      # Default implementations
      @impl true
      def init(_args), do: {:ok, nil}

      # FIXME handle events
      @impl true
      def handle_timeout(_session_id, state), do: {:noreply, state}

      @impl true
      def handle_created(_session_id, _transport, _emitter, _timestamp, state),
        do: {:noreply, state}

      @impl true
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
      @impl true
      def handle_detached(_session_id, _plugin_handle_id, state), do: {:noreply, state}

      @impl true
      def handle_webrtc_up(
            _session_id,
            _plugin_handle_id,
            _emitter,
            _opaque_id,
            _timestamp,
            state
          ),
          do: {:noreply, state}

      @impl true
      def handle_webrtc_down(
            _session_id,
            _plugin_handle_id,
            _emitter,
            _opaque_id,
            _timestamp,
            state
          ),
          do: {:noreply, state}

      @impl true
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

      @impl true
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
                     handle_webrtc_down: 6,
                     handle_audio_receiving: 7,
                     handle_video_receiving: 7
    end
  end
end
