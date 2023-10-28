defmodule WorkOS.SSO do
  @moduledoc """
  Manage Single Sign-On (SSO) in WorkOS.

  @see https://docs.workos.com/sso/overview
  """

  alias WorkOS.SSO.Connection

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
end
