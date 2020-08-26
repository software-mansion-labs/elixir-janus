defmodule Janus.Connection.TransactionTest do
  alias Janus.Connection.Transaction
  import ExUnit.CaptureLog
  use ExUnit.Case

  @tag :tag
  @timeout 5000
  @now %DateTime{
    year: 2000,
    month: 2,
    day: 29,
    zone_abbr: "CET",
    hour: 23,
    minute: 0,
    second: 7,
    utc_offset: 3600,
    std_offset: 0,
    time_zone: "Etc/UTC"
  }

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
    test "with proper expiration time", %{table: table, transaction: transaction} do
      Transaction.insert_transaction(table, transaction, from(), @timeout, @now)

      expires =
        @now
        |> DateTime.add(@timeout, :millisecond)
        |> DateTime.to_unix(:millisecond)

      assert [{_, _, ^expires}] = :ets.lookup(table, transaction)
    end
  end

  describe "transaction_status returns" do
    setup %{table: table, transaction: transaction} do
      Transaction.insert_transaction(table, transaction, from(), @timeout, @now)
      []
    end

    test ":ok tuple if transaction is up to date", %{table: table, transaction: transaction} do
      future = @now |> DateTime.add(@timeout, :millisecond)
      assert {:ok, _} = Transaction.transaction_status(table, transaction, future)
    end

    test ":outdated error if transaction expired", %{table: table, transaction: transaction} do
      future = @now |> DateTime.add(@timeout + 1, :millisecond)
      assert {:error, :outdated} = Transaction.transaction_status(table, transaction, future)
    end

    test ":unkown error if transaction hadn't been registered", %{table: table} do
      transaction = Transaction.generate_transaction!(table)
      assert {:error, :unknown} == Transaction.transaction_status(table, transaction)
    end
  end

  describe "cleanup_old_transaction" do
    setup %{table: table, transaction: first_transaction} do
      first_timeout = @timeout
      Transaction.insert_transaction(table, first_transaction, from(), first_timeout, @now)

      next_transaction = Transaction.generate_transaction!(table)
      next_timeout = first_timeout + @timeout
      Transaction.insert_transaction(table, next_transaction, from(), next_timeout, @now)

      [first_timeout: first_timeout, next_timeout: next_timeout]
    end

    test "removes all expired transactions if part was expired and returns ok", %{
      first_timeout: first_timeout,
      table: table
    } do
      future = @now |> DateTime.add(first_timeout + 1, :millisecond)

      logs =
        capture_log(fn ->
          assert Transaction.cleanup_old_transactions(table, future)
        end)

      refute_receive _
      assert logs =~ "Cleanup: cleaned up 1 outdated transaction(s)"
    end

    test "removes all expired transactions if all were expired and returns ok", %{
      next_timeout: next_timeout,
      table: table
    } do
      future = @now |> DateTime.add(next_timeout + 1, :millisecond)

      logs =
        capture_log(fn ->
          assert Transaction.cleanup_old_transactions(table, future)
        end)

      refute_receive _
      assert logs =~ "Cleanup: cleaned up 2 outdated transaction(s)"
    end

    test "return noop if there were no expired transactions", %{
      first_timeout: first_timeout,
      table: table
    } do
      future = @now |> DateTime.add(first_timeout - 1, :millisecond)

      logs =
        capture_log(fn ->
          assert not Transaction.cleanup_old_transactions(table, future)
        end)

      refute_receive _
      assert logs =~ "Cleanup: no outdated transactions found"
    end
  end

  defp from(), do: {self(), @tag}
end
