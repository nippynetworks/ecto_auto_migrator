# EctoAutoMigrator

Ecto documentation proposes a way to run migrations outside of using mix here:

- https://hexdocs.pm/phoenix/releases.html#ecto-migrations-and-custom-commands

However, in a number of cases, eg whole system apps such as Nerves and the like,
we actually want to run the migrations at app startup.

The solution to this is to create a genserver compatible module, which itself
runs the migrations and we can then insert this into our children (just after
we start the Repo perhaps) in application.ex (or wherever we start the repo)

However, we likely still want control over when we run the migrations, eg
while developing some new migrations you don't want every invocation of mix
running your migrations, nor watchers helpers, or editor plugins continuously
causing the migrations to fire. So we conditionally run the migrations based on
a config entry "run_migrations", which itself would be recommended to be set
based on an environment variable

eg:
```elixir
  config :my_app, run_migrations: System.get_env("RUN_MIGRATIONS")
```

To implement our module it should generally be sufficient to create a new Migrator
module. Optionally any of the callback functions can be overridden, eg the original
use case for this module was where the migrations absolutely must not fail. To achieve
this a custom "migrate()" function could be used which performs some sensible recovery
action on migration failure, eg destroying the database and migrating from scratch,
or restoring a backup, or ignoring the migration and raising an error, etc.

eg it's often sufficient to do

```elixir
defmodule MyApp.Repo.Migrator
  use Ecto.AutoMigrator
end
```

and then in application.ex add "MyApp.Repo.Migrator" to your list of children,
somewhere after the Repo is started

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `ecto_auto_migrator` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ecto_auto_migrator, "~> 0.1"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/ecto_auto_migrator](https://hexdocs.pm/ecto_auto_migrator).
