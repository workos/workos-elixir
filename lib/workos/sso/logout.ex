# @oagen-ignore-file — hand-maintained; end-to-end SSO logout helper.

defmodule WorkOS.SSO.Logout do
  @moduledoc """
  End-to-end SSO logout: authorizes a short-lived logout token via
  `WorkOS.SSO.authorize_logout/3`, then builds the logout redirect URL.

      {:ok, url} = WorkOS.SSO.Logout.get_logout_url(client, %{profile_id: "prof_..."})

  For the individual pieces, see `WorkOS.SSO.authorize_logout/3` and
  `WorkOS.SSO.get_logout_url/2`.
  """

  @doc """
  Runs the logout flow and returns the redirect URL to send the user to.

  ## Parameters

    * `params` — map with `:profile_id` (the profile to log out) and
      optionally `:return_to` (post-logout redirect)
  """
  @spec get_logout_url(WorkOS.Client.t(), map(), keyword()) ::
          {:ok, String.t()} | {:error, WorkOS.Error.error()}
  def get_logout_url(client, params, opts \\ []) do
    params = Map.new(params, fn {k, v} -> {to_string(k), v} end)
    {return_to, authorize_params} = Map.pop(params, "return_to")

    with {:ok, response} <- WorkOS.SSO.authorize_logout(client, authorize_params, opts) do
      url =
        WorkOS.SSO.get_logout_url(
          client,
          %{"token" => response.logout_token}
          |> then(&if return_to, do: Map.put(&1, "return_to", return_to), else: &1)
        )

      {:ok, url}
    end
  end
end
