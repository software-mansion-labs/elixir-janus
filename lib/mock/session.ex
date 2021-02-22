defmodule Janus.Mock.Session do
  @moduledoc """
  Provides a way to mock reponses from `Janus.Session` module.

  ## Example
  ```
  {:ok, session} =
    MockSession.start_link([
      {
        %{body: %{request: "destroy", room: "room"}, handle_id: ctx.handle, janus: "message"},
        %{"videoroom" => "destroyed", "room" => "room"}
      }
    ])
  assert {:ok, "room_id"} = VideoRoom.destroy(session, "room_id")
  ```
  """
  use GenServer

  @spec start_link([Janus.Mock.request_response_pair()]) :: GenServer.on_start()
  def start_link(pairs) when is_list(pairs) do
    Janus.Mock.assert_pairs_shape(pairs)
    GenServer.start_link(__MODULE__, pairs)
  end

  @doc """
  Returns count of remaining calls request and response pairs.

  If this function returns 0 it means that all scheduled calls have been made.
  """
  @spec remaining_calls(GenServer.server()) :: non_neg_integer()
  def remaining_calls(mock) do
    GenServer.call(mock, :remaining_calls)
  end

  @impl true
  def init(pairs) do
    {:ok, %{pairs: pairs}}
  end

  @impl true
  def handle_call(
        {:execute_message, message, _timeout, _call_type},
        _from,
        %{pairs: pairs} = state
      ) do
    {response, pairs} = Janus.Mock.get_response(message, pairs)

    {:reply, {:ok, response}, %{state | pairs: pairs}}
  end

  def handle_call(:remaining_calls, _sender, %{pairs: pairs} = state) do
    {:reply, Enum.count(pairs), state}
  end

  def handle_call(:get_session_id, _from, state) do
    {:reply, 1_112_477_820, state}
  end

  @impl true
  def handle_info(:keep_alive, state) do
    {:noreply, state}
  end
end
