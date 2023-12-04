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
    api_key: "sk_123",
    client_id: "project_123",
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

            config :workos, #{inspect(@config_module)}, api_key: "sk_123", client_id: "project_123"
        """

    validate_config!(config)
  end

  @spec validate_config!(WorkOS.config()) :: WorkOS.config() | no_return()
  defp validate_config!(config) do
    Keyword.get(config, :api_key) ||
      raise WorkOS.ApiKeyMissingError

    Keyword.get(config, :client_id) ||
      raise WorkOS.ClientIdMissingError

    config
  end

  @doc """
  Defines the WorkOS base API URL
  """
  def default_base_url, do: "https://api.workos.com"

  @doc """
  Retrieves the WorkOS base URL from application config.
  """
  @spec base_url() :: String.t()
  def base_url do
    case Application.get_env(:workos, @config_module) do
      config when is_list(config) ->
        Keyword.get(config, :base_url, default_base_url())

      _ ->
        default_base_url()
    end
  end

  @doc """
  Retrieves the WorkOS client ID from application config.
  """
  @spec client_id() :: String.t()
  def client_id do
    case Application.get_env(:workos, @config_module) do
      config when is_list(config) ->
        Keyword.get(config, :client_id, nil)

      _ ->
        nil
    end
  end

  @spec client_id(WorkOS.Client.t()) :: String.t()
  def client_id(client) do
    Map.get(client, :client_id)
  end

  @doc """
  Retrieves the WorkOS API key from application config.
  """
  @spec api_key() :: String.t()
  def api_key do
    WorkOS.config()
    |> Keyword.get(:api_key)
  end

  @spec api_key(WorkOS.Client.t()) :: String.t()
  def api_key(client) do
    Map.get(client, :api_key)
  end
end
