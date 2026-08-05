defmodule WorkOS.MixProject do
  use Mix.Project

  @version "3.0.1"
  @source_url "https://github.com/workos/workos-elixir"

  def project do
    [
      app: :workos,
      version: @version,
      name: "WorkOS SDK for Elixir",
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      docs: docs(),
      deps: deps(),
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

  defp package do
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

  def application do
    [extra_applications: [:logger, :crypto]]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:req, "~> 0.5"},
      {:plug, "~> 1.16", only: :test},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end

  defp docs do
    [
      extras: [
        "README.md": [title: "Overview"]
      ],
      main: "readme",
      source_url: @source_url,
      source_ref: "v#{@version}"
    ]
  end
end
