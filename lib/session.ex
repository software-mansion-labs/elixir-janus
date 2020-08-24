defmodule Janus.Session do
  @moduledoc """
  Keeps information about session and sends keep-alive messages
  if given connection's transport requires it.
  """

  @type t :: pid()
  @type message_t :: map()
  @type connection_t :: pid()
  @type timeout_t :: non_neg_integer()
  @type session_id_t :: non_neg_integer()
  @type plugin_t :: String.t()

  @type plugin_handle_id :: pos_integer

  @default_timeout 5000

  use GenServer
  alias Janus.Connection

  @doc """
  Synchronously creates a new session on the gateway.

  ## Arguments

  * `connection` - a PID of the `Janus.Connection` process,
  * `timeout` - a timeout for the call.

  ## Return values

  On success it returns `{:ok, session}` where session is
  a pid of `Janus.Session` process which keeps track of
  session indentifier used by the gateway. Session process is linked with
  calling process.

  On error it returns `{:error, reason}`.

  The reason might be:

  * `{:gateway, code, info}` - it means that the call itself succeded but the
    gateway returned an error of the given code and info,
  * other - some serious error happened.
  """
  @spec create_linked_session(connection_t(), timeout_t()) :: {:ok, Janus.Session.t()} | {:error, any}
  def create_linked_session(connection, timeout \\ @default_timeout) do
    case Connection.call(connection, %{janus: :create}, timeout) do
      {:ok, %{"id" => session_id}} ->
        start_link(session_id, connection)

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec start_link(session_id_t(), connection_t()) :: GenServer.server()
  def start_link(session_id, connection) do
    GenServer.start_link(__MODULE__, {session_id, connection}, [])
  end

  @doc """
  Synchronously attaches a plugin to the session on the gateway.

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
    case __MODULE__.execute_request(
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

  @doc """
  Replaces current connection with a new one.

  ## Arguments

  * `session` - a PID of `Janus.Session` process.
  * `connection` - a PID of `Janus.Connection` process.

  ## Return values

  Returns :ok atom.
  """
  @spec update_connection(Janus.Session.t(), connection_t()) :: :ok
  def update_connection(session, connection) do
    GenServer.cast(session, {:new_connection, connection})
  end

  # callbacks

  @impl true
  def init({session_id, connection}) do
    state = %{
      session_id: session_id,
      connection: connection
    }

    keep_alive = Janus.Connection.get_transport_module(connection).needs_keep_alive?()

    case keep_alive do
      {true, keep_alive_timeout} ->
        Process.send_after(self(), :keep_alive, keep_alive_timeout)
        {:ok, state |> Map.put(:keep_alive_timeout, keep_alive_timeout)}

      false ->
        {:ok, state}
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
          keep_alive_timeout: keep_alive_timeout
        } = state
      ) do
    Connection.call(connection, keep_alive_message(session_id))
    Process.send_after(self(), :keep_alive, keep_alive_timeout)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:new_connection, connection}, state) do
    {:noreply, %{state | connection: connection}}
  end

  defp keep_alive_message(session_id) do
    %{
      "janus" => "keepalive",
      "session_id" => session_id
    }
  end
end
