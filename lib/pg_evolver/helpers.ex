defmodule PgEvolver.Helpers do
  @moduledoc """
  Helper functions for SQL escaping and identifier handling.
  """

  @doc """
  Escapes a PostgreSQL identifier to prevent SQL injection.

  Quotes the identifier if it contains special characters, starts with a digit,
  or is a reserved word.

  ## Examples

      iex> PgEvolver.Helpers.escape_identifier("my_schema")
      "my_schema"

      iex> PgEvolver.Helpers.escape_identifier("My Schema")
      ~S("My Schema")

      iex> PgEvolver.Helpers.escape_identifier("select")
      ~S("select")

  """
  @spec escape_identifier(String.t()) :: String.t()
  def escape_identifier(name) when is_binary(name) do
    if needs_quoting?(name) do
      ~s("#{String.replace(name, ~s("), ~s(""))}")
    else
      name
    end
  end

  @doc """
  Escapes a PostgreSQL string literal.

  ## Examples

      iex> PgEvolver.Helpers.escape_string("hello")
      "'hello'"

      iex> PgEvolver.Helpers.escape_string("it's")
      "'it''s'"

  """
  @spec escape_string(String.t()) :: String.t()
  def escape_string(value) when is_binary(value) do
    escaped = String.replace(value, "'", "''")
    "'#{escaped}'"
  end

  defp needs_quoting?(name) do
    not Regex.match?(~r/^[a-z_][a-z0-9_]*$/, name) or reserved_word?(name)
  end

  defp reserved_word?(word) do
    word = String.downcase(word)

    word in ~w(
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
