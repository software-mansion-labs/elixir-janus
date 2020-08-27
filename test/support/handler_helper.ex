defmodule HandlerHelper do
  alias Janus.Connection
  alias FakeHandler.Payloads

  def handlers_last_callback_call({:state, _, _, _, %{callback: callback}, _}), do: callback

  # helper test macro to generate test for checking if proper Handler's callback has been called
  defmacro test_callback(event) do
    fun = String.to_atom("handle_" <> Atom.to_string(event))

    quote do
      test "#{inspect(unquote(fun))} callback", %{state: state} do
        message = apply(Payloads, unquote(event), [])
        {:noreply, state} = Connection.handle_info(message, state)

        assert unquote(fun) = handlers_last_callback_call(state)
      end
    end
  end
end
