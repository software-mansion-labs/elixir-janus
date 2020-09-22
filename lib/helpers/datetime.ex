defmodule Janus.DateTimeUtils do
  @behaviour DateTime.Behaviour

  @datetime Application.get_env(:elixir_janus, :date_time_module, DateTime)

  @impl true
  def utc_now() do
    @datetime.utc_now()
  end
end
