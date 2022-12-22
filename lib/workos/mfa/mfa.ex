defmodule WorkOS.MFA do
  import WorkOS.API

  @factor_types ["totp", "sms"]

  @moduledoc """
  The MFA module provides convenience methods for working with the
  WorkOS MFA platform. You'll need a valid API key.

  See https://workos.com/docs/mfa
  """

  @doc """
  Enrolls an Authentication Factor to be used as an additional factor of authentication. The returned ID should be used to create an authentication Challenge.

  ### Parameters
  - params (map)
    - type (string) The type of factor you wish to enroll. Must be one of 'totp' or 'sms'.
    - totp_issuer (string) An identifier for the organization issuing the challenge.
      Should be the name of your application or company. Required when type is totp.
    - totp_user (string) An identifier for the user. Used by authenticator apps to label connections. Required when type is totp.
    - phone_number (string) A valid phone number for an SMS-enabled device. Required when type is sms.

  ### Examples

      iex> WorkOS.MFA.enroll_factor(%{
      ...>  type: "totp",
      ...>  totp_issuer: "Foo Corp",
      ...>  totp_user: "user_01GBTCQ2"
      ...> })

      {:ok, %{
        object: "authentication_factor",
        id: "auth_factor_01FVYZ5QM8N98T9ME5BCB2BBMJ",
        created_at: "2022-02-15T15:14:19.392Z",
        updated_at: "2022-02-15T15:14:19.392Z",
        type: "totp",
        totp: %{
          qr_code: "data:image/png;base64,{base64EncodedPng}",
          secret: "NAGCCFS3EYRB422HNAKAKY3XDUORMSRF",
          "uri": "otpauth://totp/FooCorp:user_01GB"
        }
      }}

      iex> WorkOS.MFA.enroll_factor(%{
      ...>  type: "sms",
      ...>  phone_number: "+15555555555"
      ...> })

      {:ok, %{
        object: "authentication_factor",
        id: "auth_factor_01FVYZ5QM8N98T9ME5BCB2BBMJ",
        created_at: "2022-02-15T15:14:19.392Z",
        updated_at: "2022-02-15T15:14:19.392Z",
        type: "sms",
        sms: %{
          phone_number: "+15555555555"
        }
      }}

  """

  def enroll_factor(params, opts \\ [])

  def enroll_factor(%{type: type}, _opts)
      when type not in @factor_types do
    raise(ArgumentError, "#{type} is not a valid value. Type must be one of #{@factor_types}")
  end

  def enroll_factor(%{type: type, phone_number: phone_number} = params, opts)
      when type in @factor_types and
             type == "sms" and
             is_binary(phone_number) do
    body =
      process_params(
        params,
        [
          :phone_number
        ],
        %{
          type: type
        }
      )

    post("/auth/factors/enroll", body, opts)
  end

  def enroll_factor(
        %{
          type: type,
          totp_issuer: totp_issuer,
          totp_user: totp_user
        } = params,
        opts
      )
      when type in @factor_types and
             type == "totp" and
             is_binary(totp_issuer) and
             is_binary(totp_user) do
    body =
      process_params(
        params,
        [
          :totp_issuer,
          :totp_user
        ],
        %{
          type: type
        }
      )

    post("/auth/factors/enroll", body, opts)
  end

  def enroll_factor(_params, _opts) do
    raise(
      ArgumentError,
      "Invalid parameters for enroll_factor. Must include type, totp_issuer, and totp_user for type 'totp', or type and phone_number for type 'sms'."
    )
  end

  @doc """
  Creates a Challenge for an Authentication Factor.

  ### Parameters
  - params (map)
    - authentication_factor_id (string) The unique ID of the Authentication Factor to be challenged.
    - sms_template (string) Optional template for SMS messages. Only applicable for sms Factors.
      Use the {{code}} token to inject the one-time code into the message. E.g., Your Foo Corp one-time code is {{code}}.

  ### Examples

      iex> WorkOS.MFA.challenge_factor(%{
      ...>  authentication_factor_id: "auth_factor_01FVYZ5QM8N98T9ME5BCB2BBMJ",
      ...> })

      {:ok, %{
        "object": "authentication_challenge",
        "id": "auth_challenge_01FVYZWQTZQ5VB6BC5MPG2EYC5",
        "created_at": "2022-02-15T15:26:53.274Z",
        "updated_at": "2022-02-15T15:26:53.274Z",
        "expires_at": "2022-02-15T15:36:53.279Z",
        "authentication_factor_id": "auth_factor_01FVYZ5QM8N98T9ME5BCB2BBMJ"
      }}

      iex> WorkOS.MFA.challenge_factor(%{
      ...>  authentication_factor_id: "auth_factor_01FVYZ5QM8N98T9ME5BCB2BBMJ",
      ...>  sms_template: "Your Foo Corp one-time code is {{code}}"
      ...> })

      {:ok, %{
        "object": "authentication_challenge",
        "id": "auth_challenge_01FVYZWQTZQ5VB6BC5MPG2EYC5",
        "created_at": "2022-02-15T15:26:53.274Z",
        "updated_at": "2022-02-15T15:26:53.274Z",
        "expires_at": "2022-02-15T15:36:53.279Z",
        "authentication_factor_id": "auth_factor_01FVYZ5QM8N98T9ME5BCB2BBMJ"
      }}

  """
  def challenge_factor(params, opts \\ [])

  def challenge_factor(
        %{
          authentication_factor_id: authentication_factor_id
        } = params,
        opts
      )
      when is_map(params) and
             is_binary(authentication_factor_id) do
    body =
      process_params(
        params,
        [
          :authentication_factor_id,
          :sms_template
        ]
      )

    post("/auth/factors/#{params[:authentication_factor_id]}/challenge", body, opts)
  end

  def challenge_factor(_params, _opts) do
    raise(
      ArgumentError,
      "Invalid parameters for challenge_factor. Must include authentication_factor_id."
    )
  end

  @doc """
  Verify Authentication Challenge.

  ### Parameters
  - params (map)
    - authentication_challenge_id (string) The unique ID of the Authentication Challenge to be verified.
    - code (string) The 6-digit code to be verified.

  ### Examples

      iex > WorkOS.MFA.verify_challenge(%{
      ... >  authentication_challenge_id: "auth_challenge_01FVYZWQTZQ5VB6BC5MPG2EYC5",
      ... >  code: "123456"
      ... > })

      {:ok, %{
        "challenge": %{
          "object": "authentication_challenge",
          "id": "auth_challenge_01FVYZWQTZQ5VB6BC5MPG2EYC5",
          "created_at": "2022-02-15T15:26:53.274Z",
          "updated_at": "2022-02-15T15:26:53.274Z",
          "expires_at": "2022-02-15T15:36:53.279Z",
          "authentication_factor_id": "auth_factor_01FVYZ5QM8N98T9ME5BCB2BBMJ",
        },
        "valid": true
      }}
  """
  def verify_challenge(params, opts \\ [])

  def verify_challenge(
        %{
          authentication_challenge_id: authentication_challenge_id,
          code: code
        } = params,
        opts
      )
      when is_map(params) and
             is_binary(authentication_challenge_id) and
             is_binary(code) do
    body =
      process_params(
        params,
        [
          :authentication_challenge_id,
          :code
        ]
      )

    post("/auth/challenges/#{params[:authentication_challenge_id]}/verify", body, opts)
  end

  def verify_challenge(_params, _opts) do
    raise(
      ArgumentError,
      "Invalid parameters for verify_challenge. Must include authentication_challenge_id and code."
    )
  end

  @doc """
  Gets an Authentication Factor.

  ### Parameters
  - id (string) The unique ID of the Authentication Factor to retrieve.

  ### Examples
      iex > WorkOS.MFA.get_factor("auth_factor_01FVYZ5QM8N98T9ME5BCB2BBMJ")

        {:ok, %{
          "object": "authentication_factor",
          "id": "auth_factor_01FVYZ5QM8N98T9ME5BCB2BBMJ",
          "created_at": "2022-02-15T15:14:19.392Z",
          "updated_at": "2022-02-15T15:14:19.392Z",
          "type": "totp",
          "totp": {
            "qr_code": "data:image/png;base64,{base64EncodedPng}",
            "secret": "NAGCCFS3EYRB422HNAKAKY3XDUORMSRF",
            "uri": "otpauth://totp/FooCorp:alan.turing@foo-corp.com?secret=NAGCCFS3EYRB422HNAKAKY3XDUORMSRF&issuer=FooCorp"
          }
        }
  """
  def get_factor(id, opts \\ [])

  def get_factor(id, opts) when is_binary(id) do
    get("/auth/factors/#{id}", opts)
  end

  def get_factor(_id, _opts) do
    raise(
      ArgumentError,
      "Invalid parameters for get_factor. Must include id."
    )
  end

  @doc """
  Deletes an Authentication Factor.

  ### Parameters
  - id (string) The unique ID of the Authentication Factor to delete.

  ### Examples

      iex > WorkOS.MFA.delete_factor("auth_factor_01FVYZ5QM8N98T9ME5BCB2BBMJ")
  """
  def delete_factor(id, opts \\ [])

  def delete_factor(id, opts) when is_binary(id) do
    delete("/auth/factors/#{id}", opts)
  end

  def delete_factor(_id, _opts) do
    raise(
      ArgumentError,
      "Invalid parameters for delete_factor. Must include id."
    )
  end
end
