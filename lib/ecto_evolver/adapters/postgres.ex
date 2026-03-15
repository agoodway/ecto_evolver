defmodule EctoEvolver.Adapters.Postgres do
  @moduledoc """
  PostgreSQL adapter for EctoEvolver.

  Tracks migration versions via PostgreSQL object comments using `COMMENT ON`.
  Queries `pg_class` and `pg_namespace` to read version information.
  """

  @behaviour EctoEvolver.Adapters.Adapter

  import Ecto.Migration, only: [execute: 1]

  @impl true
  @spec get_version(module(), String.t(), {atom(), String.t()}) :: non_neg_integer()
  def get_version(repo, prefix, {object_type, object_name}) do
    query = """
    SELECT obj_description(c.oid)
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = $1 AND c.relname = $2 AND c.relkind = '#{relkind(object_type)}'
    """

    case repo.query(query, [prefix, object_name]) do
      {:ok, %{rows: [[comment]]}} when is_binary(comment) ->
        parse_version(comment)

      _ ->
        0
    end
  end

  @impl true
  @spec set_version(String.t(), {atom(), String.t()}, non_neg_integer(), String.t()) :: :ok
  def set_version(prefix, {object_type, object_name}, version, label) do
    escaped_prefix = escape_identifier(prefix)
    escaped_name = escape_identifier(object_name)
    escaped_comment = EctoEvolver.Helpers.escape_string("#{label} version=#{version}")

    execute(
      "COMMENT ON #{object_keyword(object_type)} #{escaped_prefix}.#{escaped_name} IS #{escaped_comment}"
    )

    :ok
  end

  @impl true
  @spec escape_identifier(String.t()) :: String.t()
  def escape_identifier(name) when is_binary(name) do
    if needs_quoting?(name) do
      ~s("#{String.replace(name, ~s("), ~s(""))}")
    else
      name
    end
  end

  @impl true
  @spec escape_string(String.t()) :: String.t()
  defdelegate escape_string(value), to: EctoEvolver.Helpers

  # PostgreSQL relkind codes
  defp relkind(:view), do: "v"
  defp relkind(:table), do: "r"
  defp relkind(:materialized_view), do: "m"

  # SQL keywords for COMMENT ON
  defp object_keyword(:view), do: "VIEW"
  defp object_keyword(:table), do: "TABLE"
  defp object_keyword(:materialized_view), do: "MATERIALIZED VIEW"

  defp parse_version(comment) do
    case Regex.run(~r/version=(\d+)/, comment) do
      [_, version] -> String.to_integer(version)
      _ -> 0
    end
  end

  defp needs_quoting?(name) do
    not Regex.match?(~r/^[a-z_][a-z0-9_]*$/, name) or reserved_word?(name)
  end

  defp reserved_word?(word) do
    String.downcase(word) in ~w(
      all analyse analyze and any array as asc asymmetric authorization between
      binary both case cast check collate collation column concurrently constraint
      create cross current_catalog current_date current_role current_schema
      current_time current_timestamp current_user default deferrable desc distinct
      do else end except exists explain false fetch for foreign freeze from full
      grant group having ilike in initially inner intersect into is isnull join
      lateral leading left like limit localtime localtimestamp natural not notnull
      null offset on only or order outer overlaps placing primary references
      returning right select session_user similar some symmetric table tablesample
      then to trailing true union unique user using variadic verbose when where
      window with
    )
  end
end
