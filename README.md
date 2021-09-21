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

## Advanced usage

My use case was for a headless system, so I needed to ensure startup could succeed. For this
use case I therefore decided to blow away the DB if migrations failed and try to re-run from scratch
(Obviously choose an appropriate retry strategy for your own situation, eg continue and log an error, etc)

This can be implemented as follows:

```elixir
defmodule Database.Repo.Migrator do
  use Ecto.AutoMigrator
  require Logger

  @doc """
  Entry point

  Run DB migrations and try to ensure they succeed.
  Specifically we will delete all the DBs if migrations fail and try to re-run migrations from scratch
  """
  @impl true
  def migrate() do
    if run_migrations?() do
      load_app()

      try_migrations_1(repos())
    end

    :ok
  end

  # Run migrations, if they fail then blow away the DBs and retry the migrationss from scratch
  defp try_migrations_1(repos) do
    case try_migrations(repos) do
      :error ->
        Logger.critical("migration failure. Purging databases to attempt to continue")

        delete_databases(repos)

        # Retry from scratch and hope we can complete
        try_migrations_2(repos)

      :ok ->
        :ok
    end
  end

  defp try_migrations_2(repos) do
    case try_migrations(repos) do
      :error ->
        Logger.critical("migration retry failure. Continuing, but anticipate that app is unstable")
        :error

      :ok ->
        :ok
    end
  end

  # Delete all database files associated with all 'repos'
  # Currently assumes sqlite DBs
  defp delete_databases(repos) do
    for repo <- repos do
      repo.__adapter__.storage_down(repo.config)
      repo.__adapter__.storage_up(repo.config)
      # Purge all in use connections or we will still be using the old DB files
      repo.stop(5)
    end
  end

  # Try and run migrations, wrapping any exceptions and converting to :error/:ok result
  defp try_migrations(repos) do
    try do
      run_all_migrations(repos)
    rescue
      _ -> :error
    else
      _ -> :ok
    end
  end
end
```
