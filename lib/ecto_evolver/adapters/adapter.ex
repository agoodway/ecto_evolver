defmodule EctoEvolver.Adapters.Adapter do
  @moduledoc """
  Behaviour for database-specific migration operations.

  Adapters handle version tracking and SQL escaping. EctoEvolver auto-detects
  the correct adapter from your Ecto repo at runtime.

  Currently supported:

    * `EctoEvolver.Adapters.Postgres` - PostgreSQL
  """

  @doc "Reads the current migrated version. Returns `0` if not yet migrated."
  @callback get_version(
              repo :: module(),
              prefix :: String.t(),
              tracking_object :: {:view | :table | :materialized_view, String.t()}
            ) :: non_neg_integer()

  @doc "Writes the migration version after a successful migration."
  @callback set_version(
              prefix :: String.t(),
              tracking_object :: {:view | :table | :materialized_view, String.t()},
              version :: non_neg_integer(),
              label :: String.t()
            ) :: :ok

  @doc "Escapes a database identifier (schema name, table name, etc.)."
  @callback escape_identifier(identifier :: String.t()) :: String.t()

  @doc "Escapes a string literal for use in SQL statements."
  @callback escape_string(value :: String.t()) :: String.t()

  @doc "Resolves an EctoEvolver adapter from an Ecto adapter module."
  @spec resolve(module()) :: {:ok, module()} | {:error, :unsupported_adapter}
  def resolve(Ecto.Adapters.Postgres), do: {:ok, EctoEvolver.Adapters.Postgres}
  def resolve(_), do: {:error, :unsupported_adapter}
end
