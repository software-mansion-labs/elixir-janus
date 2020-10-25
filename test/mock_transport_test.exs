defmodule Janus.Mock.TransportTest do
  use ExUnit.Case

  alias Janus.Mock

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
               Mock.Transport.connect(@request_response_pairs)
    end

    test "return unchanged message from handle_info callback" do
      msg = %{
        janus: :test
      }

      assert {:ok, ^msg, []} = Mock.Transport.handle_info(msg, [])
    end

    test "return valid value from keepalive_interval callback" do
      Application.put_env(:elixir_janus, Mock.Transport, keepalive_interval: 100)

      assert 100 == Mock.Transport.keepalive_interval()
    end

    test "send response to the caller" do
      {:ok, state} = Mock.Transport.connect(@request_response_pairs)

      request = %{
        janus: :keepalive
      }

      response = %{
        "janus" => "ack"
      }

      Mock.Transport.send(request, 0, state)

      assert_receive ^response
    end

    test "pass transaction field from request to the response" do
      {:ok, state} = Mock.Transport.connect(@request_response_pairs)

      request = %{
        janus: :keepalive,
        transaction: 1
      }

      response = %{
        "janus" => "ack",
        "transaction" => 1
      }

      Mock.Transport.send(request, 0, state)

      assert_receive ^response
    end

    test "remove first matched request-response pair from the list if it has been used" do
      msg = %{janus: :keepalive}

      {:ok, state} = Mock.Transport.connect(@request_response_pairs)
      assert length(state.pairs) == 3

      {:ok, state} = Mock.Transport.send(msg, 0, state)
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

      assert {:ok, state} = Mock.Transport.connect(pairs)
      assert {:ok, state} = Mock.Transport.send(%{janus: :create}, 0, state)

      assert_raise ArgumentError, fn ->
        Mock.Transport.send(%{janus: :create}, 0, state)
      end
    end
  end
end
