defmodule Janus.Mock.SessionTest do
  use ExUnit.Case

  alias Janus.Mock.Session, as: MockSession

  @example_request %{
    body: %{request: "destroy", room: "room"},
    handle_id: "123",
    janus: "message"
  }
  @example_response %{"videoroom" => "destroyed", "room" => "room"}

  describe "MockSession should" do
    test "raise an error if invalid arguemnts are given to start" do
      MockSession.start_link([])
    end

    test "return unchanged message from handle_info callback" do
      assert {:reply, {:ok, @example_response}, new_state} =
               MockSession.handle_call(
                 {:execute_message, @example_request, 1, :sync_request},
                 self(),
                 %{pairs: [{@example_request, @example_response}]}
               )

      assert %{pairs: []} == new_state
    end

    test "raise an exception if request is not found in request-response list" do
      assert_raise ArgumentError, fn ->
        MockSession.handle_call(
          {:execute_message, @example_request, 1, :sync_request},
          self(),
          %{pairs: []}
        )
      end
    end

    test "raise an exception if request is send twice but its response is declared once" do
      assert {:reply, {:ok, @example_response}, new_state} =
               MockSession.handle_call(
                 {:execute_message, @example_request, 1, :sync_request},
                 self(),
                 %{pairs: [{@example_request, @example_response}]}
               )

      assert_raise ArgumentError, fn ->
        MockSession.handle_call(
          {:execute_message, @example_request, 1, :sync_request},
          self(),
          new_state
        )
      end
    end
  end

  describe "MockSession process should work in conjuction with Session module" do
    {:ok, pid} = MockSession.start_link([{@example_request, @example_response}])
    assert {:ok, @example_response} == Janus.Session.execute_request(pid, @example_request)
  end
end
