defmodule WorkOS.MixProject do
  use Mix.Project

  def project do
    [
      name: "WorkOS SDK for Elixir",
      app: :workos,
      version: "0.1.0",
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
      {:hackney, "~> 1.16.0"},
      {:jason, ">= 1.0.0"},
      {:ex_doc, "~> 0.23", only: :dev, runtime: false},
    ]
  end

  defp description do
    """
    WorkOS SDK for Elixir.
    """
  end

  defp docs do
    [
      main: "readme", # The main page in the docs
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
