defmodule Janus.ConnectionTest do
  use ExUnit.Case
  import Janus.HandlerTest.CallbackHelper

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
