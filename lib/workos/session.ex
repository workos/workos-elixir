# @oagen-ignore-file — hand-maintained; client-side session-cookie management.

defmodule WorkOS.Session do
  @moduledoc """
  Sealed session-cookie management for AuthKit.

  A sealed session is an encrypted (AES-256-GCM) cookie value holding the
  access token, refresh token, and user returned by an authentication flow.

      session = WorkOS.Session.new(client, sealed_cookie, cookie_password)

      result = WorkOS.Session.authenticate(session)
      result.authenticated
      #=> true

      {:ok, refreshed} = WorkOS.Session.refresh(session)
      refreshed.sealed_session

  Convenience entry points that skip building the struct:

    * `authenticate/2` — one-shot authentication from a sealed value
    * `refresh_session/4` — one-shot refresh from a sealed value
    * `seal_session_from_auth_response/2` — seal an `WorkOS.AuthenticateResponse`
    * `seal_data/2` / `unseal_data/2` — raw seal/unseal for arbitrary data

  The cookie password should be a hex-encoded 32-byte key (64 hex characters);
  any other non-empty value is hashed with SHA-256 to derive the key.
  """

  @default_base_url "https://api.workos.com"
  @nonce_size 12
  @tag_size 16

  defstruct [:client, :sealed_session, :cookie_password]

  @type t :: %__MODULE__{
          client: WorkOS.Client.t() | nil,
          sealed_session: String.t() | nil,
          cookie_password: String.t()
        }

  @typedoc "Session payload carried inside the sealed cookie."
  @type session_data :: %{
          access_token: String.t() | nil,
          refresh_token: String.t() | nil,
          user: WorkOS.User.t() | map() | nil,
          impersonator: WorkOS.AuthenticateResponseImpersonator.t() | map() | nil
        }

  @typedoc """
  Result of `authenticate/1`. When `authenticated` is `false`, `reason` is one
  of `"no_session_cookie_provided"`, `"invalid_session_cookie"`,
  `"invalid_jwt"`, or `"session_expired"`. `needs_refresh` is `true` when the
  cookie was valid but the access token has expired — refresh the session
  before treating the user as unauthenticated.
  """
  @type auth_result :: %{
          authenticated: boolean(),
          session_id: String.t() | nil,
          organization_id: String.t() | nil,
          role: String.t() | nil,
          permissions: [String.t()] | nil,
          entitlements: [String.t()] | nil,
          user: WorkOS.User.t() | map() | nil,
          impersonator: WorkOS.AuthenticateResponseImpersonator.t() | map() | nil,
          needs_refresh: boolean(),
          reason: String.t() | nil
        }

  @typedoc "Successful result of `refresh/2`."
  @type refresh_result :: %{
          authenticated: true,
          sealed_session: String.t(),
          session: session_data()
        }

  @typedoc """
  Failed result of `refresh/2`. `reason` is one of
  `"no_session_cookie_provided"`, `"invalid_session_cookie"`,
  `"no_refresh_token"`, `"refresh_token_revoked"`, or `"refresh_failed"`;
  `error` carries the underlying API error when the refresh call itself failed.
  """
  @type refresh_error :: %{
          authenticated: false,
          reason: String.t(),
          error: WorkOS.Error.error() | nil
        }

  @doc """
  Builds a session helper from a sealed cookie value.

  `client` may be `nil` for authenticate-only usage; `refresh/2` requires it.
  """
  @spec new(WorkOS.Client.t() | nil, String.t() | nil, String.t()) :: t()
  def new(client, sealed_session, cookie_password) do
    %__MODULE__{client: client, sealed_session: sealed_session, cookie_password: cookie_password}
  end

  @doc """
  Validates the sealed session: unseals the cookie, checks the access token,
  and extracts its JWT claims. See `t:auth_result/0`.

  `authenticate/2` is the one-shot variant taking the sealed value and cookie
  password directly.
  """
  @spec authenticate(t()) :: auth_result()
  def authenticate(%__MODULE__{sealed_session: sealed}) when sealed in [nil, ""] do
    failed_auth("no_session_cookie_provided")
  end

  def authenticate(%__MODULE__{} = session) do
    with {:ok, data} <- unseal_session(session.sealed_session, session.cookie_password),
         {:ok, claims} <- claims_for(data) do
      base = %{
        session_id: claims["sid"],
        organization_id: claims["org_id"],
        role: claims["role"],
        permissions: claims["permissions"],
        entitlements: claims["entitlements"],
        user: data.user,
        impersonator: data.impersonator
      }

      if expired?(claims) do
        Map.merge(failed_auth("session_expired"), Map.put(base, :needs_refresh, true))
      else
        Map.merge(failed_auth(nil), Map.put(base, :authenticated, true))
      end
    else
      {:error, :invalid_jwt} -> failed_auth("invalid_jwt")
      {:error, _reason} -> failed_auth("invalid_session_cookie")
    end
  end

  @doc """
  One-shot session authentication from a sealed value and cookie password.
  No client is required.
  """
  @spec authenticate(String.t() | nil, String.t()) :: auth_result()
  def authenticate(sealed_session, cookie_password) do
    nil |> new(sealed_session, cookie_password) |> authenticate()
  end

  @doc """
  Refreshes the session using its refresh token and reseals it.

  Returns `{:ok, refresh_result}` with the new sealed session, or
  `{:error, refresh_error}` — see `t:refresh_error/0` for the reasons.
  """
  @spec refresh(t(), keyword()) :: {:ok, refresh_result()} | {:error, refresh_error()}
  def refresh(session, opts \\ [])

  def refresh(%__MODULE__{sealed_session: sealed}, _opts) when sealed in [nil, ""] do
    {:error, failed_refresh("no_session_cookie_provided")}
  end

  def refresh(%__MODULE__{client: nil}, _opts) do
    raise ArgumentError, "a WorkOS.Client is required for session refresh"
  end

  def refresh(%__MODULE__{} = session, opts) do
    case unseal_session(session.sealed_session, session.cookie_password) do
      {:error, _reason} ->
        {:error, failed_refresh("invalid_session_cookie")}

      {:ok, %{refresh_token: refresh_token}} when refresh_token in [nil, ""] ->
        {:error, failed_refresh("no_refresh_token")}

      {:ok, data} ->
        do_refresh(session, data, opts)
    end
  end

  @doc """
  One-shot session refresh from a sealed value and cookie password.
  """
  @spec refresh_session(WorkOS.Client.t(), String.t() | nil, String.t(), keyword()) ::
          {:ok, refresh_result()} | {:error, refresh_error()}
  def refresh_session(client, sealed_session, cookie_password, opts \\ []) do
    client |> new(sealed_session, cookie_password) |> refresh(opts)
  end

  @doc """
  Builds the logout URL for the session.

  The session ID is read from the access token's claims — an expired access
  token still yields a usable logout URL. Options:

    * `:return_to` — URL to redirect to after logout
  """
  @spec get_logout_url(t(), keyword()) :: {:ok, String.t()} | {:error, String.t()}
  def get_logout_url(%__MODULE__{} = session, opts \\ []) do
    case authenticate(session) do
      %{session_id: session_id} when is_binary(session_id) and session_id != "" ->
        base_url = if session.client, do: session.client.base_url, else: @default_base_url

        query =
          %{"session_id" => session_id}
          |> maybe_put("return_to", opts[:return_to])
          |> URI.encode_query()

        {:ok, "#{base_url}/user_management/sessions/logout?#{query}"}

      %{reason: reason} ->
        {:error, reason || "session has no session ID"}
    end
  end

  @doc """
  Seals session data (or any auth artifact) from a `WorkOS.AuthenticateResponse`,
  producing a sealed cookie value directly from a successful auth exchange.
  """
  @spec seal_session_from_auth_response(WorkOS.AuthenticateResponse.t(), String.t()) ::
          {:ok, String.t()} | {:error, term()}
  def seal_session_from_auth_response(%WorkOS.AuthenticateResponse{} = response, cookie_password) do
    seal_session(
      %{
        access_token: response.access_token,
        refresh_token: response.refresh_token,
        user: response.user,
        impersonator: response.impersonator
      },
      cookie_password
    )
  end

  @doc """
  Seals a `t:session_data/0` map into a cookie value.
  """
  @spec seal_session(session_data(), String.t()) :: {:ok, String.t()} | {:error, term()}
  def seal_session(data, cookie_password) do
    %{
      "access_token" => data[:access_token],
      "refresh_token" => data[:refresh_token],
      "user" => dump(data[:user]),
      "impersonator" => dump(data[:impersonator])
    }
    |> WorkOS.Cast.drop_nils()
    |> seal_data(cookie_password)
  end

  @doc """
  Seals any JSON-serializable term with AES-256-GCM under the given password.
  Returns a base64-encoded string (`nonce || ciphertext || tag`).
  """
  @spec seal_data(term(), String.t()) :: {:ok, String.t()} | {:error, term()}
  def seal_data(data, password) do
    with {:ok, key} <- derive_key(password) do
      plaintext = JSON.encode!(data)
      nonce = :crypto.strong_rand_bytes(@nonce_size)

      {ciphertext, tag} =
        :crypto.crypto_one_time_aead(:aes_256_gcm, key, nonce, plaintext, "", true)

      {:ok, Base.encode64(nonce <> ciphertext <> tag)}
    end
  end

  @doc """
  Unseals a value produced by `seal_data/2` back into the original term.
  """
  @spec unseal_data(String.t(), String.t()) :: {:ok, term()} | {:error, term()}
  def unseal_data(sealed, password) do
    with {:ok, key} <- derive_key(password),
         {:ok, raw} <- decode_sealed(sealed),
         {:ok, plaintext} <- decrypt(raw, key) do
      case JSON.decode(plaintext) do
        {:ok, decoded} -> {:ok, decoded}
        {:error, _} -> {:error, :invalid_payload}
      end
    end
  end

  defp dump(%WorkOS.User{} = user), do: WorkOS.User.to_map(user)

  defp dump(%WorkOS.AuthenticateResponseImpersonator{} = impersonator),
    do: WorkOS.AuthenticateResponseImpersonator.to_map(impersonator)

  defp dump(other), do: other

  defp decode_sealed(sealed) when is_binary(sealed) do
    case Base.decode64(sealed) do
      {:ok, raw} when byte_size(raw) >= @nonce_size + @tag_size -> {:ok, raw}
      {:ok, _short} -> {:error, :sealed_data_too_short}
      :error -> {:error, :invalid_base64}
    end
  end

  defp decode_sealed(_sealed), do: {:error, :invalid_base64}

  defp decrypt(raw, key) do
    ciphertext_size = byte_size(raw) - @nonce_size - @tag_size

    <<nonce::binary-size(@nonce_size), ciphertext::binary-size(ciphertext_size),
      tag::binary-size(@tag_size)>> = raw

    case :crypto.crypto_one_time_aead(:aes_256_gcm, key, nonce, ciphertext, "", tag, false) do
      plaintext when is_binary(plaintext) -> {:ok, plaintext}
      :error -> {:error, :decryption_failed}
    end
  end

  # The password is either a hex-encoded 32-byte key used verbatim, or any
  # other non-empty string hashed with SHA-256. Empty passwords are rejected:
  # SHA-256("") is publicly known, so accepting one would let anyone forge
  # and unseal session cookies.
  defp derive_key(password) when is_binary(password) do
    case Base.decode16(password, case: :mixed) do
      {:ok, <<key::binary-size(32)>>} -> {:ok, key}
      _ when password == "" -> {:error, :empty_cookie_password}
      _ -> {:ok, :crypto.hash(:sha256, password)}
    end
  end

  defp derive_key(_password), do: {:error, :empty_cookie_password}

  defp unseal_session(sealed, password) do
    case unseal_data(sealed, password) do
      {:ok, data} when is_map(data) ->
        {:ok,
         %{
           access_token: data["access_token"],
           refresh_token: data["refresh_token"],
           user: WorkOS.Cast.nested(data["user"], &WorkOS.User.from_map/1),
           impersonator:
             WorkOS.Cast.nested(
               data["impersonator"],
               &WorkOS.AuthenticateResponseImpersonator.from_map/1
             )
         }}

      {:ok, _other} ->
        {:error, :invalid_payload}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp claims_for(%{access_token: token}) when token in [nil, ""], do: {:error, :invalid_jwt}
  defp claims_for(%{access_token: token}), do: decode_jwt_claims(token)

  # Decodes the payload of a JWT without verifying its signature — the token
  # came out of a cookie we sealed, so it is trusted after unsealing.
  defp decode_jwt_claims(token) do
    with [_header, payload, _signature] <- String.split(token, "."),
         {:ok, decoded} <- Base.url_decode64(payload, padding: false),
         {:ok, claims} when is_map(claims) <- JSON.decode(decoded) do
      {:ok, claims}
    else
      _ -> {:error, :invalid_jwt}
    end
  end

  defp expired?(%{"exp" => exp}) when is_integer(exp),
    do: System.system_time(:second) >= exp

  defp expired?(_claims), do: false

  defp do_refresh(session, data, opts) do
    params =
      %{"refresh_token" => data.refresh_token}
      |> maybe_put("organization_id", organization_id_from(data))

    case WorkOS.UserManagement.authenticate_with_refresh_token(session.client, params, opts) do
      {:ok, response} ->
        new_data = %{
          access_token: response.access_token,
          refresh_token: response.refresh_token,
          user: response.user,
          impersonator: response.impersonator
        }

        with {:ok, sealed} <- seal_session(new_data, session.cookie_password) do
          {:ok, %{authenticated: true, sealed_session: sealed, session: new_data}}
        end

      {:error, %WorkOS.ApiError{status: 401, code: "invalid_grant"} = error} ->
        {:error, failed_refresh("refresh_token_revoked", error)}

      {:error, error} ->
        {:error, failed_refresh("refresh_failed", error)}
    end
  end

  defp organization_id_from(%{access_token: token}) when is_binary(token) and token != "" do
    case decode_jwt_claims(token) do
      {:ok, %{"org_id" => org_id}} when is_binary(org_id) and org_id != "" -> org_id
      _ -> nil
    end
  end

  defp organization_id_from(_data), do: nil

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp failed_auth(reason) do
    %{
      authenticated: false,
      session_id: nil,
      organization_id: nil,
      role: nil,
      permissions: nil,
      entitlements: nil,
      user: nil,
      impersonator: nil,
      needs_refresh: false,
      reason: reason
    }
  end

  defp failed_refresh(reason, error \\ nil) do
    %{authenticated: false, reason: reason, error: error}
  end
end
