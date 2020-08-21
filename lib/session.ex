defmodule Janus.Session do
  @moduledoc """
  Keeps information about session and sends keep-alive messages
  if given connection's transport requires it.
  """

  @type session_t :: pid()
  @type message_t :: map()
  @type connection_t :: pid()

  use GenServer
  alias Janus.Connection

  def start_link(session_id, connection, opts) do
    GenServer.start_link(__MODULE__, {session_id, connection, opts}, [])
  end

  @doc """
  Adds `session_id` field and parses additional fields to merge them to given message.

  ## Arguments

  * `message` - message to append new fields to.
  * `session` - a pid of `Janus.Session` process.
  * `fields` - keyword list of additional fields to be merged to message.

  ## Return values

  Returns given message map with merged new fields.
  """
  @spec apply_fields(message_t(), session_t(), Keyword.t()) :: map()
  def apply_fields(message, session, fields \\ []) do
    session_id = GenServer.call(session, :get_session_id)

    fields =
      fields
      |> Enum.map(fn {key, value} -> {Atom.to_string(key), value} end)
      |> Enum.into(%{})

    message
    |> Map.put("session_id", session_id)
    |> Map.merge(fields)
  end

  @doc """
  Replaces current connection with a new one.

  ## Arguments

  * `session` - a PID of `Janus.Session` process.
  * `connection` - a PID of `Janus.Connection` process.

  ## Return values

  Returns :ok atom.
  """
  @spec update_connection(session_t(), connection_t()) :: :ok
  def update_connection(session, connection) do
    GenServer.cast(session, {:new_connection, connection})
  end

  # callbacks

  @impl true
  def init({session_id, connection, _opts}) do
    state = %{
      session_id: session_id,
      connection: connection
    }

    keep_alive = Janus.Connection.get_module(connection, :transport).needs_keep_alive?()

    case keep_alive do
      {true, keep_alive_timeout} ->
        Process.send_after(self(), :keep_alive, keep_alive_timeout)
        {:ok, state |> Map.put(:keep_alive_timeout, keep_alive_timeout)}

      false ->
        {:ok, state}
    end
  end

  @impl true
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
