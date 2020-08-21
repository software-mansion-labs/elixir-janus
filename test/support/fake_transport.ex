defmodule FakeTransport do
  @behaviour Janus.Transport

  defmodule MessageResponder do
    use GenServer

    def start_link(id, respond_to) do
      GenServer.start_link(__MODULE__, {id, respond_to}, [])
    end

    @impl true
    def init({id, respond_to}) do
      {:ok, %{id: id, respond_to: respond_to}}
    end

    @impl true
    def handle_cast({:message, payload}, %{respond_to: respond_to, id: id} = state) do
      send(respond_to, {:message, payload, id})
      {:noreply, state}
    end
  end

  @keepalive_timeout 500

  @impl true
  def connect({id, respond_to}) do
    {:ok, pid} = MessageResponder.start_link(id, respond_to)
    {:ok, %{server: pid}}
  end

  @impl true
  def send(payload, _timeout, %{server: pid} = state) do
    GenServer.cast(pid, {:message, payload})
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
