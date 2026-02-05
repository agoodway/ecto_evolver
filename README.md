# PgEvolver

Versioned PostgreSQL migrations for Elixir libraries using Ecto

PgEvolver provides infrastructure for library authors to ship versioned database schemas that support incremental upgrades. Inspired by how [Oban](https://hexdocs.pm/oban/Oban.Migration.html) handles migrations.

![Walex mascot](pg_evolver.png)

## Philosophy

PgEvolver uses **raw PostgreSQL** instead of Ecto's schema DSL. This enables:

- **Advanced PostgreSQL features** - Functions, triggers, views, materialized views, RLS policies, and complex DDL that Ecto's DSL doesn't support
- **Portability** - SQL files work outside Elixir/Ecto, making migrations usable with any PostgreSQL client
- **Transparency** - Standard `.sql` files are readable and auditable without Elixir knowledge

## Installation

```elixir
def deps do
  [
    {:pg_evolver, "~> 0.1.0"}
  ]
end
```

## Usage

### 1. Define a Migration Module

```elixir
defmodule MyLibrary.Migration do
  use PgEvolver,
    otp_app: :my_library,
    default_prefix: "my_library",
    versions: [MyLibrary.Migrations.V01],
    tracking_object: {:view, "my_main_view"}
end
```

### 2. Define Version Modules

```elixir
defmodule MyLibrary.Migrations.V01 do
  use PgEvolver.Version,
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

CREATE VIEW $SCHEMA$.my_view AS SELECT 1;

--SPLIT--

COMMENT ON VIEW $SCHEMA$.my_view IS 'MyLibrary version=1';
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

### `use PgEvolver`

- `:otp_app` - OTP application containing SQL files in `priv/`
- `:default_prefix` - Default schema name
- `:versions` - List of version modules in order `[V01, V02, ...]`
- `:tracking_object` - `{:view | :table | :materialized_view, "name"}` for version tracking

### `use PgEvolver.Version`

- `:otp_app` - OTP application containing SQL files
- `:version` - Version string like `"01"`, `"02"`
- `:sql_path` - Path within `priv/` to SQL versions directory

## Version Tracking

Versions are tracked via PostgreSQL comments on the tracking object:

```sql
COMMENT ON VIEW schema.my_view IS 'MyLibrary version=1';
```

This allows PgEvolver to detect the current version and apply only necessary migrations during upgrades.

## License

MIT
