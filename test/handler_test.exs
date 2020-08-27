defmodule Janus.HandlerTest do
  use ExUnit.Case
  use Bunch
  alias Janus.Connection
  alias FakeHandler.Payloads

  import HandlerHelper

  defmodule SimpleTransport do
    def handle_info(message, state) do
      {:ok, message, state}
    end
  end

  setup do
    state = {:state, SimpleTransport, %{}, FakeHandler, %{callback: nil}, nil}
    [state: state]
  end

  describe "Connection should call handler's" do
    # check if all callbacks are called for their respective events
    test_callback(:created)
    test_callback(:attached)
    test_callback(:webrtc_up)
    test_callback(:audio_receiving)
    test_callback(:video_receiving)
    test_callback(:timeout)
  end
end
