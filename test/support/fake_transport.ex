defmodule FakeTransport do
  # fake transport for mocking communication with janus gateway
  # mocks `send` callback to return proper gateway's responses

  @behaviour Janus.Transport
  @keepalive_interval 50

  @session_id 1

  def default_session_id(), do: @session_id

  @impl true
  def connect(opts) do
    # used to mock errors returned by Monitor/Admin API
    fail_admin_api = opts[:fail_admin_api] || false
    {:ok, %{message_receiver: self(), fail_admin_api: fail_admin_api}}
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

  def send(
        %{janus: :test, transaction: transaction, session_id: session_id},
        _timeout,
        %{message_receiver: receiver} = state
      ) do
    send(receiver, %{
      "janus" => "success",
      "session_id" => session_id,
      "transaction" => transaction,
      "data" => %{"session_id" => @session_id}
    })

    {:ok, state}
  end

  # handling admin api tests
  def send(
        %{janus: :list_sessions, transaction: _transaction} = payload,
        _timeout,
        %{message_receiver: receiver, fail_admin_api: fail} = state
      ) do
    success_msg = %{
      "janus" => "success",
      "sessions" => [1, 2, 3]
    }

    handle_admin_api_payload(receiver, payload, success_msg, fail)

    {:ok, state}
  end

  def send(
        %{janus: :list_handles, session_id: _session_id, transaction: _transaction} = payload,
        _timeout,
        %{message_receiver: receiver, fail_admin_api: fail} = state
      ) do
    success_msg = %{
      "janus" => "success",
      "handles" => [1, 2, 3]
    }

    handle_admin_api_payload(receiver, payload, success_msg, fail)

    {:ok, state}
  end

  def send(
        %{
          janus: :handle_info,
          session_id: session_id,
          handle_id: handle_id,
          transaction: _transaction
        } = payload,
        _timeout,
        %{message_receiver: receiver, fail_admin_api: fail} = state
      ) do
    success_msg = %{
      "janus" => "success",
      "session_id" => session_id,
      "handle_id" => handle_id,
      "info" => %{}
    }

    handle_admin_api_payload(receiver, payload, success_msg, fail)

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

  defp handle_admin_api_payload(receiver, payload, success_msg, fail) do
    transaction = payload[:transaction]

    msg =
      cond do
        payload[:admin_secret] == nil ->
          %{
            "janus" => "error",
            "transaction" => transaction,
            "error" => %{"code" => 403, "reason" => "unauthorized"}
          }

        fail == true ->
          %{
            "janus" => "error",
            "transaction" => transaction,
            "error" => %{"code" => 490, "reason" => "test error"}
          }

        true ->
          success_msg |> Map.put("transaction", transaction)
      end

    send(receiver, msg)
  end
end
