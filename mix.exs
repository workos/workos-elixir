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
      homepage_url: "https://workos.com"
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:tesla, "~> 1.4"},
      {:hackney, "~> 1.16.0"},
      {:jason, ">= 1.0.0"}
    ]
  end

  defp description do
    """
    WorkOS SDK for Elixir.
    """
  end

  defp package do
    [
      files: ["lib", "LICENSE*", "mix.exs", "README*"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/workos-inc/workos-elixir",
        "Docs" => "https://workos.com/docs"
      },
      maintainers: ["Conner Fritz"]
    ]
  end
end
