defmodule EctoEvolver do
  @moduledoc """
  Versioned database migrations for Elixir libraries.

  EctoEvolver provides infrastructure for library authors to ship versioned database
  schemas that can be incrementally upgraded. It tracks migration versions via
  database-specific adapters and supports both forward migrations and rollbacks.

  ## Usage

  Define a migration module in your library:

      defmodule MyLibrary.Migration do
        use EctoEvolver,
          otp_app: :my_library,
          default_prefix: "my_library",
          versions: [MyLibrary.Migrations.V01, MyLibrary.Migrations.V02],
          tracking_object: {:table, "my_main_table"}
      end

  Then users generate an Ecto migration that calls your module:

      defmodule MyApp.Repo.Migrations.AddMyLibrary do
        use Ecto.Migration

        def up, do: MyLibrary.Migration.up()
        def down, do: MyLibrary.Migration.down()
      end

  ## Options

    * `:otp_app` - The OTP application containing SQL files in priv/
    * `:default_prefix` - Default schema prefix
    * `:versions` - List of version modules in order `[V01, V02, ...]`
    * `:tracking_object` - `{:view | :table | :materialized_view, "object_name"}`
    * `:adapter` - Adapter module (optional, auto-detected from repo)

  ## Adapters

  EctoEvolver uses adapters for database-specific operations. The adapter is
  auto-detected from your Ecto repo at runtime.

  Currently supported:

    * `EctoEvolver.Adapters.Postgres` - PostgreSQL (default)
  """

  @doc false
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @otp_app Keyword.fetch!(opts, :otp_app)
      @default_prefix Keyword.fetch!(opts, :default_prefix)
      @versions Keyword.fetch!(opts, :versions)
      @tracking_object Keyword.fetch!(opts, :tracking_object)
      @explicit_adapter Keyword.get(opts, :adapter)

      @current_version length(@versions)
      @initial_version 1

      import Ecto.Migration, only: [execute: 1, repo: 0]

      @doc "Returns the current migration version supported by this library."
      @spec current_version() :: pos_integer()
      def current_version, do: @current_version

      @doc """
      Applies migrations up to the target version.

      ## Options

        * `:prefix` - Schema prefix. Defaults to `"#{@default_prefix}"`.
        * `:version` - Target version. Defaults to `#{@current_version}`.
      """
      @spec up(keyword()) :: :ok
      def up(opts \\ []) do
        opts = Keyword.put_new(opts, :prefix, @default_prefix)
        adapter = resolve_adapter!()
        initial = migrated_version(opts)
        target = Keyword.get(opts, :version, @current_version)

        cond do
          initial == 0 ->
            run_versions(@initial_version..target, :up, opts, adapter)

          initial < target ->
            run_versions((initial + 1)..target, :up, opts, adapter)

          true ->
            :ok
        end
      end

      @doc """
      Rolls back migrations to the target version.

      ## Options

        * `:prefix` - Schema prefix. Defaults to `"#{@default_prefix}"`.
        * `:version` - Target version to roll back to. Defaults to `0`.
      """
      @spec down(keyword()) :: :ok
      def down(opts \\ []) do
        opts = Keyword.put_new(opts, :prefix, @default_prefix)
        adapter = resolve_adapter!()
        current = migrated_version(opts)
        target = Keyword.get(opts, :version, 0)

        if current > target do
          run_versions(current..max(target + 1, @initial_version)//-1, :down, opts, adapter)
        else
          :ok
        end
      end

      @doc """
      Returns the currently migrated version from the database.

      Returns `0` if no migrations have been applied.
      """
      @spec migrated_version(keyword()) :: non_neg_integer()
      def migrated_version(opts \\ []) do
        prefix = Keyword.get(opts, :prefix, @default_prefix)
        adapter = resolve_adapter!()
        # Kernel.apply/3 prevents the compiler from following the call chain
        # through repo() at compile time (repo/0 returns nil outside migrations)
        Kernel.apply(adapter, :get_version, [repo(), prefix, @tracking_object])
      end

      defp run_versions(range, direction, opts, adapter) do
        for version <- range do
          module = Enum.at(@versions, version - 1)

          case direction do
            :up -> module.up(opts)
            :down -> module.down(opts)
          end
        end

        case direction do
          :up ->
            update_version(Enum.max(range), opts, adapter)

          :down ->
            target = Enum.min(range) - 1

            if target >= @initial_version do
              update_version(target, opts, adapter)
            end
        end

        :ok
      end

      defp update_version(version, opts, adapter) do
        prefix = Keyword.get(opts, :prefix, @default_prefix)
        label = __MODULE__ |> Module.split() |> Enum.take(1) |> Enum.join(".")
        adapter.set_version(prefix, @tracking_object, version, label)
      end

      defp resolve_adapter! do
        if @explicit_adapter do
          @explicit_adapter
        else
          ecto_adapter = repo().__adapter__()

          # credo:disable-for-next-line Credo.Check.Design.AliasUsage
          case EctoEvolver.Adapters.Adapter.resolve(ecto_adapter) do
            {:ok, adapter} ->
              adapter

            {:error, :unsupported_adapter} ->
              raise """
              EctoEvolver could not auto-detect an adapter for #{inspect(ecto_adapter)}.

              Supported Ecto adapters:
                * Ecto.Adapters.Postgres → EctoEvolver.Adapters.Postgres

              You can specify an adapter explicitly:

                  use EctoEvolver,
                    adapter: MyCustomAdapter,
                    ...
              """
          end
        end
      end
    end
  end
end
