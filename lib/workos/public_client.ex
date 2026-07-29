# @oagen-ignore-file — hand-maintained; PKCE-only public-client preset.

defmodule WorkOS.PublicClient do
  @moduledoc """
  A client preset for public (PKCE-only) applications — no API key required.

  Exposes only the helper surface that is safe without a client secret:
  authorization URL builders with automatic PKCE.

      public = WorkOS.PublicClient.new("client_123")

      %{url: url, code_verifier: verifier} =
        WorkOS.PublicClient.get_authorization_url(public, %{redirect_uri: "..."})

  Exchange the resulting code with `WorkOS.AuthKit.pkce_code_exchange/3` or
  `WorkOS.SSO.PKCE.code_exchange/3` from your backend, or against the token
  endpoint directly from the public client's environment.
  """

  alias WorkOS.SSO.PKCE

  defstruct [:client]

  @type t :: %__MODULE__{client: WorkOS.Client.t()}

  @doc """
  Builds a public client from a client ID. No API key is required.

  ## Options

    * `:base_url` — override the API base URL
  """
  @spec new(String.t(), keyword()) :: t()
  def new(client_id, opts \\ []) do
    if !(is_binary(client_id) and client_id != "") do
      raise WorkOS.ConfigurationError, message: "client_id is required for WorkOS.PublicClient"
    end

    %__MODULE__{
      client: %WorkOS.Client{
        # Public clients have no API key; URL builders never read it.
        api_key: "",
        client_id: client_id,
        base_url: String.trim_trailing(opts[:base_url] || "https://api.workos.com", "/"),
        timeout: 60_000,
        max_retries: 3,
        req_options: []
      }
    }
  end

  @doc """
  Builds an AuthKit authorization URL with automatically generated PKCE
  parameters and state. See `WorkOS.AuthKit.get_pkce_authorization_url/2`.
  """
  @spec get_authorization_url(t(), map()) :: WorkOS.AuthKit.pkce_authorization_url()
  def get_authorization_url(%__MODULE__{client: client}, params \\ %{}) do
    WorkOS.AuthKit.get_pkce_authorization_url(client, params)
  end

  @doc """
  Builds an SSO authorization URL with automatically generated PKCE
  parameters and state. See `WorkOS.SSO.PKCE.get_authorization_url/2`.
  """
  @spec get_sso_authorization_url(t(), map()) :: WorkOS.AuthKit.pkce_authorization_url()
  def get_sso_authorization_url(%__MODULE__{client: client}, params \\ %{}) do
    PKCE.get_authorization_url(client, params)
  end
end
