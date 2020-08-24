defmodule FakeTransport do
  @behaviour Janus.Transport
  @keepalive_timeout 500

  @impl true
  def connect({id, respond_to}) do
    {:ok, %{message_receiver: respond_to, id: id}}
  end

  @impl true
  def send(payload, _timeout, %{message_receiver: receiver, id: id} = state) do
    send(receiver, {:message, payload, id})
    {:ok, state}
  end

  @impl true
  def handle_info(_any, state) do
    {:ok, state}
  end

  @impl true
  def needs_keep_alive?() do
    {true, @keepalive_timeout}
  end
end
