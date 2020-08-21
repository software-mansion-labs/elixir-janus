defmodule Janus.Transport do
  @type reason :: any
  @type state :: any
  @type payload :: map
  @type keepalive_timeout :: number

  @callback connect(any) :: {:ok, state} | {:error, reason}
  @callback send(payload, timeout, state) :: {:ok, state} | {:error, reason, state}
  @callback handle_info(any, state) ::
              {:ok, state} | {:ok, payload, state} | {:error, reason, state}
  @callback needs_keep_alive?() :: {true, keepalive_timeout} | false
end
