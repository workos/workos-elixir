defmodule WorkOS.MixProject do
  use Mix.Project

  def project do
    [
      name: "WorkOS SDK for Elixir",
      app: :workos,
      version: "0.1.3",
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      deps: deps(),
      source_url: "https://github.com/workos-inc/workos-elixir/",
      homepage_url: "https://workos.com",
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      env: env()
    ]
  end

  defp deps do
    [
      {:tesla, "~> 1.4"},
      {:hackney, "~> 1.18.0"},
      {:jason, ">= 1.0.0"},
      {:ex_doc, "~> 0.23", only: :dev, runtime: false},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false}
    ]
  end

  defp description do
    """
    WorkOS SDK for Elixir.
    """
  end

  defp docs do
    [
      # The main page in the docs
      main: "readme",
      extras: ["README.md"]
    ]
  end

  defp env do
    [
      host: "api.workos.com"
    ]
  end

  defp package do
    [
      files: ["lib", "LICENSE*", "mix.exs", "README*"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/workos-inc/workos-elixir",
        "Online documentation" => "https://workos.com/docs",
        "Homepage" => "https://workos.com"
      },
      maintainers: ["Conner Fritz"]
    ]
  end
end
