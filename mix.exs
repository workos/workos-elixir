defmodule WorkOS.MixProject do
  use Mix.Project

  @version "1.0.0"
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
      source_ref: "#{@version}",
      dialyzer: [
        flags: [:unmatched_returns, :error_handling, :extra_return],
        plt_file: {:no_warn, "plts/dialyzer.plt"},
        plt_core_path: "plts",
        plt_add_deps: :app_tree,
        plt_add_apps: [:mix, :ex_unit]
      ]
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
  defp elixirc_paths(:test), do: ["test/support"] ++ elixirc_paths(:dev)
  defp elixirc_paths(_other), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:tesla, "~> 1.4"},
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
        WorkOS.AuditLogs,
        WorkOS.DirectorySync,
        WorkOS.Events,
        WorkOS.OrganizationDomains,
        WorkOS.Organizations,
        WorkOS.Passwordless,
        WorkOS.Portal,
        WorkOS.SSO,
        WorkOS.UserManagement,
        WorkOS.Webhooks
      ],
      "Response Structs": [
        WorkOS.AuditLogs.Export,
        WorkOS.DirectorySync.Directory,
        WorkOS.DirectorySync.Directory.Group,
        WorkOS.DirectorySync.Directory.User,
        WorkOS.Events.Event,
        WorkOS.Organizations.Organization,
        WorkOS.Organizations.Organization.Domain,
        WorkOS.OrganizationDomains.OrganizationDomain,
        WorkOS.Passwordless.Session,
        WorkOS.Passwordless.Session.Send,
        WorkOS.Portal.Link,
        WorkOS.SSO.Connection,
        WorkOS.SSO.Connection.Domain,
        WorkOS.SSO.Profile,
        WorkOS.SSO.ProfileAndToken,
        WorkOS.UserManagement.Authentication,
        WorkOS.UserManagement.EmailVerification.SendVerificationEmail,
        WorkOS.UserManagement.EmailVerification.VerifyEmail,
        WorkOS.UserManagement.EnrollAuthFactor,
        WorkOS.UserManagement.Invitation,
        WorkOS.UserManagement.MagicAuth.SendMagicAuthCode,
        WorkOS.UserManagement.MultiFactor.AuthenticationChallenge,
        WorkOS.UserManagement.MultiFactor.AuthenticationFactor,
        WorkOS.UserManagement.MultiFactor.EnrollAuthFactor,
        WorkOS.UserManagement.MultiFactor.SMS,
        WorkOS.UserManagement.MultiFactor.TOTP,
        WorkOS.UserManagement.OrganizationMembership,
        WorkOS.UserManagement.ResetPassword,
        WorkOS.Webhooks.Event,
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
