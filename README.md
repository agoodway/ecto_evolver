# EctoEvolver

[![Hex.pm](https://img.shields.io/hexpm/v/ecto_evolver.svg)](https://hex.pm/packages/ecto_evolver)
[![Hex Docs](https://img.shields.io/badge/hex-docs-blue.svg)](https://hexdocs.pm/ecto_evolver)
[![License](https://img.shields.io/hexpm/l/ecto_evolver.svg)](https://github.com/agoodway/ecto_evolver/blob/main/LICENSE)

Versioned database migrations for Elixir libraries using Ecto.

EctoEvolver provides infrastructure for library authors to ship versioned database schemas that support incremental upgrades. Inspired by how [Oban](https://hexdocs.pm/oban/Oban.Migration.html) handles migrations.

![EctoEvolver Lab](ecto_evolver.png)

## Philosophy

EctoEvolver uses **raw SQL** instead of Ecto's schema DSL. This enables:

- **Advanced database features** - Functions, triggers, views, materialized views, RLS policies, and complex DDL that Ecto's DSL doesn't support
- **Portability** - SQL files work outside Elixir/Ecto, making migrations usable with any database client
- **Transparency** - Standard `.sql` files are readable and auditable without Elixir knowledge

## Adapters

EctoEvolver uses an adapter system for database-specific operations. The adapter is auto-detected from your Ecto repo's configuration at runtime.

**Currently supported:**
- `EctoEvolver.Adapters.Postgres` — PostgreSQL (auto-detected, default)

> **Future adapters**: The adapter architecture is designed to support other databases that Ecto supports (SQLite, MySQL, etc.). Contributions welcome.

## Installation

```elixir
def deps do
  [
    {:ecto_evolver, "~> 0.1.0"}
  ]
end
```

## Usage

### 1. Define a Migration Module

```elixir
defmodule MyLibrary.Migration do
  use EctoEvolver,
    otp_app: :my_library,
    default_prefix: "my_library",
    versions: [MyLibrary.Migrations.V01],
    tracking_object: {:table, "my_main_table"}
end
```

### 2. Define Version Modules

```elixir
defmodule MyLibrary.Migrations.V01 do
  use EctoEvolver.Version,
    otp_app: :my_library,
    version: "01",
    sql_path: "my_library/sql/versions"
end
```

### 3. Create SQL Files

Place SQL files in your `priv/` directory:

```
priv/my_library/sql/versions/
└── v01/
    ├── v01_up.sql
    └── v01_down.sql
```

Use `$SCHEMA$` as a placeholder for the schema name and `--SPLIT--` to separate statements:

```sql
CREATE SCHEMA IF NOT EXISTS $SCHEMA$;

--SPLIT--

CREATE TABLE $SCHEMA$.my_table (
  id BIGSERIAL PRIMARY KEY,
  name TEXT NOT NULL
);
```

### 4. Users Generate an Ecto Migration

```elixir
defmodule MyApp.Repo.Migrations.AddMyLibrary do
  use Ecto.Migration

  def up, do: MyLibrary.Migration.up()
  def down, do: MyLibrary.Migration.down()
end
```

## Options

### `use EctoEvolver`

- `:otp_app` - OTP application containing SQL files in `priv/`
- `:default_prefix` - Default schema name
- `:versions` - List of version modules in order `[V01, V02, ...]`
- `:tracking_object` - `{:view | :table | :materialized_view, "name"}` for version tracking
- `:adapter` - Adapter module (optional, auto-detected from repo)

### `use EctoEvolver.Version`

- `:otp_app` - OTP application containing SQL files
- `:version` - Version string like `"01"`, `"02"`
- `:sql_path` - Path within `priv/` to SQL versions directory

## Version Tracking

Version tracking is adapter-specific. The PostgreSQL adapter uses object comments:

```sql
COMMENT ON TABLE schema.my_table IS 'MyLibrary version=1';
```

This allows EctoEvolver to detect the current version and apply only necessary migrations during upgrades.

## License

MIT
