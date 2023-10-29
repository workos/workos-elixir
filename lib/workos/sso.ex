defmodule WorkOS.SSO do
  @moduledoc """
  Manage Single Sign-On (SSO) in WorkOS.

  @see https://docs.workos.com/sso/overview
  """

  require Logger

  alias WorkOS.SSO.Connection
  alias WorkOS.SSO.ProfileAndToken

  @doc """
  Lists all connections.
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
          order: opts[:order]
        }
      ]
    )
  end

  @doc """
  Deletes a connection.
  """
  @spec delete_connection(String.t()) :: WorkOS.Client.response(Connection.t())
  @spec delete_connection(WorkOS.Client.t(), String.t()) :: WorkOS.Client.response(Connection.t())
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
  """
  @spec get_authorization_url(map()) :: {:ok, String.t()} | {:error, String.t()}
  def get_authorization_url(params) do
    if is_map_key(params, :connection) or is_map_key(params, :organization) or
         is_map_key(params, :redirect_uri) do
      if is_map_key(params, :domain) do
        Logger.warn(
          "The `domain` parameter for `get_authorization_url` is deprecated. Please use `organization` instead."
        )
      end

      defaults = %{
        client_id: WorkOS.config() |> Keyword.take([:client_id]),
        response_type: "code"
      }

      query =
        defaults
        |> Map.merge(params)
        |> Map.take(
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
          ] ++ Map.keys(defaults)
        )
        |> URI.encode_query()

      base_url = WorkOS.config() |> Keyword.take([:base_url])

      {:ok, "#{base_url}/sso/authorize?#{query}"}
    else
      {:error, "Invalid params"}
    end
  end

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
      # TODO - Maybe create a separate getter function for those values
      client_id: WorkOS.config() |> Keyword.take([:client_id]),
      client_secret: WorkOS.config() |> Keyword.take([:client_secret]),
      grant_type: "authorization_code",
      code: opts["code"]
    })
  end
end
