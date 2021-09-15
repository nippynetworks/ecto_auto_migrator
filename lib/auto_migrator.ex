defmodule Ecto.AutoMigrator do
  @callback migrate :: :ok
  @callback rollback(atom, any) :: {:ok, any, any}
  @callback load_app :: :ok | {:error, any}
  @callback repos :: list(atom())
  @callback run_migrations? :: boolean

  defmacro __using__(_opts) do
    quote do
      @behaviour Ecto.AutoMigrator

      if Module.get_attribute(__MODULE__, :doc) == nil do
        @doc """
        Automatic migrations module which can be added to the supervision tree
        """
      end

      @app Mix.Project.config()[:app]
      use GenServer

      def start_link(args) do
        GenServer.start_link(__MODULE__, args, [])
      end

      @impl true
      @spec init(any) :: :ignore
      def init(_args) do
        migrate()

        :ignore
      end

      def migrate() do
        if run_migrations?() do
          load_app()

          run_all_migrations(repos)
        end

        :ok
      end

      def run_all_migrations(repos) do
        for repo <- repos do
          {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
        end
      end

      def rollback(repo, version) do
        load_app()
        {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
      end

      def load_app() do
        Application.load(@app)
      end

      def repos() do
        Application.fetch_env!(@app, :ecto_repos)
      end

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
