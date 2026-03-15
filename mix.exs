defmodule EctoEvolver.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/agoodway/ecto_evolver"

  def project do
    [
      app: :ecto_evolver,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs(),
      aliases: aliases()
    ]
  end

  def cli do
    [preferred_envs: [quality: :test]]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:ecto_sql, "~> 3.13"},
      {:ex_doc, "~> 0.40", only: :dev, runtime: false},
      {:credo, "~> 1.7.17", only: [:dev, :test], runtime: false},
      {:ex_slop, "~> 0.2", only: [:dev, :test], runtime: false},
      {:ex_dna, "~> 1.2", only: [:dev, :test], runtime: false},
      {:doctor, "~> 0.22.0", only: [:dev, :test], runtime: false}
    ]
  end

  defp description do
    """
    Versioned database migrations for Elixir libraries.
    Provides infrastructure for library authors to ship versioned database schemas
    that can be incrementally upgraded. Adapter-based with PostgreSQL support.
    """
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE)
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"],
      source_url: @source_url
    ]
  end

  defp aliases do
    [
      quality: ["format --check-formatted", "credo --strict", "ex_dna", "doctor", "test"]
    ]
  end
end
