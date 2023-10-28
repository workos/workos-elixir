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
  @spec list_connections(WorkOS.Client.t(), map()) :: WorkOS.Client.response(WorkOS.List.t(Connection.t()))
  def list_connections(client \\ WorkOS.client(), opts) do
    WorkOS.Client.get(client, WorkOS.List.of(Connection), "/connections", %{
      connection_type: opts[:connection_type],
      domain: opts[:domain],
      organization_id: opts[:organization_id],
      limit: opts[:limit],
      before: opts[:before],
      after: opts[:after],
      order: opts[:order],
    })
  end
end
