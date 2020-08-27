# Elixir Janus

Package responsible for communicating with Janus Gateway from Elixir's code level.

It can take advantage of various transport interfaces provided by Janus API, more info [here](https://janus.conf.meetecho.com/docs/rest.html).


## Disclaimer
This package is experimental and is not yet released to hex.

## Example

```elixir
# user have to provide transport and handler modules that ElixirJanus can take advantage of
iex> alias Janus.{Connection, Session}
iex> {:ok, connection} = Connection.start_link(your_transport_module, transport_args, your_handler_module, handler_args, []) 
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


## Copyright and License

Copyright 2020, [Software Mansion](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=elixir-janus)

[![Software Mansion](https://logo.swmansion.com/logo?color=white&variant=desktop&width=200&tag=elixir-janus-transport-ws)](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=elixir-janus)

Licensed under the [Apache License, Version 2.0](LICENSE)

