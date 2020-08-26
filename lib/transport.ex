defmodule Janus.Transport do
  @type reason :: any
  @type state :: any
  @type payload :: map

  @doc """
  Creates transport specific connection and preserves it in state.

  Returns either `{:ok, state}` indicating valid transport state
  or `{:error, reason}` indicating connection failure.
  """
  @callback connect(any) :: {:ok, state} | {:error, reason}

  @doc """
  Synchronously sends given payload via previously created transport connection respecting given timeout.

  ## Arguments
  * `payload` - arbitrary map structure to be sent via transport
  * `timeout` - time after which `send/3` call should return imidiately with an error
  * `state` - state structure containing valid transport data necessary to send payload

  ## Returns
  `{:ok, state}` on successful payload delivery
  `{:error, reason, state}` on delivery failure
  """
  @callback send(payload, timeout, state) :: {:ok, state} | {:error, reason, state}

  @doc """
  Handles messages received by connection process

  Main purpose is to parse messages sent to the process owner by the transport module.

  ## Arguments
  * `info` - arbitrary data to be handled by module
  * `state` - state structure contianing transport data

  ## Returns
  on success:
  `{:ok, state}` or `{:ok, payload, state}` if message contained payload

  on error:
  `{:error, reason, state}`
  """
  @callback handle_info(info :: any, state) ::
              {:ok, state} | {:ok, payload, state} | {:error, reason, state}

  @doc """
  Provides time interval in which the keep-alive messages should be sent. `nil` indicates such messages are not needed
  """
  @callback keepalive_interval() :: timeout() | nil
end
