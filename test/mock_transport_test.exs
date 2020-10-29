defmodule Janus.Mock.TransportTest do
  use ExUnit.Case

  alias Janus.Mock.Transport, as: MockTransport

  @request_response_pairs [
    {
      %{
        janus: :create
      },
      %{
        "janus" => "success",
        "data" => %{"id" => "session id"}
      }
    },
    {
      %{
        janus: :keepalive
      },
      %{
        "janus" => "ack"
      }
    },
    {
      %{
        janus: :keepalive
      },
      %{
        "janus" => "ack"
      }
    }
  ]

  describe "Mock.Transport should" do
    test "save request-result pairs in state" do
      assert {:ok, %{pairs: @request_response_pairs}} =
               MockTransport.connect(@request_response_pairs)
    end

    test "return unchanged message from handle_info callback" do
      msg = %{
        janus: :test
      }

      assert {:ok, ^msg, []} = MockTransport.handle_info(msg, [])
    end

    test "return valid value from keepalive_interval callback" do
      Application.put_env(:elixir_janus, MockTransport, keepalive_interval: 100)

      assert 100 == MockTransport.keepalive_interval()
    end

    test "send response to the caller" do
      {:ok, state} = MockTransport.connect(@request_response_pairs)

      request = %{
        janus: :keepalive
      }

      response = %{
        "janus" => "ack"
      }

      MockTransport.send(request, 0, state)

      assert_receive ^response
    end

    test "pass transaction field from request to the response" do
      {:ok, state} = MockTransport.connect(@request_response_pairs)

      request = %{
        janus: :keepalive,
        transaction: 1
      }

      response = %{
        "janus" => "ack",
        "transaction" => 1
      }

      MockTransport.send(request, 0, state)

      assert_receive ^response
    end

    test "remove first matched request-response pair from the list if it has been used" do
      msg = %{janus: :keepalive}

      {:ok, state} = MockTransport.connect(@request_response_pairs)
      assert length(state.pairs) == 3

      {:ok, state} = MockTransport.send(msg, 0, state)
      assert length(state.pairs) == 2
    end

    test "raise an exception if request is send twice but its response is declared once" do
      pairs = [
        {
          %{
            janus: :create
          },
          %{
            "janus" => "success"
          }
        }
      ]

      assert {:ok, state} = MockTransport.connect(pairs)
      assert {:ok, state} = MockTransport.send(%{janus: :create}, 0, state)

      assert_raise ArgumentError, fn ->
        MockTransport.send(%{janus: :create}, 0, state)
      end
    end
  end
end
