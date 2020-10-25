defmodule Janus.Mock do
  @moduledoc false

  @typedoc """
  Tuple element containing request and response maps.

  Response map should be compatible with formats handled by `Janus.Connection`, otherwise
  it will not be handled by mentioned module and will crash `Janus.Connection` process.
  """
  @type request_response_pair :: {request :: map(), response :: map()}

  @spec assert_pairs_shape([request_response_pair]) :: :ok
  def assert_pairs_shape(pairs) do
    Enum.each(pairs, fn pair ->
      if !match?({request, response} when is_map(request) and is_map(response), pair) do
        raise ArgumentError,
              "Expected a pair in list to be a tuple with two maps. Got #{pair} instead."
      end
    end)
  end

  @spec get_response(request :: map, [request_response_pair]) ::
          {response :: map, remaining_responses :: [request_response_pair]}
  def get_response(payload, pairs) do
    case List.keytake(pairs, payload, 0) do
      nil ->
        raise ArgumentError,
              "#{inspect(__MODULE__)}: payload's corresponding response has not been found, got: #{
                inspect(payload)
              }"

      {{_, response}, pairs} ->
        {response, pairs}
    end
  end
end
