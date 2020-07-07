defmodule ElixirJanus.Transport do
  @type reason :: any
  @type state :: any
  @type payload :: map

  @callback connect(any) :: {:ok, state} | {:error, reason}
  @callback send(payload, timeout, state) :: {:ok, state} | {:error, reason, state}
  @callback handle_info(any, state) ::
              {:ok, state} | {:ok, payload, state} | {:error, reason, state}
end
