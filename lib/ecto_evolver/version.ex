defmodule EctoEvolver.Version do
  @moduledoc """
  Behaviour and macro for defining version migration modules.

  Each version module represents a single migration step with `up/1` and `down/1`
  that execute SQL files from the `priv/` directory.

  ## Usage

      defmodule MyLibrary.Migrations.V01 do
        use EctoEvolver.Version,
          otp_app: :my_library,
          version: "01",
          sql_path: "my_library/sql/versions"
      end

  ## Options

    * `:otp_app` - The OTP application containing the SQL files.
    * `:version` - Version string like `"01"`, `"02"`.
    * `:sql_path` - Path within `priv/` to the SQL versions directory.

  ## SQL File Layout

      priv/<sql_path>/v<version>/v<version>_up.sql
      priv/<sql_path>/v<version>/v<version>_down.sql
  """

  @doc "Applies the migration (create tables, views, etc.)."
  @callback up(keyword()) :: :ok

  @doc "Rolls back the migration (drop tables, views, etc.)."
  @callback down(keyword()) :: :ok

  @doc false
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @behaviour EctoEvolver.Version

      @otp_app Keyword.fetch!(opts, :otp_app)
      @version Keyword.fetch!(opts, :version)
      @sql_path Keyword.fetch!(opts, :sql_path)

      @doc "Applies this version's migration by executing the up SQL file."
      @impl EctoEvolver.Version
      @spec up(keyword()) :: :ok
      def up(opts \\ []) do
        EctoEvolver.SqlRunner.execute_sql_file(
          otp_app: @otp_app,
          version: @version,
          direction: :up,
          sql_path: @sql_path,
          prefix: Keyword.fetch!(opts, :prefix)
        )
      end

      @doc "Rolls back this version's migration by executing the down SQL file."
      @impl EctoEvolver.Version
      @spec down(keyword()) :: :ok
      def down(opts \\ []) do
        EctoEvolver.SqlRunner.execute_sql_file(
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
