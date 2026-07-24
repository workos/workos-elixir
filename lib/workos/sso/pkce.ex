# @oagen-ignore-file — hand-maintained; SSO PKCE flow helpers.

defmodule WorkOS.SSO.PKCE do
  @moduledoc """
  PKCE helpers for the SSO authorization-code flow (public clients).

      %{url: url, code_verifier: verifier, state: state} =
        WorkOS.SSO.PKCE.get_authorization_url(client, %{redirect_uri: "..."})

      # after the redirect comes back with a code:
      {:ok, token} =
        WorkOS.SSO.PKCE.code_exchange(client, %{code: code, code_verifier: verifier})
  """

  @doc """
  Builds an SSO authorization URL with automatically generated PKCE
  parameters, plus a random `state` unless one is passed in `params`.

  Store `code_verifier` securely — it is required for the token exchange.
  See `WorkOS.SSO.get_authorization_url/2` for the supported params.
  """
  @spec get_authorization_url(WorkOS.Client.t(), map()) ::
          WorkOS.AuthKit.pkce_authorization_url()
  def get_authorization_url(client, params \\ %{}) do
    {params, pair, state} = WorkOS.AuthKit.put_pkce_and_state(params)

    %{
      url: WorkOS.SSO.get_authorization_url(client, params),
      code_verifier: pair.code_verifier,
      state: state
    }
  end

  @doc """
  Exchanges an SSO authorization code using a PKCE code verifier
  (public-client flow).

  ## Parameters

    * `params` — map with `:code` and `:code_verifier`
  """
  @spec code_exchange(WorkOS.Client.t(), map(), keyword()) ::
          {:ok, WorkOS.SSOTokenResponse.t()} | {:error, WorkOS.Error.error()}
  def code_exchange(client, params, opts \\ []) do
    WorkOS.SSO.get_profile_and_token(client, params, opts)
  end
end
