defmodule EctoEvolverTest do
  use ExUnit.Case

  alias EctoEvolver.Adapters.Adapter
  alias EctoEvolver.Adapters.Postgres
  alias EctoEvolver.Helpers

  doctest EctoEvolver.Helpers

  describe "Adapter.resolve/1" do
    test "maps Ecto.Adapters.Postgres to the Postgres adapter" do
      assert {:ok, Postgres} == Adapter.resolve(Ecto.Adapters.Postgres)
    end

    test "returns error for unsupported adapters" do
      assert {:error, :unsupported_adapter} == Adapter.resolve(Ecto.Adapters.SQLite3)
      assert {:error, :unsupported_adapter} == Adapter.resolve(Ecto.Adapters.MyXQL)
      assert {:error, :unsupported_adapter} == Adapter.resolve(SomeOtherModule)
    end
  end

  describe "Postgres.escape_identifier/1" do
    test "passes through safe identifiers unchanged" do
      assert "my_schema" == Postgres.escape_identifier("my_schema")
      assert "tango_providers" == Postgres.escape_identifier("tango_providers")
    end

    test "quotes identifiers with uppercase or spaces" do
      assert ~S("My Schema") == Postgres.escape_identifier("My Schema")
      assert ~S("CamelCase") == Postgres.escape_identifier("CamelCase")
    end

    test "quotes PostgreSQL reserved words" do
      assert ~S("select") == Postgres.escape_identifier("select")
      assert ~S("table") == Postgres.escape_identifier("table")
      assert ~S("user") == Postgres.escape_identifier("user")
    end

    test "quotes identifiers starting with digits" do
      assert ~S("123abc") == Postgres.escape_identifier("123abc")
    end

    test "escapes double quotes within identifiers" do
      assert ~S("has""quote") == Postgres.escape_identifier(~S(has"quote))
    end
  end

  describe "Helpers.escape_string/1" do
    test "wraps values in single quotes" do
      assert "'hello'" == Helpers.escape_string("hello")
    end

    test "escapes internal single quotes" do
      assert "'it''s'" == Helpers.escape_string("it's")
    end

    test "handles empty strings" do
      assert "''" == Helpers.escape_string("")
    end
  end

  describe "Postgres.escape_string/1" do
    test "delegates to Helpers.escape_string/1" do
      assert Postgres.escape_string("test") == Helpers.escape_string("test")
      assert Postgres.escape_string("it's") == Helpers.escape_string("it's")
    end
  end

  describe "SqlRunner.build_file_path/4" do
    test "constructs correct path for up migration" do
      path = EctoEvolver.SqlRunner.build_file_path(:ecto_evolver, "sql/versions", "01", :up)
      assert String.ends_with?(path, "sql/versions/v01/v01_up.sql")
    end

    test "constructs correct path for down migration" do
      path = EctoEvolver.SqlRunner.build_file_path(:ecto_evolver, "sql/versions", "02", :down)
      assert String.ends_with?(path, "sql/versions/v02/v02_down.sql")
    end
  end
end
