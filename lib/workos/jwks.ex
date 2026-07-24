# @oagen-ignore-file — hand-maintained; JWKS convenience surface.

defmodule WorkOS.JWKS do
  @moduledoc """
  JWKS (JSON Web Key Set) helpers for token and session verification.

      WorkOS.JWKS.url(client)
      #=> "https://api.workos.com/sso/jwks/client_..."

      {:ok, jwks} = WorkOS.JWKS.fetch(client)
  """

  @doc """
  Builds the JWKS URL for a client ID. Defaults to the client's configured
  `client_id`.
  """
  @spec url(WorkOS.Client.t(), String.t() | nil) :: String.t()
  def url(client, client_id \\ nil) do
    client_id = require_client_id(client, client_id)
    "#{client.base_url}/sso/jwks/#{URI.encode(client_id, &URI.char_unreserved?/1)}"
  end

  @doc """
  Fetches the JWKS for a client ID. Defaults to the client's configured
  `client_id`.
  """
  @spec fetch(WorkOS.Client.t(), String.t() | nil, keyword()) ::
          {:ok, WorkOS.JwksResponse.t()} | {:error, WorkOS.Error.error()}
  def fetch(client, client_id \\ nil, opts \\ []) do
    WorkOS.UserManagement.get_jwks(client, require_client_id(client, client_id), opts)
  end

  defp require_client_id(client, client_id) do
    case client_id || client.client_id do
      id when is_binary(id) and id != "" ->
        id

      _missing ->
        raise ArgumentError,
              "a client_id is required — pass one explicitly or configure it on WorkOS.Client.new/1"
    end
  end
end
