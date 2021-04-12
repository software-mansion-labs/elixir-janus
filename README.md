# Elixir Janus

Package responsible for communicating with Janus Gateway from Elixir's code level.

It can take advantage of various transport interfaces provided by Janus API, more info [here](https://janus.conf.meetecho.com/docs/rest.html).

## Disclaimer

This package is experimental and is not yet released to hex.

## Example

```elixir
# handler example
defmodule CustomHandler do
  use Janus.Handler

  @impl true
  def init(_) do
    {:ok, %{}}
  end

  # example of event's callback implementation
  @impl true
  def handle_created(_session_id, _transport, _meta, state) do
    # created event has been send by the gateway, handle it in any way e.g. log, store in database
    {:noreply, state}
  end

  ...

end
```

Communicating with the gateway:

```elixir
# user have to provide transport and handler modules that ElixirJanus can take advantage of
# this example uses previously created `CustomHandler` and `Janus.Transport.WS` package for transport
iex> alias Janus.{Connection, Session}
iex> alias Janus.Transport.WS
iex> {:ok, connection} = Connection.start_link(WS, {"WebSocket url to the gateway", WS.Adapters.WebSockex, [timeout: 5000]}, CustomHandler, {}, [])
iex> {:ok, session} = Session.start_link(connection, 5000)  # session module is responsible for applying `session_id` to all messages and keeping connection alive
iex> {:ok, response} = Session.execute_request(session, message_to_gateway)
```

## Installation

```elixir
defp deps do
  [
    {:elixir_janus, github: "software-mansion-labs/elixir-janus"}
  ]
end
```

## Transports

Supported transports:

- `Janus.Transport.WS` - WebSockets transport package, for more information how to use given transport please refer to package's [repository](https://github.com/software-mansion-labs/elixir-janus-transport-ws).

## Copyright and License

Copyright 2020, [Software Mansion](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=elixir-janus)

[![Software Mansion](https://logo.swmansion.com/logo?color=white&variant=desktop&width=200&tag=elixir-janus-transport-ws)](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=elixir-janus)

Licensed under the [Apache License, Version 2.0](LICENSE)
