defmodule Janus.Handler do
  alias Janus.Session

  @type opaque_id :: String.t()
  @type emitter :: String.t()
  @type transport :: map

  @type event_meta :: %{
          optional(:emitter) => emitter(),
          optional(:timestamp) => DateTime.t(),
          optional(:opaque_id) => opaque_id()
        }

  @type state :: any

  @callback init(any) :: {:ok, state} | {:error, any}
  @callback handle_created(
              Session.session_id_t(),
              transport(),
              event_meta(),
              state
            ) :: {:noreply, state}
  # FIXME handle events
  @callback handle_timeout(Session.session_id_t(), state) :: {:noreply, state}
  @callback handle_attached(
              Session.session_id_t(),
              Session.plugin_t(),
              Session.plugin_handle_id(),
              event_meta(),
              state
            ) :: {:noreply, state}
  # FIXME handle events
  @callback handle_detached(Session.session_id_t(), Session.plugin_handle_id(), state) ::
              {:noreply, state}
  @callback handle_webrtc_up(
              Session.session_id_t(),
              Session.plugin_handle_id(),
              event_meta(),
              state
            ) :: {:noreply, state}
  @callback handle_webrtc_down(
              Session.session_id_t(),
              Session.plugin_handle_id(),
              reason :: String.t(),
              event_meta(),
              state
            ) :: {:noreply, state}
  @callback handle_slow_link(
              Session.session_id_t(),
              Session.plugin_handle_id(),
              direction :: :to_janus | :from_janus,
              lost_packets :: non_neg_integer(),
              event_meta(),
              state
            ) :: {:noreply, state}
  @callback handle_audio_receiving(
              Session.session_id_t(),
              Session.plugin_handle_id(),
              boolean,
              event_meta(),
              state
            ) :: {:noreply, state}
  @callback handle_video_receiving(
              Session.session_id_t(),
              Session.plugin_handle_id(),
              boolean,
              event_meta(),
              state
            ) :: {:noreply, state}
  @callback handle_plugin_event(
              Session.session_id_t(),
              Session.plugin_handle_id(),
              plugin :: String.t(),
              event_data :: map(),
              event_meta(),
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
      def handle_created(_session_id, _transport, _meta, state),
        do: {:noreply, state}

      @impl true
      def handle_attached(_session_id, _plugin, _plugin_handle_id, _meta, state),
        do: {:noreply, state}

      # FIXME handle events
      @impl true
      def handle_detached(_session_id, _plugin_handle_id, state), do: {:noreply, state}

      @impl true
      def handle_webrtc_up(
            _session_id,
            _plugin_handle_id,
            _meta,
            state
          ),
          do: {:noreply, state}

      @impl true
      def handle_webrtc_down(
            _session_id,
            _plugin_handle_id,
            _reason,
            _meta,
            state
          ),
          do: {:noreply, state}

      @impl true
      def handle_slow_link(
            _session_id,
            _plugin_handle_id,
            _direction,
            _lost_packets,
            _meta,
            state
          ),
          do: {:noreply, state}

      @impl true
      def handle_audio_receiving(
            _session_id,
            _plugin_handle_id,
            _receiving,
            _meta,
            state
          ),
          do: {:noreply, state}

      @impl true
      def handle_video_receiving(
            _session_id,
            _plugin_handle_id,
            _receiving,
            _meta,
            state
          ),
          do: {:noreply, state}

      @impl true
      def handle_plugin_event(
            _session_id,
            _plugin_handle_id,
            _plugin,
            _event_data,
            _meta,
            state
          ),
          do: {:noreply, state}

      defoverridable init: 1,
                     handle_created: 4,
                     handle_timeout: 2,
                     handle_attached: 5,
                     handle_detached: 3,
                     handle_webrtc_up: 4,
                     handle_webrtc_down: 5,
                     handle_slow_link: 6,
                     handle_audio_receiving: 5,
                     handle_video_receiving: 5,
                     handle_plugin_event: 6
    end
  end
end
