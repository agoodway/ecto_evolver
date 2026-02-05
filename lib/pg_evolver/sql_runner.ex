defmodule PgEvolver.SqlRunner do
  @moduledoc """
  Executes SQL migration files with schema prefix substitution.

  SQL files use `--SPLIT--` delimiters to separate statements because:
  - Ecto's `execute()` can only handle ONE statement at a time
  - Semicolon splitting is unreliable with functions and triggers

  The `$SCHEMA$` placeholder is replaced with the actual schema name.

  ## Usage

  Typically used via `PgEvolver.Version`:

      defmodule MyLibrary.Migrations.V01 do
        use PgEvolver.Version,
          otp_app: :my_library,
          version: "01",
          sql_path: "my_library/sql/versions"
      end

  Or called directly:

      PgEvolver.SqlRunner.execute_sql_file(
        otp_app: :my_library,
        version: "01",
        direction: :up,
        sql_path: "my_library/sql/versions",
        prefix: "my_schema"
      )

  """

  import Ecto.Migration, only: [execute: 1]

  @doc """
  Executes SQL statements from a version file.

  ## Options

    * `:otp_app` - Required. The OTP app containing the priv directory.
    * `:version` - Required. Version string like "01", "02".
    * `:direction` - Required. Either `:up` or `:down`.
    * `:sql_path` - Required. Path within priv to SQL versions directory.
    * `:prefix` - Required. The schema prefix to substitute for `$SCHEMA$`.

  ## Examples

      PgEvolver.SqlRunner.execute_sql_file(
        otp_app: :pgflow,
        version: "01",
        direction: :up,
        sql_path: "pgflow_dashboard/sql/versions",
        prefix: "pgflow_dashboard"
      )

  """
  @spec execute_sql_file(keyword()) :: :ok
  def execute_sql_file(opts) do
    otp_app = Keyword.fetch!(opts, :otp_app)
    version = Keyword.fetch!(opts, :version)
    direction = Keyword.fetch!(opts, :direction)
    sql_path = Keyword.fetch!(opts, :sql_path)
    prefix = Keyword.fetch!(opts, :prefix)

    validate_version!(version)
    validate_direction!(direction)

    file_path = build_file_path(otp_app, sql_path, version, direction)

    file_path
    |> File.read!()
    |> String.replace("$SCHEMA$", PgEvolver.Helpers.escape_identifier(prefix))
    |> String.split("--SPLIT--")
    |> Enum.map(&String.trim/1)
    |> Enum.filter(&has_sql_content?/1)
    |> Enum.each(&execute/1)

    :ok
  end

  @doc """
  Returns the path to an SQL file for a given version and direction.
  """
  @spec build_file_path(atom(), String.t(), String.t(), :up | :down) :: String.t()
  def build_file_path(otp_app, sql_path, version, direction) do
    otp_app
    |> :code.priv_dir()
    |> Path.join(sql_path)
    |> Path.join("v#{version}")
    |> Path.join(sql_filename(version, direction))
  end

  defp sql_filename(version, :up), do: "v#{version}_up.sql"
  defp sql_filename(version, :down), do: "v#{version}_down.sql"

  defp validate_version!(version) when is_binary(version) do
    unless Regex.match?(~r/^\d{1,2}$/, version) do
      raise ArgumentError, "Version must be 1-2 digits, got: #{inspect(version)}"
    end
  end

  defp validate_direction!(direction) when direction in [:up, :down], do: :ok

  defp validate_direction!(direction) do
    raise ArgumentError, "Direction must be :up or :down, got: #{inspect(direction)}"
  end

  defp has_sql_content?(str) do
    str != "" and
      Regex.match?(
        ~r/\b(CREATE|DROP|ALTER|INSERT|UPDATE|DELETE|SELECT|COMMENT|GRANT|REVOKE)\b/i,
        str
      )
  end
end
