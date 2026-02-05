defmodule PgEvolver.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/agoodway/pg_evolver"

  def project do
    [
      app: :pg_evolver,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:ecto_sql, "~> 3.10"},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false}
    ]
  end

  defp description do
    """
    Versioned PostgreSQL migrations for Elixir libraries.
    Provides infrastructure for library authors to ship versioned database schemas
    that can be incrementally upgraded.
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
end
