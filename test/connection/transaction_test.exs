defmodule Janus.Connection.TransactionTest do
  use ExUnit.Case
  import ExUnit.CaptureLog

  @tag :tag

  alias Janus.Connection.Transaction

  setup do
    table = Transaction.init_transaction_call_table()
    transaction = Transaction.generate_transaction!(table)

    [table: table, transaction: transaction]
  end

  describe "Handles response for up to date request" do
    setup %{table: table, transaction: transaction} do
      Transaction.insert_transaction(table, transaction, from(), 10000)
      []
    end

    test "when result is a success", %{table: table, transaction: transaction} do
      response = {:ok, %{"data" => "example"}}

      logs =
        capture_log(fn ->
          Transaction.handle_transaction(response, transaction, table)
        end)

      assert_receive {@tag, ^response}
      assert logs =~ "Call OK:"
    end

    test "when response is an error", %{table: table, transaction: transaction} do
      response = {:error, 418, "reason"}

      logs =
        capture_log(fn ->
          Transaction.handle_transaction(response, transaction, table)
        end)

      assert_receive {@tag, ^response}
      assert logs =~ "Call ERROR:"
    end
  end

  describe "Handles response when" do
    test "request is outdated", %{table: table, transaction: transaction} do
      # Deliberetely inserting outdated record
      :ets.insert(table, {transaction, from(), 0})

      logs =
        capture_log(fn ->
          Transaction.handle_transaction({:ok, %{}}, transaction, table)
        end)

      refute_receive _
      assert logs =~ "Received OK reply to the outdated call"
    end

    test "when request is unkown", %{table: table, transaction: transaction} do
      logs =
        capture_log(fn ->
          Transaction.handle_transaction({:ok, %{}}, transaction, table)
        end)

      refute_receive _
      assert logs =~ "Received OK reply to the unknown call"
    end
  end

  describe "insert_transaction adds new transaction" do
    test "with proper expiration time"
  end

  describe "transaction_status returns" do
    test ":ok tuple if transaction is up to date"
    test ":outdated error if transaction expired"
    test ":unkown error if transaction hadn't been registered"
  end

  describe "cleanup_old_transaction" do
    test "removes all expired transactions and returns ok"
    test "return noop if there were no expired transactions"
  end

  defp from(), do: {self(), @tag}
end
