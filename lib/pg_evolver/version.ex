defmodule PgEvolver.Version do
  @moduledoc """
  Behaviour and macro for defining version migration modules.

  Each version module represents a single migration version with up/down functions
  that execute SQL files from the priv directory.

  ## Usage

      defmodule MyLibrary.Migrations.V01 do
        use PgEvolver.Version,
          otp_app: :my_library,
          version: "01",
          sql_path: "my_library/sql/versions"
      end

  This generates:

      def up(opts), do: PgEvolver.SqlRunner.execute_sql_file(...)
      def down(opts), do: PgEvolver.SqlRunner.execute_sql_file(...)

  ## Options

    * `:otp_app` - Required. The OTP application containing the SQL files.
    * `:version` - Required. Version string like "01", "02".
    * `:sql_path` - Required. Path within priv to the SQL versions directory.

  ## SQL File Structure

  SQL files should be placed in:

      priv/<sql_path>/v<version>/v<version>_up.sql
      priv/<sql_path>/v<version>/v<version>_down.sql

  For example:

      priv/my_library/sql/versions/v01/v01_up.sql
      priv/my_library/sql/versions/v01/v01_down.sql

  """

  @doc """
  Callback for applying the migration (create objects).
  """
  @callback up(keyword()) :: :ok

  @doc """
  Callback for rolling back the migration (drop objects).
  """
  @callback down(keyword()) :: :ok

  @doc false
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @behaviour PgEvolver.Version

      @otp_app Keyword.fetch!(opts, :otp_app)
      @version Keyword.fetch!(opts, :version)
      @sql_path Keyword.fetch!(opts, :sql_path)

      @impl PgEvolver.Version
      def up(opts \\ []) do
        PgEvolver.SqlRunner.execute_sql_file(
          otp_app: @otp_app,
          version: @version,
          direction: :up,
          sql_path: @sql_path,
          prefix: Keyword.fetch!(opts, :prefix)
        )
      end

      @impl PgEvolver.Version
      def down(opts \\ []) do
        PgEvolver.SqlRunner.execute_sql_file(
          otp_app: @otp_app,
          version: @version,
          direction: :down,
          sql_path: @sql_path,
          prefix: Keyword.fetch!(opts, :prefix)
        )
      end

      defoverridable up: 1, down: 1
    end
  end
end
