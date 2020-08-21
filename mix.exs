defmodule Janus.MixProject do
  use Mix.Project

  def project do
    [
      app: :elixir_janus,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps()
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:bunch, "~> 1.3"},
      {:ex2ms, "~> 1.0"}
    ]
  end
end
