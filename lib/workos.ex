defmodule WorkOS do
  @moduledoc """
  Documentation for `WorkOS`.
  """

  @config_module WorkOS.Client

  @type config() ::
          list(
            {:api_key, String.t()}
            | {:client_id, String.t()}
            | {:base_url, String.t()}
            | {:client, atom()}
          )

  @doc """
  Returns a WorkOS client.

  Accepts a keyword list of config opts, though if omitted then it will attempt to load
  them from the application environment.
  """
  @spec client() :: WorkOS.Client.t()
  @spec client(config()) :: WorkOS.Client.t()
  def client(config \\ config()) do
    WorkOS.Client.new(config)
  end

  @doc """
  Loads config values from the application environment.

  Config options are as follows:

  ```ex
  config :workos, WorkOS.Client
    api_key: "test_123",
    base_url: "https://api.workos.com",
    client: WorkOs.Client.TeslaClient
  ```

  The only required config option is `:api_key` and `:client_id`. If you would like to replace the
  HTTP client used by WorkOS, configure the `:client` option. By default, this library
  uses [Tesla](https://github.com/elixir-tesla/tesla), but changing it is as easy as
  defining your own client module. See the `WorkOS.Client` module docs for more info.
  """
  @spec config() :: config()
  def config do
    config =
      Application.get_env(:workos, @config_module) ||
        raise """
        Missing client configuration for WorkOS.

        Configure your WorkOS API key in one of your config files, for example:

            config :workos, #{inspect(@config_module)}, api_key: "example_123", client_id: "example_123"
        """

    validate_config!(config)
  end

  @spec validate_config!(WorkOS.config()) :: WorkOS.config() | no_return()
  defp validate_config!(config) do
    api_key =
      Keyword.get(config, :api_key) ||
        raise "Missing required config key for #{@config_module}: :api_key"

    String.starts_with?(api_key, "sk_") ||
      raise "WorkOS API key should start with 'sk_', please check your configuration"

    client_id =
      Keyword.get(config, :client_id) ||
        raise "Missing required config key for #{@config_module}: :client_id"

    String.starts_with?(client_id, "project_") ||
      raise "WorkOS Client ID should start with 'project_', please check your configuration"

    config
  end

  def default_base_url, do: "https://api.workos.com"

  @spec base_url() :: String.t()
  def base_url do
    WorkOS.config()
    |> Keyword.get(:base_url, default_base_url())
  end
end
