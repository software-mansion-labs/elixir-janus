defmodule Janus.Test.Macro do
  defmacro assert_next_receive(pattern, timeout \\ 20000) do
    quote do
      receive do
        {[], {:ok, message}} ->
          assert ^unquote(pattern) = message
      after
        unquote(timeout) -> flunk("Response has not been received")
      end
    end
  end

  # macro generating test checking if event message handled by `Janus.Connection` module is passed to proper `Janus.Handler` callbacks
  # it used `FakeHandler.Payloads` mocked event messages and pass them through `Janus.Connection` which is supposed to pass them to proper `Janus.Handler` callbacks.
  # it uses `FakeHandler` callbacks to store last called callback in state, then it asserts that it was called for proper event type
  defmacro test_callback(event) do
    fun = String.to_atom("handle_" <> Atom.to_string(event))

    quote do
      test "#{inspect(unquote(fun))} callback" do
        alias Janus.Connection
        alias Janus.Transport.Stub.ValidTransport
        alias Janus.Handler.Stub.FakeHandler
        alias FakeHandler.Payloads

        state =
          state(
            transport_module: ValidTransport,
            handler_module: FakeHandler,
            handler_state: %{callback: nil}
          )

        message = apply(Payloads, unquote(event), [])

        {:noreply, new_state} = Connection.handle_info(message, state)
        state(handler_state: %{callback: callback}) = new_state

        assert unquote(fun) == callback
      end
    end
  end
end
