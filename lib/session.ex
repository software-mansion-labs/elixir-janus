defmodule Janus.Session do
  @moduledoc """
  Keeps information about session and sends keep-alive messages
  if given connection's transport requires it.
  """

  use GenServer
  alias Janus.Connection

  @default_timeout 5000

  @type t :: GenServer.server()
  @type message_t :: map()
  @type timeout_t :: non_neg_integer()
  @type session_id_t :: non_neg_integer()
  @type plugin_t :: String.t()

  @type plugin_handle_id :: pos_integer

  @doc """
  Starts the session and links it to the current
  process.

  ## Arguments

  * `connection` - a PID of the `Janus.Connection` process,
  * `timeout` - a timeout for the call.

  ## Return values

  Returns the same values as `GenServer.start_link/3`.

  If session fails to start the reason might be:
  * `{:gateway, code, info}` - it means that the call itself succeded but the
    gateway returned an error of the given code and info,
  * other - some serious error happened.
  """
  @spec start_link(Connection.t(), timeout_t()) :: {:ok, Janus.Session.t()} | {:error, any}
  def start_link(connection, timeout \\ @default_timeout),
    do: do_start(:start_link, connection, timeout)

  @doc """
  Works the same as `start_link/2` but does not link the process.
  """
  @spec start(Connection.t(), timeout_t()) :: {:ok, Janus.Session.t()} | {:error, any}
  def start(connection, timeout \\ @default_timeout), do: do_start(:start, connection, timeout)

  defp do_start(method, connection, timeout) do
    apply(GenServer, method, [__MODULE__, {connection, timeout}, []])
  end

  @doc """
  Synchronously attaches to a plugin via session on the gateway.

  ## Arguments

  * `session` - a PID of the `Janus.Session` process,
  * `plugin` - a string containing valid gateway's plugin name,
  * `timeout` - a timeout for the call.

  ## Return values

  On success it returns `{:ok, plugin_handle_id}` where `plugin_handle_id` is
  a positive integer which is used as internal plugin handle identifier by the
  gateway.

  On error it returns `{:error, reason}`.

  The reason might be:

  * `{:gateway, code, info}` - it means that the call itself succeded but the
    gateway returned an error of the given code and info,
  * other - some serious error happened.
  """
  @spec session_attach(Janus.Session.t(), plugin_t(), timeout_t()) ::
          {:ok, plugin_handle_id} | {:error, any}
  def session_attach(session, plugin, timeout \\ @default_timeout) do
    case execute_request(
           session,
           %{janus: :attach, plugin: plugin},
           timeout
         ) do
      {:ok, %{"id" => plugin_handle_id}} ->
        {:ok, plugin_handle_id}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Adds `session_id` to given message and sends it through connection stored by given session.

  ## Arguments

  * `session` - a PID of `Janus.Session` process.
  * `message` - map containing message request.
  * `timeout` - timeout passed to `Janus.Connection.call/3`.

  ## Return values

  Returns response same as `Janus.Connection.call/3`.
  """
  @spec execute_request(Janus.Session.t(), message_t(), timeout_t()) :: {:ok, any} | {:error, any}
  def execute_request(session, message, timeout \\ @default_timeout) do
    GenServer.call(session, {:execute_message, message, timeout})
  end

  # callbacks

  @impl true
  def init({connection, timeout}) do
    Process.monitor(connection)

    case Connection.call(connection, %{janus: :create}, timeout) do
      {:ok, %{"id" => session_id}} ->
        state = %{session_id: session_id, connection: connection}

        interval = Connection.get_transport_module(connection).keepalive_interval()

        state =
          case interval do
            nil ->
              state

            interval ->
              Process.send_after(self(), :keep_alive, interval)
              Map.put(state, :keepalive_interval, interval)
          end

        {:ok, state}

      # TODO: handle positive errors
      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def handle_call(
        {:execute_message, message, timeout},
        _from,
        %{connection: connection, session_id: session_id} = state
      ) do
    message = Map.put(message, "session_id", session_id)
    response = Connection.call(connection, message, timeout)

    {:reply, response, state}
  end

  def handle_call(:get_session_id, _from, %{session_id: session_id} = state) do
    {:reply, session_id, state}
  end

  @impl true
  def handle_info(
        :keep_alive,
        %{
          session_id: session_id,
          connection: connection,
          keepalive_interval: interval
        } = state
      ) do
    Connection.call(connection, keep_alive_message(session_id))
    Process.send_after(self(), :keep_alive, interval)
    {:noreply, state}
  end

  def handle_info({:DOWN, _ref, :process, object, reason}, %{connection: conn} = state)
      when object == conn do
    {:stop, {:connection, reason}, state}
  end

  @impl true
  def handle_cast({:new_connection, connection}, state) do
    {:noreply, %{state | connection: connection}}
  end

  defp keep_alive_message(session_id) do
    %{
      janus: :keepalive,
      session_id: session_id
    }
  end
end
