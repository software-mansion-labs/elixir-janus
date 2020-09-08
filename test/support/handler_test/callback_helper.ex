defmodule Janus.HandlerTest.CallbackHelper do
  # helper module that declares macro for testing `Janus.Handler`'s callback calls

  # simple transport returning message given to `handle_info/2` without changes
  # used by `Janus.Connection.handle_info/2`
  defmodule SimpleTransport do
    def handle_info(message, state) do
      {:ok, message, state}
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
        alias Janus.HandlerTest.FakeHandler
        alias Janus.HandlerTest.FakeHandler.Payloads

        state = {:state, SimpleTransport, %{}, FakeHandler, %{callback: nil}, nil}
        message = apply(Payloads, unquote(event), [])

        {:noreply, new_state} = Connection.handle_info(message, state)
        {:state, _, _, _, %{callback: callback}, _} = new_state

        assert unquote(fun) == callback
      end
    end
  end
end
