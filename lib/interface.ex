defmodule Janus.Interface do
  alias Janus.Connection

  @default_timeout 5000

  @type session :: pid()
  @type plugin_handle_id :: pos_integer
  @type opaque_id :: String.t()
  @type emitter :: String.t()
  @type plugin :: String.t()
  @type transport :: map

  @doc """
  Synchronously creates a new session on the gateway.

  ## Arguments

  * `connection` - a PID of the `Janus.Connection` process,
  * `timeout` - a timeout for the call.

  ## Return values

  On success it returns `{:ok, session}` where `session` is
  a pid of `Janus.Session` process which keeps track of
  session indentifier used by the gateway.

  On error it returns `{:error, reason}`.

  The reason might be:

  * `{:gateway, code, info}` - it means that the call itself succeded but the
    gateway returned an error of the given code and info,
  * other - some serious error happened.
  """
  @spec session_create(pid, timeout) :: {:ok, session} | {:error, any}
  def session_create(connection, timeout \\ @default_timeout) do
    case Connection.call(connection, %{janus: :create}, timeout) do
      {:ok, %{"id" => session_id}} ->
        Janus.Session.start_link(session_id, connection, [])

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Synchronously attaches a plugin to the session on the gateway.

  ## Arguments

  * `connection` - a PID of the `Janus.Connection` process,
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
  @spec session_attach(pid, session, String.t(), timeout) ::
          {:ok, plugin_handle_id} | {:error, any}
  def session_attach(connection, session, plugin, timeout \\ @default_timeout) do
    case Connection.call(
           connection,
           %{janus: :attach, plugin: plugin} |> Janus.Session.apply_fields(session),
           timeout
         ) do
      {:ok, %{"id" => plugin_handle_id}} ->
        {:ok, plugin_handle_id}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
