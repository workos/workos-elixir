defmodule WorkOS.Config do
  @moduledoc false

  @default_max_hackney_connections 50
  @default_hackney_timeout 5000

  @spec validate_environment_name!() :: :ok
  def validate_environment_name! do
    # This already raises if missing.
    environment_name()
    :ok
  end

  @spec validate_included_environments!() :: :ok
  def validate_included_environments! do
    normalized_environments =
      case included_environments() do
        list when is_list(list) ->
          Enum.map(list, fn
            env when is_atom(env) or is_binary(env) ->
              to_string(env)

            other ->
              raise ArgumentError, """
              expected environments in :included_environments to be atoms or strings, \
              got: #{inspect(other)}\
              """
          end)

        :all ->
          :all
      end

    :ok = Application.put_env(:workos, :included_environments, normalized_environments)
  end

  def included_environments do
    case Application.fetch_env(:workos, :included_environments) do
      {:ok, :all} ->
        :all

      {:ok, envs} when is_binary(envs) ->
        raise ArgumentError, """
        setting :included_environments to a comma-separated string is not supported anymore. \
        Set :included_environments to a list of atoms instead.\
        """

      {:ok, envs} when is_list(envs) ->
        string_envs = Enum.map(envs, &to_string/1)
        Application.put_env(:workos, :included_environments, string_envs)
        string_envs

      :error ->
        _default = ["prod"]
    end
  end

  def max_hackney_connections do
    Application.get_env(:workos, :hackney_pool_max_connections, @default_max_hackney_connections)
  end

  def hackney_timeout do
    Application.get_env(:workos, :hackney_pool_timeout, @default_hackney_timeout)
  end

  def client do
    Application.get_env(:workos, :client, WorkOS.HackneyClient)
  end

  def hackney_opts do
    Application.get_env(:workos, :hackney_opts, [])
  end

  def json_library do
    Application.get_env(:workos, :json_library, Jason)
  end

  defp get_config_from_app_or_system_env(app_key, system_env_key) do
    case Application.get_env(:workos, app_key, nil) do
      {:system, env_key} ->
        raise ArgumentError, """
        using {:system, env} as a configuration value is not supported since v9.0.0 of this \
        library. Move the configuration for #{inspect(app_key)} to config/runtime.exs, \
        and read the #{inspect(env_key)} environment variable from there:

          config :workos,
            # ...,
            #{app_key}: System.fetch_env!(#{inspect(env_key)})

        """

      nil ->
        if value = System.get_env(system_env_key) do
          Application.put_env(:workos, app_key, value)
          value
        else
          nil
        end

      value ->
        value
    end
  end
end
