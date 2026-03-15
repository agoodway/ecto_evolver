defmodule EctoEvolver.SqlRunner do
  @moduledoc """
  Executes SQL migration files with schema prefix substitution.

  SQL files use `--SPLIT--` delimiters to separate statements (Ecto's
  `execute/1` handles one statement at a time, and semicolon splitting
  is unreliable with functions and triggers).

  The `$SCHEMA$` placeholder is replaced with the actual schema name.
  """

  import Ecto.Migration, only: [execute: 1]

  @doc """
  Executes SQL statements from a version file.

  ## Options

    * `:otp_app` - The OTP app containing the `priv/` directory.
    * `:version` - Version string like `"01"`, `"02"`.
    * `:direction` - `:up` or `:down`.
    * `:sql_path` - Path within `priv/` to SQL versions directory.
    * `:prefix` - Schema prefix to substitute for `$SCHEMA$`.
    * `:adapter` - Adapter module for identifier escaping (defaults to Postgres).
  """
  @spec execute_sql_file(keyword()) :: :ok
  def execute_sql_file(opts) do
    otp_app = Keyword.fetch!(opts, :otp_app)
    version = Keyword.fetch!(opts, :version)
    direction = Keyword.fetch!(opts, :direction)
    sql_path = Keyword.fetch!(opts, :sql_path)
    prefix = Keyword.fetch!(opts, :prefix)
    adapter = Keyword.get(opts, :adapter, EctoEvolver.Adapters.Postgres)

    validate_version!(version)
    validate_direction!(direction)

    file_path = build_file_path(otp_app, sql_path, version, direction)

    file_path
    |> File.read!()
    |> String.replace("$SCHEMA$", adapter.escape_identifier(prefix))
    |> String.split("--SPLIT--")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&empty_or_comment_only?/1)
    |> Enum.each(&execute/1)

    :ok
  end

  @doc "Builds the path to a SQL file for a given version and direction."
  @spec build_file_path(atom(), String.t(), String.t(), :up | :down) :: String.t()
  def build_file_path(otp_app, sql_path, version, direction) do
    otp_app
    |> :code.priv_dir()
    |> Path.join(sql_path)
    |> Path.join("v#{version}")
    |> Path.join("v#{version}_#{direction}.sql")
  end

  defp validate_version!(version) when is_binary(version) do
    unless Regex.match?(~r/^\d{1,2}$/, version) do
      raise ArgumentError, "Version must be 1-2 digits, got: #{inspect(version)}"
    end
  end

  defp validate_direction!(:up), do: :ok
  defp validate_direction!(:down), do: :ok

  defp validate_direction!(direction) do
    raise ArgumentError, "Direction must be :up or :down, got: #{inspect(direction)}"
  end

  defp empty_or_comment_only?(chunk) do
    stripped =
      chunk
      |> String.split("\n")
      |> Enum.reject(&line_is_comment_or_blank?/1)
      |> Enum.join()
      |> String.trim()

    stripped == ""
  end

  defp line_is_comment_or_blank?(line) do
    trimmed = String.trim(line)
    trimmed == "" or String.starts_with?(trimmed, "--")
  end
end
