defmodule Janus.Handler.Stub.FakeHandler do
  # fake handler that updates state with currently invoked callback
  use Janus.Handler

  defmodule Payloads do
    # helper module with mocked messages based on events handled by `Janus.Handler`

    @emitter "emitter"
    @session_id 1
    @timestamp 1_598_526_845
    @plugin_handle_id 2
    @opaque_id "opaque_id"
    @plugin "some_plugin"
    @receiving true
    @transaction "transaction_XXX"

    def created() do
      %{
        "emitter" => @emitter,
        "event" => %{"name" => "created", "transport" => %{}},
        "session_id" => @session_id,
        "timestamp" => @timestamp,
        "type" => 1
      }
    end

    def attached() do
      %{
        "emitter" => @emitter,
        "event" => %{"name" => "attached", "opaque_id" => @opaque_id, "plugin" => @plugin},
        "handle_id" => @plugin_handle_id,
        "opaque_id" => @opaque_id,
        "session_id" => @session_id,
        "timestamp" => @timestamp,
        "type" => 2
      }
    end

    def webrtc_up() do
      %{
        "emitter" => @emitter,
        "event" => %{"connection" => "webrtcup"},
        "handle_id" => @plugin_handle_id,
        "opaque_id" => @opaque_id,
        "session_id" => @session_id,
        "subtype" => 6,
        "type" => 16,
        "timestamp" => @timestamp
      }
    end

    def audio_receiving() do
      %{
        "emitter" => @emitter,
        "event" => %{"media" => "audio", "receiving" => @receiving},
        "handle_id" => @plugin_handle_id,
        "opaque_id" => @opaque_id,
        "session_id" => @session_id,
        "subtype" => 1,
        "timestamp" => @timestamp,
        "type" => 32
      }
    end

    def video_receiving() do
      %{
        "emitter" => @emitter,
        "event" => %{"media" => "video", "receiving" => @receiving},
        "handle_id" => @plugin_handle_id,
        "opaque_id" => @opaque_id,
        "session_id" => @session_id,
        "subtype" => 1,
        "timestamp" => @timestamp,
        "type" => 32
      }
    end

    def timeout() do
      %{
        "janus" => "timeout",
        "session_id" => @session_id,
        "transaction" => @transaction
      }
    end

    def detached() do
      %{"janus" => "detached", "session_id" => @session_id, "sender" => @plugin_handle_id}
    end
  end

  @impl true
  def init(_), do: {:ok, %{callback: nil}}

  @impl true
  def handle_timeout(_session_id, state), do: {:noreply, %{state | callback: :handle_timeout}}

  @impl true
  def handle_created(_session_id, _transport, _emitter, _timestamp, state),
    do: {:noreply, %{state | callback: :handle_created}}

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
      do: {:noreply, %{state | callback: :handle_attached}}

  @impl true
  def handle_detached(_session_id, _plugin_handle_id, state),
    do: {:noreply, %{state | callback: :handle_detached}}

  @impl true
  def handle_webrtc_up(
        _session_id,
        _plugin_handle_id,
        _emitter,
        _opaque_id,
        _timestamp,
        state
      ),
      do: {:noreply, %{state | callback: :handle_webrtc_up}}

  @impl true
  def handle_webrtc_down(
        _session_id,
        _plugin_handle_id,
        _emitter,
        _opaque_id,
        _timestamp,
        state
      ),
      do: {:noreply, %{state | callback: :handle_webrtc_down}}

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
      do: {:noreply, %{state | callback: :handle_audio_receiving}}

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
      do: {:noreply, %{state | callback: :handle_video_receiving}}
end
