defmodule WorkOS.SSO do
  import WorkOS.API
  require Logger

  @provider_values ["GoogleOAuth", "MicrosoftOAuth", "authkit"]

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
    configured on your WorkOS dashboard. One of provider, domain,
    connection, or organization is required.
    The domain is deprecated.
    - provider (string) A provider name for an Identity Provider
    configured on your WorkOS dashboard. Only 'GoogleOAuth' and
    'MicrosoftOAuth' are supported.
    - connection (string) Unique identifier for a WorkOS Connection
    - organization (string) Unique identifier for a WorkOS Organization
    - client_id (string) Client ID for a WorkOS Environment. This
    value can be found in the WorkOS dashboard.
    - redirect_uri (string) The URI where users are directed
    after completing the authentication step. Must match a
    configured redirect URI on your WorkOS dashboard.
    - state (string) An aribtrary state object
    that is preserved and available to the client in the response.
    - domain_hint (string) Used to pre-fill domain field when
    authenticating with MicrosoftOAuth
    - login_hint (string) Used to prefill the username/email field
    when authenticating with GoogleOAuth or OpenID Connect

  ### Example
  WorkOS.SSO.get_authorization_url(%{
    connection: "conn_123",
    client_id: "project_01DG5TGK363GRVXP3ZS40WNGEZ",
    redirect_uri: "https://workos.com/callback"
  })
  """
  def get_authorization_url(params, opts \\ [])

  def get_authorization_url(%{provider: provider} = _params, _opts)
      when provider not in @provider_values,
      do:
        raise(ArgumentError,
          message: "#{provider} is not a valid value. `provider` must be in #{@provider_values}"
        )

  def get_authorization_url(params, opts)
      when is_map_key(params, :domain) or is_map_key(params, :provider) or
             is_map_key(params, :connection) or is_map_key(params, :organization) do
    if is_map_key(params, :domain) do
      Logger.warn("[DEPRECATION] `domain` is deprecated. Please use `organization` instead.")
    end

    query =
      process_params(
        params,
        [
          :domain,
          :provider,
          :connection,
          :organization,
          :client_id,
          :redirect_uri,
          :state,
          :domain_hint,
          :login_hint
        ],
        %{
          client_id: WorkOS.client_id(opts),
          response_type: "code"
        }
      )
      |> URI.encode_query()

    {:ok, "#{WorkOS.base_url()}/sso/authorize?#{query}"}
  end

  def get_authorization_url(_params, _opts),
    do:
      raise(ArgumentError,
        message: "Either connection, domain, provider, or organization required in params"
      )

  @doc """
  Fetch the user profile details with an access token.

  ### Parameters
  - access_token (string) An access token that can be exchanged for a user profile

  ### Example
  WorkOS.SSO.get_profile("12345")
  """
  def get_profile(access_token, opts \\ []) do
    opts = opts |> Keyword.put(:access_token, access_token)

    get(
      "/sso/profile",
      %{},
      opts
    )
  end

  @doc """
  Fetch the user profile details and access token for the authenticated SSO user using the code passed to your Redirect URI.

  ### Parameters
  - code (string) The authorization code provided in the callback URL

  ### Example
  WorkOS.SSO.get_profile_and_token("12345")
  """
  def get_profile_and_token(code, opts \\ []) do
    post(
      "/sso/token",
      %{
        code: code,
        client_id: WorkOS.client_id(opts),
        client_secret: WorkOS.api_key(opts),
        grant_type: "authorization_code"
      },
      opts
    )
  end

  @doc """
  List connections

  ### Parameters
  - params (map)
    - connection_type (string - optional) Authentication service provider descriptor
    - domain (string - optional) The domain of the connection to be retrieved
    - organization_id (string - optional) The id of the organization of the connections to be retrieved
    - limit (number - optional) Upper limit on the number of objects to return, between 1 and 100. The default value is 10
    - before (string - optional) An object ID that defines your place in the list
    - after (string - optional) An object ID that defines your place in the list
    - order ("asc" or "desc" - optional) Supported values are "asc" and "desc" for ascending and descending order respectively

  ### Example
  WorkOS.SSO.list_connections()
  """
  def list_connections(params \\ %{}, opts \\ []) do
    query =
      process_params(params, [
        :connection_type,
        :domain,
        :organization_id,
        :limit,
        :before,
        :after,
        :order
      ])

    get("/connections", query, opts)
  end

  @doc """
  Get a connection

  ### Parameters
  - connection (string) The ID of the connection to retrieve

  ### Example
  WorkOS.SSO.get_connection(connection="conn_123")
  """
  def get_connection(connection, opts \\ []) do
    get("/connections/#{connection}", %{}, opts)
  end

  @doc """
  Delete a connection

  ### Parameters
  - connection (string) the ID of the connection to delete

  ### Example
  WorkOS.SSO.delete_connection("conn_12345")
  """
  def delete_connection(connection, opts \\ []) do
    delete("/connections/#{connection}", %{}, opts)
  end
end
