defmodule WorkOS.WorkloadIdentity.AWS.MixProject do
  use Mix.Project

  @version "0.0.0"
  @source_url "https://github.com/workos/workos-elixir"

  def project do
    [
      app: :workos_workload_identity_aws,
      version: @version,
      name: "WorkOS workload identity for AWS",
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      docs: docs(),
      deps: deps()
    ]
  end

  # STS is called through `aws`, over `:httpc`, so no HTTP client dependency
  # is needed beyond OTP.
  def application do
    [extra_applications: [:inets, :ssl, :public_key]]
  end

  defp description do
    """
    AWS identity token provider for WorkOS workload identity federation.
    """
  end

  defp package do
    [
      description: description(),
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "WorkOS" => "https://workos.com"
      }
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # 1.0.11 is the first release with `AWS.STS.get_web_identity_token/3`.
      {:aws, "~> 1.0 and >= 1.0.11"},
      # The credential chain: environment, shared files, ECS, EKS and EC2.
      {:aws_credentials, "~> 1.1"},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end

  defp docs do
    [
      extras: [
        "README.md": [title: "Overview"]
      ],
      main: "readme",
      source_url: @source_url,
      source_ref: "workos_workload_identity_aws-v#{@version}"
    ]
  end
end
