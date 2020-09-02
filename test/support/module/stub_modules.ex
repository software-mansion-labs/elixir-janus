defmodule Janus.Transport.Stub do
  defmodule ValidTransport do
    def connect(_args) do
      {:ok, "transport"}
    end

    def send(_payload, _timeout, state) do
      {:ok, state}
    end

    def handle_info(message, transport_state) do
      {:ok, message, transport_state}
    end
  end

  defmodule BrokenTransport do
    def connect(_args) do
      {:error, "transport"}
    end

    def send(_payload, _timeout, _state) do
      {:error, "handler"}
    end
  end
end

defmodule Janus.Handler.Stub do
  defmodule ValidHandler do
    def init(_args) do
      {:ok, "handler"}
    end
  end

  defmodule BrokenHandler do
    def init(_args) do
      {:error, "handler"}
    end
  end
end
