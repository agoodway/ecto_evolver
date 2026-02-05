defmodule PgEvolver do
  @moduledoc """
  Versioned PostgreSQL migrations for Elixir libraries.

  PgEvolver provides infrastructure for library authors to ship versioned database
  schemas that can be incrementally upgraded. It tracks migration versions via
  PostgreSQL comments and supports both forward migrations and rollbacks.

  ## Usage

  Define a migration module in your library:

      defmodule MyLibrary.Migration do
        use PgEvolver,
          otp_app: :my_library,
          default_prefix: "my_library",
          versions: [MyLibrary.Migrations.V01, MyLibrary.Migrations.V02],
          tracking_object: {:view, "my_main_view"}
      end

  Then users generate an Ecto migration that calls your module:

      defmodule MyApp.Repo.Migrations.AddMyLibrary do
        use Ecto.Migration

        def up, do: MyLibrary.Migration.up()
        def down, do: MyLibrary.Migration.down()
      end

  ## Options

    * `:otp_app` - The OTP application containing SQL files in priv/
    * `:default_prefix` - Default schema prefix (defaults to library name)
    * `:versions` - List of version modules in order [V01, V02, ...]
    * `:tracking_object` - Tuple of `{:view | :table, "object_name"}` for version comments

  ## Version Tracking

  Versions are tracked via PostgreSQL comments on the tracking object:

      COMMENT ON VIEW schema.my_view IS 'MyLibrary version=2';

  This allows PgEvolver to detect the current version and apply only
  the necessary migrations during upgrades.
  """

  @doc false
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @otp_app Keyword.fetch!(opts, :otp_app)
      @default_prefix Keyword.fetch!(opts, :default_prefix)
      @versions Keyword.fetch!(opts, :versions)
      @tracking_object Keyword.fetch!(opts, :tracking_object)

      @current_version length(@versions)
      @initial_version 1

      import Ecto.Migration, only: [execute: 1, repo: 0]

      @doc """
      Returns the current migration version supported by this library.
      """
      @spec current_version() :: pos_integer()
      def current_version, do: @current_version

      @doc """
      Applies migrations up to the target version.

      ## Options

        * `:prefix` - Schema prefix. Defaults to "#{@default_prefix}".
        * `:version` - Target version. Defaults to current version (#{@current_version}).

      """
      @spec up(keyword()) :: :ok
      def up(opts \\ []) do
        opts = Keyword.put_new(opts, :prefix, @default_prefix)
        initial = migrated_version(opts)
        target = Keyword.get(opts, :version, @current_version)

        cond do
          initial == 0 ->
            change(@initial_version..target, :up, opts)

          initial < target ->
            change((initial + 1)..target, :up, opts)

          true ->
            :ok
        end
      end

      @doc """
      Rolls back migrations to the target version.

      ## Options

        * `:prefix` - Schema prefix. Defaults to "#{@default_prefix}".
        * `:version` - Target version to roll back to. Defaults to 0 (complete removal).

      """
      @spec down(keyword()) :: :ok
      def down(opts \\ []) do
        opts = Keyword.put_new(opts, :prefix, @default_prefix)
        current = migrated_version(opts)
        target = Keyword.get(opts, :version, 0)

        if current > target do
          change(current..max(target + 1, @initial_version)//-1, :down, opts)
        else
          :ok
        end
      end

      @doc """
      Returns the currently migrated version from the database.

      Returns 0 if no migrations have been applied or the tracking object doesn't exist.
      """
      @spec migrated_version(keyword()) :: non_neg_integer()
      def migrated_version(opts \\ []) do
        prefix = Keyword.get(opts, :prefix, @default_prefix)
        {object_type, object_name} = @tracking_object

        query = version_query(object_type)

        case repo().query(query, [prefix, object_name]) do
          {:ok, %{rows: [[comment]]}} when is_binary(comment) ->
            parse_version(comment)

          _ ->
            0
        end
      end

      defp version_query(:view) do
        """
        SELECT obj_description(c.oid)
        FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = $1 AND c.relname = $2 AND c.relkind = 'v'
        """
      end

      defp version_query(:table) do
        """
        SELECT obj_description(c.oid)
        FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = $1 AND c.relname = $2 AND c.relkind = 'r'
        """
      end

      defp version_query(:materialized_view) do
        """
        SELECT obj_description(c.oid)
        FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = $1 AND c.relname = $2 AND c.relkind = 'm'
        """
      end

      defp change(range, direction, opts) do
        for version <- range do
          module = Enum.at(@versions, version - 1)
          apply(module, direction, [opts])
        end

        case direction do
          :up ->
            target = Enum.max(range)
            update_version(target, opts)

          :down ->
            target = Enum.min(range) - 1

            if target >= @initial_version do
              update_version(target, opts)
            end
        end

        :ok
      end

      defp parse_version(comment) do
        case Regex.run(~r/version=(\d+)/, comment) do
          [_, version] -> String.to_integer(version)
          _ -> 0
        end
      end

      defp update_version(version, opts) do
        prefix = Keyword.get(opts, :prefix, @default_prefix)
        {object_type, object_name} = @tracking_object

        escaped_prefix = PgEvolver.Helpers.escape_identifier(prefix)
        escaped_name = PgEvolver.Helpers.escape_identifier(object_name)
        module_name = __MODULE__ |> Module.split() |> Enum.take(1) |> Enum.join(".")
        escaped_comment = PgEvolver.Helpers.escape_string("#{module_name} version=#{version}")

        object_keyword =
          case object_type do
            :view -> "VIEW"
            :table -> "TABLE"
            :materialized_view -> "MATERIALIZED VIEW"
          end

        execute("COMMENT ON #{object_keyword} #{escaped_prefix}.#{escaped_name} IS #{escaped_comment}")
      end
    end
  end
end
