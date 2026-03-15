defmodule EctoEvolver.Helpers do
  @moduledoc """
  Generic helper functions shared across adapters.
  """

  @doc """
  Escapes a SQL string literal.

  ## Examples

      iex> EctoEvolver.Helpers.escape_string("hello")
      "'hello'"

      iex> EctoEvolver.Helpers.escape_string("it's")
      "'it''s'"

  """
  @spec escape_string(String.t()) :: String.t()
  def escape_string(value) when is_binary(value) do
    escaped = String.replace(value, "'", "''")
    "'#{escaped}'"
  end
end
