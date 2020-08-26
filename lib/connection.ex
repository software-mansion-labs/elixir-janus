defmodule Janus.Connection do
  use GenServer
  use Bunch
  # use Bitwise
  require Record
  require Logger

  alias Janus.Connection.Transaction

  @default_timeout 5000
  @cleanup_interval 60000

  Record.defrecordp(:state,
    transport_module: nil,
    transport_state: nil,
    handler_module: nil,
    handler_state: nil,
    pending_calls_table: nil
  )

  @doc """
  Starts the new connection to the gateway and links it to the current
  process. The connection is transport-agnostic. The gateway supports
  multiple means of accesing its API and this module can use any of them.

  ## Arguments

  * `transport_module` - a module that implements `Wembrane.Gateway.Transport`
    behaviour, responsible for handling the actual data flow to and from
    the gateway,
  * `transport_args` - a transport module-specific argument that will be
    passed to the `c:Wembrane.Gateway.Transport.connect/1` callback.
  * `handler_module` - a module that implements `Wembrane.Gateway.Handler`
    behaviour, responsible for handling the callbacks sent from the gateway,
  * `handler_args` - a handler module-specific argument that will be
    passed to the `c:Wembrane.Gateway.Handler.init/1` callback.
  * `options` - process options, as in `GenServer.start_link/3`.

  ## Return values

  Returns the same values as `GenServer.start_link/3`.
  """
  @spec start_link(module, any, module, any, GenServer.options()) :: GenServer.on_start()
  def start_link(transport_module, transport_args, handler_module, handler_args, options \\ []) do
    GenServer.start_link(
      __MODULE__,
      {transport_module, transport_args, handler_module, handler_args},
      options
    )
  end

  @doc """
  Calls the gateway in synchronous manner.

  The underlying gateway API is asynchronous but that will wait until the reply
  is returned or until given timeout passes.

  See the [gateway's API documentation](https://janus.conf.meetecho.com/docs/rest.html)
  for list of valid payloads that can be sent.

  ## Arguments

  * `server` - a PID of the `Wembrane.Gateway.Connection` process,
  * `payload` - a map that can be later safely serialized to JSON according to the
    gateway's API but without the `transaction` key as it will be injected
    automatically,
  * `timeout` - a valid timeout, in milliseconds.

  ## Return values

  On success it returns `{:ok, payload}`, where `payload` is a map that contains
  response as defined in the gateway API.

  On error it returns `{:error, reason}`.

  The reason might be:

  * `{:gateway, code, info}` - it means that the call itself succeded but the
    gateway returned an error of the given code and info.
  """
  @spec call(GenServer.server(), map, timeout) :: {:ok, any} | {:error, any}
  def call(server, payload, timeout \\ @default_timeout) do
    GenServer.call(server, {:call, payload, timeout}, timeout)
  end

  # Callbacks

  @impl true
  def init({transport_module, transport_args, handler_module, handler_args}) do
    Logger.debug(
      "[#{__MODULE__} #{inspect(self())}] Init: transport_module = #{inspect(transport_module)}, handler_module = #{
        inspect(handler_module)
      }"
    )

    withl handler: {:ok, handler_state} <- handler_module.init(handler_args),
          connect: {:ok, transport_state} <- transport_module.connect(transport_args) do
      pending_calls_table = Transaction.init_transaction_call_table()

      Process.send_after(self(), :cleanup, @cleanup_interval)

      {:ok,
       state(
         transport_module: transport_module,
         transport_state: transport_state,
         handler_module: handler_module,
         handler_state: handler_state,
         pending_calls_table: pending_calls_table
       )}
    else
      handler: {:error, reason} ->
        {:stop, {:handler, reason}}

      connect: {:error, reason} ->
        {:stop, {:connect, reason}}
    end
  end

  @impl true
  def handle_call(
        {:call, payload, timeout},
        from,
        state(
          transport_module: transport_module,
          transport_state: transport_state,
          pending_calls_table: pending_calls_table
        ) = s
      ) do
    transaction = Transaction.insert_transaction(pending_calls_table, from, timeout)
    payload_with_transaction = Map.put(payload, :transaction, transaction)

    "[#{__MODULE__} #{inspect(self())}] Call: transaction = #{inspect(transaction)}, payload = #{
      inspect(payload)
    }"
    |> Logger.debug()

    case transport_module.send(payload_with_transaction, timeout, transport_state) do
      {:ok, new_transport_state} ->
        {:noreply, state(s, transport_state: new_transport_state)}

      {:error, reason} ->
        "[#{__MODULE__} #{inspect(self())}] Transport send error: reason = #{inspect(reason)}"
        |> Logger.error()

        # TODO check if this is correct return value
        {:stop, {:call, reason}, s}
    end
  end

  @impl true
  def handle_info(:cleanup, state(pending_calls_table: pending_calls_table) = s) do
    Transaction.cleanup_old_transactions(pending_calls_table)
    Process.send_after(self(), :cleanup, @cleanup_interval)
    {:noreply, s}
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

  # Handles payload which is a success response to the call
  defp handle_payload(
         %{"janus" => "success", "transaction" => transaction} = response,
         state(pending_calls_table: pending_calls_table) = state
       ) do
    data = response["data"] || response["plugindata"]["data"]
    Transaction.handle_transaction({:ok, data}, transaction, pending_calls_table)
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
    Transaction.handle_transaction(
      {:error, {:gateway, code, reason}},
      transaction,
      pending_calls_table
    )

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

  # Handles event without subtype FIXME
  defp handle_payload(
         %{"emitter" => emitter, "event" => event, "type" => type, "timestamp" => timestamp},
         state(handler_module: _handler_module, handler_state: _handler_state) = s
       ) do
    "[#{__MODULE__} #{inspect(self())}] Event: emitter = #{inspect(emitter)}, event = #{
      inspect(event)
    }, type = #{inspect(type)}, timestamp = #{inspect(timestamp)}"
    |> Logger.debug()

    {:ok, s}
    # case handler_module.handle_detached(session_id, sender, handler_state) do
    #   {:noreply, new_handler_state} ->
    #     {:ok, state(s, handler_state: new_handler_state)}
    # end
  end

  # Payloads related to the events might come batched in lists, handle them recusively
  defp handle_payload([head | tail], s) do
    case handle_payload(head, s) do
      {:ok, new_state} ->
        handle_payload(tail, new_state)
    end
  end

  defp handle_payload([], s) do
    {:ok, s}
  end

  # Catch-all
  defp handle_payload(payload, s) do
    "[#{__MODULE__} #{inspect(self())}] Received unhandled payload: payload = #{inspect(payload)}"
    |> Logger.warn()

    {:ok, s}
  end
end
