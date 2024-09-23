defmodule Ecto.AutoMigrator do
  @callback create!(any) :: :ok
  @callback create_repo(atom(), any) :: :ok | {:error, any}
  @callback migrate!(any) :: :ok
  @callback migrate_repo(atom(), any) :: :ok | {:error, any}
  @callback recreate_repo(atom(), any) :: :ok | {:error, any}
  @callback rollback(atom, any) :: {:ok, any, any} | {:error, any}
  @callback load_app :: :ok | {:error, any}
  @callback repos(any) :: list(atom())
  @callback run_migrations? :: boolean

  defmacro __using__(_opts) do
    quote do
      @behaviour Ecto.AutoMigrator

      if Module.get_attribute(__MODULE__, :doc) == nil do
        @doc """
        Automatic migrations module which can be added to the supervision tree
        """
      end

      use GenServer
      require Logger

      @app Mix.Project.config()[:app]

      def start_link(args) do
        GenServer.start_link(__MODULE__, args, [])
      end

      @impl true
      @spec init(any) :: :ignore
      def init(args) do
        Logger.info("Starting #{inspect(__MODULE__)}")

        if run_migrations?() do
          create!(args)
          migrate!(args)
        end

        :ignore
      end

      @doc """
      Equiv of mix ecto.create
      """
      def create!(args) do
        Logger.info("Ensuring repos are created")
        load_app()

        Enum.each(repos(args), fn repo ->
          # Attempt to ensure that the DBs are created before progressing
          create_repo(repo, args)
        end)

        :ok
      end

      @doc """
      Do the creation/init of a single repo
      """
      def create_repo(repo, args \\ nil)

      def create_repo(repo, _args) do
        Logger.info("About to create: #{inspect(repo)}")

        try do
          repo.adapter().storage_up(repo.config)
        rescue
          e ->
            Logger.error("Error creating Repo: #{inspect(repo)} got #{inspect(e)}")
            {:error, e}
        else
          _ -> :ok
        end
      end

      @doc """
      Delete and then recreate repo
      """
      def recreate_repo(repo, args) do
        try do
          repo.adapter().storage_down(repo.config)
          repo.adapter().storage_up(repo.config)
        rescue
          e ->
            Logger.error("Error deleting and recreating Repo: #{inspect(repo)} got #{inspect(e)}")
            {:error, e}
        else
          _ ->
            # Purge all in use connections or we will still be using the old DB files
            repo.stop(5)
        end
      end

      @doc """
      Equiv of mix ecto.migrate
      """
      def migrate!(args) do
        Logger.info("Ensuring repos are migrated")
        load_app()

        for repo <- repos(args) do
          :ok = migrate_repo(repo, args)
        end

        :ok
      end

      @doc """
      Do the migration of a single repo
      """
      def migrate_repo(repo, args \\ nil)

      def migrate_repo(repo, _args) do
        Logger.info("Running migrations for: #{inspect(repo)}")

        try do
          Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
        rescue
          e ->
            Logger.error("Error migrating Repo: #{inspect(repo)} got #{inspect(e)}")
            {:error, e}
        else
          {:ok, _, _} -> :ok
          {:error, term} -> {:error, term}
        end
      end

      def rollback(repo, version) do
        load_app()
        {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
      end

      @doc """
      Load all modules, etc needed for our migration to be able to complete successfully
      """
      def load_app() do
        Application.load(@app)
      end

      @doc """
      The list of modules we will operate against

      Defaults to the same as mix ecto.migrate, ie list of repos from:
        Application.fetch_env!(:my_app, :ecto_repos)
      """
      def repos(repos \\ nil)
      def repos(%{repos: repos}), do: repos

      def repos(_args) do
        Application.fetch_env!(@app, :ecto_repos)
      end

      @doc """
      Whether to run migrations or not

      Defaults to Application.fetch_env(:my_app, :run_migrations), set this in you config, eg:
        config :my_app, run_migrations: System.get_env("RUN_MIGRATIONS") || Mix.env == :test
      """
      def run_migrations?() do
        case Application.fetch_env(@app, :run_migrations) do
          {:ok, val} -> !!val
          :error -> false
        end
      end

      defoverridable Ecto.AutoMigrator
    end
  end
end
