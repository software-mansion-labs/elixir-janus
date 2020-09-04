defmodule JanusIntegrationTests.MixProject do
  use Mix.Project

  def project do
    [
      app: :janus_integration,
      version: "0.1.0",
      elixir: "~> 1.10",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:elixir_janus, path: "../", override: true},
      {:elixir_janus_transport_ws, github: "software-mansion-labs/elixir-janus-transport-ws"},
      {:websockex, "~> 0.4.2"}
    ]
  end
end
