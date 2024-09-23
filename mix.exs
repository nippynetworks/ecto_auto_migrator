defmodule EctoAutoMigrator.MixProject do
  use Mix.Project

  @version "1.2.0"
  @source_url "https://github.com/nippynetworks/ecto_auto_migrator"

  def project do
    [
      app: :ecto_auto_migrator,
      description: "Automatic migrations for Ecto as part of the application boot process",
      version: @version,
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ecto, "~>3.0", optional: true},
      {:ex_doc, "~> 0.24", only: :dev, runtime: false}
    ]
  end

  defp package() do
    [
      maintainers: ["Ed Wildgoose"],
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => @source_url}
    ]
  end
end
