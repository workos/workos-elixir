defmodule WorkOS.SSO do
  alias WorkOS.Api

  @moduledoc """
  The SSO module provides convenience methods for working with the WorkOS
  SSO platform. You'll need a valid API key, a client ID, and to have
  created an SSO connection on your WorkOS dashboard.
  
  @see https://docs.workos.com/sso/overview
  """
  
  @doc """
  Generate an Oauth2 authorization URL where your users will
  authenticate using the configured SSO Identity Provider.

  ### Parameters
  - params (map)
    - domain (string) The domain for the relevant SSO Connection
     configured on your WorkOS dashboard. One of provider or domain is
     required
    - provider (string) A provider name for an Identity Provider
     configured on your WorkOS dashboard. Only 'Google' is supported.
    - redirect_uri (string) The URI where users are directed
     after completing the authentication step. Must match a
     configured redirect URI on your WorkOS dashboard.
    - state (string) An aribtrary state object
     that is preserved and available to the client in the response.

  ### Example
  WorkOS.SSO.get_authorization_url(%{
    domain: "workos.com",
    redirect_uri: "https://workos.com"
  })
  """
  def get_authorization_url(params, opts \\ [])
  def get_authorization_url(params, opts) when is_map_key(params, :domain) or is_map_key(params, :provider) do
    query = Api.process_params(params, [:domain, :provider, :project_id, :redirect_uri, :state], %{
      client_id: WorkOS.client_id(opts),
      response_type: "code"
    })
    |> URI.encode_query()
    {:ok, "#{WorkOS.base_url}/sso/authorize?#{query}"}
  end
  def get_authorization_url(_params, _opts), do: raise ArgumentError, message: "need either domain or provider in params"

  @doc """
  Create a Connection

  ### Parameters
  source (source) The Draft Connection token that's been provided to you by WorkOS.js

  ### Example
  WorkOS.SSO.create_connection('draft_conn_12345')
  """
  def create_connection(source, opts \\ []) do
    Api.post("/connections", %{source: source}, opts)
  end

  @doc """
  Fetch the profile details for the authenticated SSO user.

  ### Parameters
  - code (string) The authorization code provided in the callback URL

  ### Example
  WorkOS.SSO.get_profile("12345")
  """
  def get_profile(code, opts \\ []) do
    Api.post("/sso/token", %{
      code: code,
      client_id: WorkOS.client_id(opts),
      client_secret: WorkOS.api_key(opts),
      grant_type: "authorization_code"
    }, opts)
  end
end
