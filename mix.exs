defmodule Elixir.Janus.MixProject do
  use Mix.Project

  @version "0.1.0"
  @github_url "https://github.com/software-mansion-labs/elixir-janus"

  def project do
    [
      app: :elixir_janus,
      version: @version,
      elixir: "~> 1.10",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # hex
      description: "Package for communicating with Janus Gateway",
      package: package(),

      # docs
      name: "Elixir Janus",
      source_url: @github_url,
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_env), do: ["lib"]

  defp deps do
    [
      {:bunch, "~> 1.3"},
      {:ex2ms, "~> 1.0"},
      {:jason, "~> 1.2", only: :test},
      {:ex_doc, "~> 0.22", only: [:test, :dev], runtime: false}
    ]
  end

  defp package do
    [
      maintainers: ["Software Mansion Team"],
      licenses: ["Apache 2.0"],
      links: %{
        "GitHub" => @github_url
      }
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "LICENSE"],
      source_ref: "v#{@version}"
    ]
  end
end
