defmodule WorkOS.SSO do
  @moduledoc """
  Manage Single Sign-On (SSO) in WorkOS.

  @see https://docs.workos.com/sso/overview
  """

  require Logger

  alias WorkOS.SSO.Profile
  alias WorkOS.SSO.Connection
  alias WorkOS.SSO.ProfileAndToken

  @doc """
  Lists all connections.

  Parameter options:

    * `:connection_type` - Filter Connections by their type.
    * `:organization_id` - Filter Connections by their associated organization.
    * `:domain` - Filter Connections by their associated domain.
    * `:limit` - Maximum number of records to return. Accepts values between 1 and 100. Default is 10.
    * `:after` - Pagination cursor to receive records after a provided event ID.
    * `:before` - An object ID that defines your place in the list. When the ID is not present, you are at the end of the list.
    * `:order` - Order the results by the creation time. Supported values are "asc" and "desc" for showing older and newer records first respectively.

  """
  @spec list_connections(map()) :: WorkOS.Client.response(WorkOS.List.t(Connection.t()))
  @spec list_connections(WorkOS.Client.t(), map()) ::
          WorkOS.Client.response(WorkOS.List.t(Connection.t()))
  def list_connections(client \\ WorkOS.client(), opts) do
    WorkOS.Client.get(client, WorkOS.List.of(Connection), "/connections",
      opts: [
        query: %{
          connection_type: opts[:connection_type],
          organization_id: opts[:organization_id],
          domain: opts[:domain],
          limit: opts[:limit],
          after: opts[:after],
          before: opts[:before],
          order: opts[:order]
        }
      ]
    )
  end

  @spec list_connections() :: WorkOS.Client.response(WorkOS.List.t(Connection.t()))
  def list_connections() do
    list_connections(WorkOS.client(), %{})
  end

  @doc """
  Deletes a connection.
  """
  @spec delete_connection(String.t()) :: WorkOS.Client.response(nil)
  @spec delete_connection(WorkOS.Client.t(), String.t()) :: WorkOS.Client.response(nil)
  def delete_connection(client \\ WorkOS.client(), connection_id) do
    WorkOS.Client.delete(client, Connection, "/connections/:id", %{},
      opts: [
        path_params: [id: connection_id]
      ]
    )
  end

  @doc """
  Gets a connection given an ID.
  """
  @spec get_connection(String.t()) :: WorkOS.Client.response(Connection.t())
  @spec get_connection(WorkOS.Client.t(), String.t()) :: WorkOS.Client.response(Connection.t())
  def get_connection(client \\ WorkOS.client(), connection_id) do
    WorkOS.Client.get(client, Connection, "/connections/:id",
      opts: [
        path_params: [id: connection_id]
      ]
    )
  end

  @doc """
  Generates an OAuth 2.0 authorization URL.

  Parameter options:

    * `:organization` - The organization connection selector is used to initiate SSO for an Organization.
    * `:connection` - The connection connection selector is used to initiate SSO for a Connection.
    * `:redirect_uri` - A Redirect URI to return an authorized user to. (required)
    * `:client_id` - This value can be obtained from the SSO Configuration page in the WorkOS dashboard.
    * `:provider` - The provider connection selector is used to initiate SSO using an OAuth provider.
    * `:state` - An optional parameter that can be used to encode arbitrary information to help restore application state between redirects.
    * `:login_hint` - Can be used to pre-fill the username/email address field of the IdP sign-in page for the user, if you know their username ahead of time.
    * `:domain_hint` - Can be used to pre-fill the domain field when initiating authentication with Microsoft OAuth, or with a GoogleSAML connection type.

  """
  @spec get_authorization_url(map()) :: {:ok, String.t()} | {:error, String.t()}
  def get_authorization_url(params)
      when is_map_key(params, :connection) or is_map_key(params, :organization) or
             is_map_key(params, :provider) or is_map_key(params, :domain) do
    if is_map_key(params, :domain) do
      Logger.warn(
        "The `domain` parameter for `get_authorization_url` is deprecated. Please use `organization` instead."
      )
    end

    defaults = %{
      client_id: WorkOS.config() |> Keyword.get(:client_id, params[:client_id]),
      response_type: "code"
    }

    query =
      defaults
      |> Map.merge(params)
      |> Map.take(
        [
          :client_id,
          :redirect_uri,
          :connection,
          :organization,
          :provider,
          :state,
          :login_hint,
          :domain_hint,
          :domain
        ] ++ Map.keys(defaults)
      )
      |> URI.encode_query()

    {:ok, "#{WorkOS.base_url()}/sso/authorize?#{query}"}
  end

  def get_authorization_url(_params),
    do:
      {:error,
       "Incomplete arguments. Need to specify either a 'connection', 'organization', 'domain', or 'provider'."}

  @doc """
  Gets an access token along with the user `Profile`.

  Parameter options:

    * `:code` - The authorization value which was passed back as a query parameter in the callback to the Redirect URI. (required)

  """
  @spec get_profile_and_token(map()) :: WorkOS.Client.response(ProfileAndToken.t())
  @spec get_profile_and_token(WorkOS.Client.t(), map()) ::
          WorkOS.Client.response(ProfileAndToken.t())
  def get_profile_and_token(client \\ WorkOS.client(), opts) do
    WorkOS.Client.post(client, ProfileAndToken, "/sso/token", %{
      client_id: WorkOS.client_id(),
      client_secret: WorkOS.client_secret(),
      grant_type: "authorization_code",
      code: opts[:code]
    })
  end

  @doc """
  Gets a profile given an access token.
  """
  @spec get_profile(String.t()) :: WorkOS.Client.response(Profile.t())
  @spec get_profile(WorkOS.Client.t(), String.t()) :: WorkOS.Client.response(Profile.t())
  def get_profile(client \\ WorkOS.client(), access_token) do
    WorkOS.Client.get(client, Profile, "/sso/profile",
      opts: [
        access_token: access_token
      ]
    )
  end
end
