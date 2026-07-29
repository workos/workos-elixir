# @oagen-ignore-file — hand-maintained; higher-level AuthKit flow helpers.

defmodule WorkOS.AuthKit do
  @moduledoc """
  Higher-level AuthKit authentication flow helpers.

  Layered on top of `WorkOS.UserManagement`:

    * `get_authorization_url/2` — build an AuthKit authorization URL
    * `get_pkce_authorization_url/2` — same, with PKCE and state generated
      automatically
    * `pkce_code_exchange/3` — exchange an authorization code with a PKCE
      code verifier
    * `start_device_authorization/3` and `poll_device_code/3` — the OAuth 2.0
      device authorization flow (RFC 8628)
  """

  @default_poll_interval_seconds 5

  @typedoc "Result of `get_pkce_authorization_url/2`."
  @type pkce_authorization_url :: %{
          url: String.t(),
          code_verifier: String.t(),
          state: String.t()
        }

  @doc """
  Builds an AuthKit authorization URL. See
  `WorkOS.UserManagement.get_authorization_url/2` for the supported params.
  """
  @spec get_authorization_url(WorkOS.Client.t(), map()) :: String.t()
  def get_authorization_url(client, params \\ %{}) do
    WorkOS.UserManagement.get_authorization_url(client, params)
  end

  @doc """
  Builds an AuthKit authorization URL with automatically generated PKCE
  parameters, plus a random `state` unless one is passed in `params`.

  Store `code_verifier` securely — it is required for the token exchange.
  """
  @spec get_pkce_authorization_url(WorkOS.Client.t(), map()) :: pkce_authorization_url()
  def get_pkce_authorization_url(client, params \\ %{}) do
    {params, pair, state} = put_pkce_and_state(params)
    %{url: get_authorization_url(client, params), code_verifier: pair.code_verifier, state: state}
  end

  @doc """
  Exchanges an authorization code using a PKCE code verifier
  (public-client flow).

  ## Parameters

    * `params` — map with `:code` and `:code_verifier`
  """
  @spec pkce_code_exchange(WorkOS.Client.t(), map(), keyword()) ::
          {:ok, WorkOS.AuthenticateResponse.t()} | {:error, WorkOS.Error.error()}
  def pkce_code_exchange(client, params, opts \\ []) do
    WorkOS.UserManagement.authenticate_with_code(client, params, opts)
  end

  @doc """
  Initiates a device authorization flow, returning the device/user codes and
  verification URIs.
  """
  @spec start_device_authorization(WorkOS.Client.t(), map(), keyword()) ::
          {:ok, WorkOS.DeviceAuthorizationResponse.t()} | {:error, WorkOS.Error.error()}
  def start_device_authorization(client, params \\ %{}, opts \\ []) do
    params = WorkOS.Client.put_inferred(Map.new(params), "client_id", client.client_id)
    WorkOS.UserManagement.create_device(client, params, opts)
  end

  @doc """
  Polls the authenticate endpoint until the user completes device
  authorization.

  Waits `:interval` seconds (default #{@default_poll_interval_seconds}, as
  recommended by the device authorization response) between attempts while the
  API reports `authorization_pending`. Options:

    * `:interval` — seconds between polls
    * `:max_attempts` — give up after this many polls (default `:infinity`),
      returning the last `authorization_pending` error
  """
  @spec poll_device_code(WorkOS.Client.t(), String.t(), keyword()) ::
          {:ok, WorkOS.AuthenticateResponse.t()} | {:error, WorkOS.Error.error()}
  def poll_device_code(client, device_code, opts \\ []) do
    interval = Keyword.get(opts, :interval, @default_poll_interval_seconds)
    max_attempts = Keyword.get(opts, :max_attempts, :infinity)
    request_opts = Keyword.drop(opts, [:interval, :max_attempts])

    do_poll(client, device_code, interval, max_attempts, request_opts)
  end

  defp do_poll(client, device_code, interval, attempts_left, request_opts) do
    Process.sleep(interval * 1000)

    case WorkOS.UserManagement.authenticate_with_device_code(
           client,
           %{"device_code" => device_code},
           request_opts
         ) do
      {:error, %WorkOS.ApiError{code: "authorization_pending"} = error} ->
        case attempts_left do
          :infinity -> do_poll(client, device_code, interval, :infinity, request_opts)
          n when n > 1 -> do_poll(client, device_code, interval, n - 1, request_opts)
          _exhausted -> {:error, error}
        end

      result ->
        result
    end
  end

  @doc false
  @spec put_pkce_and_state(map()) :: {map(), WorkOS.PKCE.pair(), String.t()}
  def put_pkce_and_state(params) do
    params = Map.new(params, fn {k, v} -> {to_string(k), v} end)
    pair = WorkOS.PKCE.generate_pair()

    state =
      params["state"] || Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)

    params =
      Map.merge(params, %{
        "state" => state,
        "code_challenge" => pair.code_challenge,
        "code_challenge_method" => pair.code_challenge_method
      })

    {params, pair, state}
  end
end
