defmodule WorkOS do
  @moduledoc """
  Documentation for `WorkOS`.
  """

  @config_module WorkOS.Client

  def host, do: Application.get_env(:workos, :host)
  def base_url, do: "https://" <> Application.get_env(:workos, :host)
  def adapter, do: Application.get_env(:workos, :adapter) || Tesla.Adapter.Hackney

  def api_key(opts \\ [])
  def api_key(api_key: api_key), do: api_key
  def api_key(_opts), do: Application.get_env(:workos, :api_key)

  def client_id(opts \\ [])
  def client_id(client_id: client_id), do: client_id
  def client_id(_opts), do: Application.get_env(:workos, :client_id)
end
