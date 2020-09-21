defmodule Janus.Support do
  defmodule BrokenTransport do
    def connect(_args) do
      {:error, "transport"}
    end
  end

  defmodule ValidHandler do
    def init(_args) do
      {:ok, {}}
    end
  end

  defmodule BrokenHandler do
    def init(_args) do
      {:error, "handler"}
    end
  end
end
