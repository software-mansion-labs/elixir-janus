defmodule Janus.Connection do
  @moduledoc """
  Creates and keeps active connection with Janus Gateway, sends and
  handles messages specific to the gateway and its plugins.

  Module can take advantage of different transports and handler modules.
  All the interaction is done via `Janus.Connection.call/3` function.
  """

  use Connection
  use Bunch
  require Record
  require Logger

  alias Janus.Connection.Transaction

  @default_timeout 5000
  @default_cleanup_interval 60000

  @type t :: GenServer.server()

  Record.defrecord(:state,
    transport_module: nil,
    transport_state: nil,
    transport_args: nil,
    handler_module: nil,
    handler_state: nil,
    handler_args: nil,
    pending_calls_table: nil,
    cleanup_interval: @default_cleanup_interval
  )

  @doc """
  Starts the new connection to the gateway and links it to the current
  process. The connection is transport-agnostic. The gateway supports
  multiple means of accessing its API and this module can use any of them.

  ## Arguments

  * `transport_module` - a module that implements `Janus.Transport`
    behaviour, responsible for handling the actual data flow to and from
    the gateway,
  * `transport_args` - a transport module-specific argument that will be
    passed to the `c:Janus.Transport.connect/1` callback.
  * `handler_module` - a module that implements `Janus.Handler`
    behaviour, responsible for handling the callbacks sent from the gateway,
  * `handler_args` - a handler module-specific argument that will be
    passed to the `c:Janus.Handler.init/1` callback.
  * `options` - process options, as in `GenServer.start_link/3`.

  ## Return values

  Returns the same values as `GenServer.start_link/3`.
  """
  @spec start_link(module, any, module, any, GenServer.options()) :: GenServer.on_start()
  def start_link(transport_module, transport_args, handler_module, handler_args, options \\ []),
    do:
      do_start(
        :start_link,
        transport_module,
        transport_args,
        handler_module,
        handler_args,
        options
      )

  @doc """
  Works the same as `start_link/5` but does not link with the calling process.
  """
  @spec start(module, any, module, any, GenServer.options()) :: GenServer.on_start()
  def start(transport_module, transport_args, handler_module, handler_args, options \\ []),
    do: do_start(:start, transport_module, transport_args, handler_module, handler_args, options)

  defp do_start(method, transport_module, transport_args, handler_module, handler_args, options) do
    args = %{
      transport_module: transport_module,
      transport_args: transport_args,
      handler_module: handler_module,
      handler_args: handler_args
    }

    apply(Connection, method, [
      __MODULE__,
      args,
      options
    ])
  end

  @doc """
  Calls the gateway in synchronous manner.

  The underlying gateway API is asynchronous but that will wait until the reply
  is returned or until given timeout passes.

  See the [gateway's API documentation](https://janus.conf.meetecho.com/docs/rest.html)
  for list of valid payloads that can be sent.

  ## Arguments

  * `server` - a PID of the `Janus.Connection` process,
  * `payload` - a map that can be later safely serialized to JSON according to the
    gateway's API without the `transaction` key. It will be injected automatically
  * `timeout` - a valid timeout, in milliseconds.

  ## Return values

  On success it returns `{:ok, payload}`, where `payload` is a map that contains
  response as defined in the gateway API.

  On error it returns `{:error, reason}`.

  The reason might be:

  * `{:gateway, code, info}` - it means that the call itself succeeded but the
    gateway returned an error of the given code and info.
  """
  @spec call(GenServer.server(), map, Transaction.call_type(), timeout) ::
          {:ok, any} | {:error, any}
  def call(server, payload, call_type, timeout \\ @default_timeout) do
    GenServer.call(server, {:call, payload, timeout, call_type}, timeout)
  end

  @doc """
  Returns transport module.
  """
  @spec get_transport_module(GenServer.server()) :: any
  def get_transport_module(server) do
    Connection.call(server, {:get_module, :transport})
  end

  @doc """
  Returns handler module.
  """
  @spec get_handler_module(GenServer.server()) :: any
  def get_handler_module(server) do
    Connection.call(server, {:get_module, :handler})
  end

  # Callbacks

  @impl true
  def init(
        %{
          transport_module: transport_module,
          transport_args: transport_args,
          handler_module: handler_module,
          handler_args: handler_args
        } = args
      ) do
    Logger.debug(
      "[#{__MODULE__} #{inspect(self())}] Init: transport_module = #{inspect(transport_module)}, handler_module = #{
        inspect(handler_module)
      }"
    )

    cleanup_interval = args[:cleanup_interval] || @default_cleanup_interval
    pending_calls_table = Transaction.init_transaction_call_table()

    state =
      state(
        transport_module: transport_module,
        transport_args: transport_args,
        handler_module: handler_module,
        handler_args: handler_args,
        cleanup_interval: cleanup_interval,
        pending_calls_table: pending_calls_table
      )

    {:connect, :init, state}
  end

  @impl true
  def connect(
        _,
        state(
          transport_module: transport_module,
          transport_args: transport_args,
          handler_module: handler_module,
          handler_args: handler_args,
          cleanup_interval: cleanup_interval
        ) = state
      ) do
    Logger.debug(
      "[#{__MODULE__} #{inspect(self())}] Connect: transport_module = #{inspect(transport_module)}, handler_module = #{
        inspect(handler_module)
      }"
    )

    withl handler: {:ok, handler_state} <- handler_module.init(handler_args),
          connect: {:ok, transport_state} <- transport_module.connect(transport_args) do
      state =
        state(state,
          cleanup_interval: cleanup_interval,
          handler_state: handler_state,
          transport_state: transport_state
        )

      {:ok, state}
    else
      handler: {:error, reason} ->
        {:stop, {:handler, reason}}

      connect: {:error, reason} ->
        Logger.error(
          "[#{__MODULE__} #{inspect(self())}] Error trying to establish connection, reason: #{
            inspect(reason)
          }"
        )

        {:backoff, 1000, state}
    end
  end

  @impl true
  def handle_call(
        {:call, payload, timeout, type},
        from,
        state(
          transport_module: transport_module,
          transport_state: transport_state,
          pending_calls_table: pending_calls_table
        ) = state
      ) do
    transaction = Transaction.insert_transaction(pending_calls_table, from, timeout, type)
    payload_with_transaction = Map.put(payload, :transaction, transaction)

    "[#{__MODULE__} #{inspect(self())}] Call: transaction = #{inspect(transaction)}, payload = #{
      inspect(payload)
    }"
    |> Logger.debug()

    case transport_module.send(payload_with_transaction, timeout, transport_state) do
      {:ok, new_transport_state} ->
        {:noreply, state(state, transport_state: new_transport_state)}

      {:error, reason} ->
        "[#{__MODULE__} #{inspect(self())}] Transport send error: reason = #{inspect(reason)}"
        |> Logger.error()

        # TODO check if this is correct return value
        {:stop, {:call, reason}, state}
    end
  end

  def handle_call({:get_module, :transport}, _from, state(transport_module: module) = state) do
    {:reply, module, state}
  end

  def handle_call({:get_module, :handler}, _from, state(handler_module: module) = state) do
    {:reply, module, state}
  end

  @impl true
  def handle_info(
        :cleanup,
        state(pending_calls_table: pending_calls_table, cleanup_interval: cleanup_interval) =
          state
      ) do
    Transaction.cleanup_old_transactions(pending_calls_table)

    Process.send_after(self(), :cleanup, cleanup_interval)
    {:noreply, state}
  end

  def handle_info(
        message,
        state(transport_module: transport_module, transport_state: transport_state) = s
      ) do
    case transport_module.handle_info(message, transport_state) do
      {:ok, new_transport_state} ->
        {:noreply, state(s, transport_state: new_transport_state)}

      {:ok, payload, new_transport_state} ->
        "[#{__MODULE__} #{inspect(self())}] Received payload: payload = #{inspect(payload)}"
        |> Logger.debug()

        case handle_payload(payload, s) do
          {:ok, new_state} ->
            {:noreply, state(new_state, transport_state: new_transport_state)}
        end

      {:error, reason, new_transport_state} ->
        "[#{__MODULE__} #{inspect(self())}] Transport handle info error: reason = #{
          inspect(reason)
        }"
        |> Logger.error()

        # TODO check if this is correct return value
        {:stop, {:transport_handle_info, reason}, state(s, transport_state: new_transport_state)}
    end
  end

  # Helpers

  # Monitor/Admin API payloads

  ## Handle list_sessions payload
  defp handle_payload(
         %{"janus" => "success", "transaction" => transaction, "sessions" => _sessions} = msg,
         state
       ) do
    handle_successful_payload(transaction, msg, state)
  end

  ## Handle list_handles payload
  defp handle_payload(
         %{"janus" => "success", "transaction" => transaction, "handles" => _handles} = msg,
         state
       ) do
    handle_successful_payload(transaction, msg, state)
  end

  ## Handle handle_info payload
  defp handle_payload(
         %{
           "janus" => "success",
           "transaction" => transaction,
           "session_id" => _session_id,
           "handle_id" => _handle_id,
           "info" => _info
         } = msg,
         state
       ) do
    handle_successful_payload(transaction, msg, state)
  end

  # Handles payload which is a success response to the call
  defp handle_payload(
         %{"janus" => "success", "transaction" => transaction} = response,
         state(pending_calls_table: pending_calls_table) = state
       ) do
    data = response["data"] || response["plugindata"]["data"]
    Transaction.handle_transaction({:ok, data}, transaction, pending_calls_table)
    {:ok, state}
  end

  defp handle_payload(
         %{"janus" => "ack", "transaction" => transaction},
         state(pending_calls_table: pending_calls_table) = state
       ) do
    Transaction.handle_transaction({:ok, %{"janus" => "ack"}}, transaction, pending_calls_table)
    {:ok, state}
  end

  # Handles payload which is an error response to the call
  defp handle_payload(
         %{
           "janus" => "error",
           "transaction" => transaction,
           "error" => %{"code" => code, "reason" => reason}
         },
         state(pending_calls_table: pending_calls_table) = state
       ) do
    result = {:error, {:gateway, code, reason}}
    Transaction.handle_transaction(result, transaction, pending_calls_table)

    {:ok, state}
  end

  # Handles notification about session timeout
  defp handle_payload(
         %{"janus" => "timeout", "session_id" => session_id},
         state(handler_module: handler_module, handler_state: handler_state) = s
       ) do
    Logger.warn("[#{__MODULE__} #{inspect(self())}] Timeout: session_id = #{inspect(session_id)}")

    case handler_module.handle_timeout(session_id, handler_state) do
      {:noreply, new_handler_state} ->
        {:ok, state(s, handler_state: new_handler_state)}
    end
  end

  # Handles notification about plugin being detached from the session
  defp handle_payload(
         %{"janus" => "detached", "session_id" => session_id, "sender" => sender},
         state(handler_module: handler_module, handler_state: handler_state) = s
       ) do
    "[#{__MODULE__} #{inspect(self())}] Detached: session_id = #{inspect(session_id)}, sender = #{
      inspect(sender)
    }"
    |> Logger.info()

    case handler_module.handle_detached(session_id, sender, handler_state) do
      {:noreply, new_handler_state} ->
        {:ok, state(s, handler_state: new_handler_state)}
    end
  end

  defp handle_payload(
         %{"janus" => "webrtcup", "session_id" => session_id, "sender" => sender},
         state(handler_module: handler_module, handler_state: handler_state) = s
       ) do
    case handler_module.handle_webrtc_up(session_id, sender, nil, nil, nil, handler_state) do
      {:noreply, new_handler_state} ->
        {:ok, state(s, handler_state: new_handler_state)}
    end
  end

  defp handle_payload(
         %{
           "janus" => "media",
           "session_id" => session_id,
           "sender" => sender,
           "receiving" => receiving,
           "type" => type
         },
         state(handler_module: handler_module, handler_state: handler_state) = s
       ) do
    {:noreply, new_handler_state} =
      case type do
        "audio" ->
          handler_module.handle_audio_receiving(
            session_id,
            sender,
            nil,
            nil,
            receiving,
            nil,
            handler_state
          )

        "video" ->
          handler_module.handle_video_receiving(
            session_id,
            sender,
            nil,
            nil,
            receiving,
            nil,
            handler_state
          )
      end

    {:ok, state(s, handler_state: new_handler_state)}
  end

  ########
  # Event Emitter payloads
  ########

  # Handle event created
  defp handle_payload(
         %{
           "emitter" => emitter,
           "event" => %{"name" => "created", "transport" => transport},
           "session_id" => session_id,
           "timestamp" => timestamp,
           "type" => 1
         },
         state(handler_module: handler_module, handler_state: handler_state) = s
       ) do
    case handler_module.handle_created(
           session_id,
           transport,
           emitter,
           DateTime.from_unix!(timestamp, :microsecond),
           handler_state
         ) do
      {:noreply, new_handler_state} ->
        {:ok, state(s, handler_state: new_handler_state)}
    end
  end

  # Handle event attached
  defp handle_payload(
         %{
           "emitter" => emitter,
           "event" => %{"name" => "attached", "opaque_id" => _opaque_id, "plugin" => plugin},
           "handle_id" => plugin_handle_id,
           "opaque_id" => opaque_id,
           "session_id" => session_id,
           "timestamp" => timestamp,
           "type" => 2
         },
         state(handler_module: handler_module, handler_state: handler_state) = s
       ) do
    case handler_module.handle_attached(
           session_id,
           plugin,
           plugin_handle_id,
           emitter,
           opaque_id,
           DateTime.from_unix!(timestamp, :microsecond),
           handler_state
         ) do
      {:noreply, new_handler_state} ->
        {:ok, state(s, handler_state: new_handler_state)}
    end
  end

  # Handle event WebRTC UP
  defp handle_payload(
         %{
           "emitter" => emitter,
           "event" => %{"connection" => "webrtcup"},
           "handle_id" => plugin_handle_id,
           "opaque_id" => opaque_id,
           "session_id" => session_id,
           "subtype" => 6,
           "type" => 16,
           "timestamp" => timestamp
         },
         state(handler_module: handler_module, handler_state: handler_state) = s
       ) do
    case handler_module.handle_webrtc_up(
           session_id,
           plugin_handle_id,
           emitter,
           opaque_id,
           DateTime.from_unix!(timestamp, :microsecond),
           handler_state
         ) do
      {:noreply, new_handler_state} ->
        {:ok, state(s, handler_state: new_handler_state)}
    end
  end

  # Handle event media receiving for audio
  defp handle_payload(
         %{
           "emitter" => emitter,
           "event" => %{"media" => "audio", "receiving" => receiving},
           "handle_id" => plugin_handle_id,
           "opaque_id" => opaque_id,
           "session_id" => session_id,
           "subtype" => 1,
           "timestamp" => timestamp,
           "type" => 32
         },
         state(handler_module: handler_module, handler_state: handler_state) = s
       ) do
    case handler_module.handle_audio_receiving(
           session_id,
           plugin_handle_id,
           emitter,
           opaque_id,
           receiving,
           DateTime.from_unix!(timestamp, :microsecond),
           handler_state
         ) do
      {:noreply, new_handler_state} ->
        {:ok, state(s, handler_state: new_handler_state)}
    end
  end

  # Handle event media receiving for video
  defp handle_payload(
         %{
           "emitter" => emitter,
           "event" => %{"media" => "video", "receiving" => receiving},
           "handle_id" => plugin_handle_id,
           "opaque_id" => opaque_id,
           "session_id" => session_id,
           "subtype" => 1,
           "timestamp" => timestamp,
           "type" => 32
         },
         state(handler_module: handler_module, handler_state: handler_state) = s
       ) do
    case handler_module.handle_video_receiving(
           session_id,
           plugin_handle_id,
           emitter,
           opaque_id,
           receiving,
           DateTime.from_unix!(timestamp, :microsecond),
           handler_state
         ) do
      {:noreply, new_handler_state} ->
        {:ok, state(s, handler_state: new_handler_state)}
    end
  end

  # Plugin-originated events
  defp handle_payload(
         %{"event" => event, "type" => 64, "timestamp" => timestamp} = payload,
         state(handler_module: handler_module, handler_state: handler_state) = state
       ) do
    case handler_module.handle_plugin_event(
           payload["session_id"],
           payload["handle_id"],
           event["plugin"],
           event["data"],
           payload["emitter"],
           payload["opaque_id"],
           DateTime.from_unix!(timestamp, :microsecond),
           handler_state
         ) do
      {:noreply, new_handler_state} ->
        {:ok, state(state, handler_state: new_handler_state)}
    end
  end

  # Handles event without subtype FIXME
  defp handle_payload(
         %{"emitter" => emitter, "event" => event, "type" => type, "timestamp" => timestamp},
         state(handler_module: _handler_module, handler_state: _handler_state) = state
       ) do
    "[#{__MODULE__} #{inspect(self())}] Event: emitter = #{inspect(emitter)}, event = #{
      inspect(event)
    }, type = #{inspect(type)}, timestamp = #{inspect(timestamp)}"
    |> Logger.warn()

    {:ok, state}
  end

  # Payloads related to the events might come batched in lists, handle them recursively
  defp handle_payload([head | tail], s) do
    case handle_payload(head, s) do
      {:ok, new_state} ->
        handle_payload(tail, new_state)
    end
  end

  defp handle_payload([], s) do
    {:ok, s}
  end

  # Handle all successes
  defp handle_payload(
         %{
           "janus" => "success",
           "transaction" => transaction
         } = payload,
         state
       ) do
    handle_successful_payload(transaction, payload, state)
  end

  # Async response to a plugin request
  defp handle_payload(
         %{
           "janus" => "event",
           "transaction" => transaction,
           "plugindata" => %{
             "plugin" => _plugin,
             "data" => _data
           }
         } = payload,
         state
       ) do
    data = payload |> Map.take(["janus", "session_id", "plugindata", "jsep", "sender"])
    handle_successful_payload(transaction, data, state)
  end

  # VideoRoom Events on attached handle
  # FIXME: this should be handled by plugin module
  defp handle_payload(
         %{
           "janus" => "event",
           "plugindata" => %{
             "plugin" => plugin,
             "data" => data
           },
           "sender" => sender_handle_id,
           "session_id" => session_id
         },
         state(handler_module: handler_module, handler_state: handler_state) = state
       ) do
    case handler_module.handle_plugin_event(
           session_id,
           sender_handle_id,
           plugin,
           data,
           nil,
           nil,
           nil,
           handler_state
         ) do
      {:noreply, new_handler_state} ->
        {:ok, state(state, handler_state: new_handler_state)}
    end
  end

  defp handle_payload(
         %{
           "janus" => "hangup",
           "reason" => reason,
           "sender" => sender_handle_id,
           "session_id" => session_id
         },
         state(handler_module: handler_module, handler_state: handler_state) = state
       ) do
    case handler_module.handle_webrtc_down(
           session_id,
           sender_handle_id,
           reason,
           nil,
           nil,
           nil,
           handler_state
         ) do
      {:noreply, new_handler_state} ->
        {:ok, state(state, handler_state: new_handler_state)}
    end
  end

  defp handle_payload(
         %{
           "janus" => "slowlink",
           "uplink" => uplink?,
           "lost" => lost_packets,
           "sender" => sender_handle_id,
           "session_id" => session_id
         },
         state(handler_module: handler_module, handler_state: handler_state) = state
       ) do
    case handler_module.handle_slow_link(
           session_id,
           sender_handle_id,
           if(uplink?, do: :from_janus, else: :to_janus),
           lost_packets,
           nil,
           nil,
           nil,
           handler_state
         ) do
      {:noreply, new_handler_state} ->
        {:ok, state(state, handler_state: new_handler_state)}
    end
  end

  # Catch-all
  defp handle_payload(payload, state) do
    "[#{__MODULE__} #{inspect(self())}] Received unhandled payload: payload = #{inspect(payload)}"
    |> Logger.warn()

    {:ok, state}
  end

  defp handle_successful_payload(
         transaction,
         data,
         state(pending_calls_table: pending_calls_table) = state
       ) do
    Transaction.handle_transaction({:ok, data}, transaction, pending_calls_table)

    {:ok, state}
  end
end
