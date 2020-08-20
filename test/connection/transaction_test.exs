defmodule Janus.Connection.TransactionTest do
  use ExUnit.Case

  alias Janus.Connection.Transaction

  setup do
    table = Transaction.init_transaction_call_table()
    transaction = Transaction.generate_transaction!(table)

    [table: table, transaction: transaction]
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
end
