defmodule WorkOS.MixProject do
  use Mix.Project

  @version "0.3.0"
  @source_url "https://github.com/workos/workos-elixir"

  def project do
    [
      app: :workos,
      version: @version,
      name: "WorkOS SDK for Elixir",
      elixir: "~> 1.11",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      docs: docs(),
      deps: deps(),
      source_ref: "#{@version}"
    ]
  end

  defp description do
    """
    Official Elixir SDK for interacting with the WorkOS API.
    """
  end

  defp package() do
    [
      description: description(),
      licenses: ["MIT"],
      maintainers: [
        "Mark Tran",
        "Laura Beatris",
        "Blair Lunceford",
        "Jacobia Johnson"
      ],
      links: %{
        "GitHub" => @source_url,
        "WorkOS" => "https://workos.com",
        "Elixir Example" => "https://github.com/workos/elixir-example-applications"
      }
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:tesla, "~> 1.4"},
      {:hackney, "~> 1.18.0"},
      {:jason, ">= 1.0.0"},
      {:plug_crypto, "~> 1.0"},
      {:ex_doc, "~> 0.23", only: :dev, runtime: false},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.2", only: :dev, runtime: false}
    ]
  end

  defp docs() do
    [
      extras: [
        "README.md": [title: "Overview"]
      ],
      main: "readme",
      source_url: @source_url,
      source_ref: "v#{@version}",
      groups_for_modules: groups_for_modules()
    ]
  end

  defp groups_for_modules() do
    [
      "Core API": [
        WorkOS.SSO,
        WorkOS.Organizations,
        WorkOS.Portal,
        WorkOS.Webhooks,
        WorkOS.DirectorySync,
        WorkOS.Passwordless,
        WorkOS.Events,
      ],
      "Response Structs": [
        WorkOS.SSO.Connection,
        WorkOS.SSO.Connection.Domain,
        WorkOS.SSO.Profile,
        WorkOS.SSO.ProfileAndToken,
        WorkOS.Organizations.Organization,
        WorkOS.Organizations.Organization.Domain,
        WorkOS.Portal.Link,
        WorkOS.Webhooks.Event,
        WorkOS.DirectorySync.Directory,
        WorkOS.DirectorySync.Directory.Group,
        WorkOS.DirectorySync.Directory.User,
        WorkOS.Passwordless.Session,
        WorkOS.Passwordless.Session.Send,
        WorkOS.Events.Event,
        WorkOS.Empty,
        WorkOS.Error,
        WorkOS.List
      ],
      "API Client": [
        WorkOS.Client,
        WorkOS.Client.TeslaClient
      ]
    ]
  end
end
