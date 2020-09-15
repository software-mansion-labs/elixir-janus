defmodule Janus.Connection.TransactionTest do
  use ExUnit.Case

  import ExUnit.CaptureLog

  alias Janus.Connection.Transaction

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
  @test_transaction "A very unique string"

  setup do
    table = Transaction.init_transaction_call_table(__MODULE__)

    [table: table]
  end

  describe "Handles response for up to date request" do
    setup %{table: table} do
      [transaction: Transaction.insert_transaction(table, from(), 10000, :sync_request)]
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
      response = {:error, {:gateway, 418, "reason"}}

      logs =
        capture_log(fn ->
          Transaction.handle_transaction(response, transaction, table)
        end)

      assert_receive {@tag, ^response}
      assert logs =~ "Call ERROR:"
    end
  end

  describe "Handles response when" do
    test "request is outdated", %{table: table} do
      # Deliberetely inserting outdated record
      :ets.insert(table, {@test_transaction, from(), 0, :sync_request})

      logs =
        capture_log(fn ->
          Transaction.handle_transaction({:ok, %{}}, @test_transaction, table)
        end)

      refute_receive _
      assert logs =~ "Received OK reply to the outdated call"
    end

    test "when request is unkown", %{table: table} do
      logs =
        capture_log(fn ->
          Transaction.handle_transaction({:ok, %{}}, @test_transaction, table)
        end)

      refute_receive _
      assert logs =~ "Received OK reply to the unknown_transaction call"
    end
  end

  describe "insert_transaction" do
    test "adds new transaction with proper expiration time", %{table: table} do
      expires =
        @now
        |> DateTime.add(@timeout, :millisecond)
        |> DateTime.to_unix(:millisecond)

      transaction = Transaction.insert_transaction(table, from(), @timeout, :sync_request, @now)

      assert [{_, _, ^expires, _}] = :ets.lookup(table, transaction)
    end

    test "raises an error when tried too many_times", %{table: table} do
      assert_raise(RuntimeError, "Could not insert transaction", fn ->
        Transaction.insert_transaction(table, from(), @timeout, :sync_request, @now, 0)
      end)
    end
  end

  describe "transaction_status returns" do
    setup %{table: table} do
      [transaction: Transaction.insert_transaction(table, from(), @timeout, :sync_request, @now)]
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
      transaction = "Unkown unique string"
      assert {:error, :unknown_transaction} == Transaction.transaction_status(table, transaction)
    end
  end

  describe "cleanup_old_transaction" do
    setup %{table: table} do
      first_timeout = @timeout
      Transaction.insert_transaction(table, from(), first_timeout, :sync_request, @now)

      next_timeout = first_timeout + @timeout
      Transaction.insert_transaction(table, from(), next_timeout, :sync_request, @now)

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
