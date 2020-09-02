defmodule Janus.Transport.Stub.FakeTransport do
  @behaviour Janus.Transport
  @keepalive_interval 50

  @session_id 1

  def default_session_id(), do: @session_id

  @impl true
  def connect({id}) do
    {:ok, %{message_receiver: self(), id: id}}
  end

  def send(message, _timeout, %{message_receiver: receiver} = state) do
    payload = Jason.encode!(message) |> Jason.decode!()
    :ok = handle_payload(payload, receiver)
    {:ok, state}
  end

  @impl true
  def send(
        %{janus: :keepalive, transaction: transaction},
        _timeout,
        %{message_receiver: receiver} = state
      ) do
    send(receiver, %{"janus" => "ack", "transaction" => transaction})
    {:ok, state}
  end

  def send(
        %{janus: :create, transaction: transaction},
        _timeout,
        %{message_receiver: receiver} = state
      ) do
    send(receiver, %{
      "janus" => "success",
      "transaction" => transaction,
      "data" => %{"id" => @session_id}
    })

    {:ok, state}
  end

  def send(payload, _timeout, %{message_receiver: receiver, id: id} = state) do
    send(receiver, {:message, payload, id})
    {:ok, state}
  end

  @impl true
  def handle_info(payload, state) do
    {:ok, payload, state}
  end

  @impl true
  def keepalive_interval() do
    @keepalive_interval
  end

  defp handle_payload(%{"janus" => "create", "transaction" => transaction}, receiver) do
    send(receiver, %{
      "janus" => "success",
      "transaction" => transaction,
      "data" => %{"id" => @session_id}
    })

    :ok
  end

  defp handle_payload(
         %{"janus" => "keepalive", "session_id" => _session_id, "transaction" => transaction},
         receiver
       ) do
    send(receiver, %{"janus" => "ack", "transaction" => transaction})
    :ok
  end

  defp handle_payload(%{"transaction" => transaction} = msg, receiver) do
    send(receiver, %{"janus" => "success", "data" => msg, "transaction" => transaction})
    :ok
  end
end
