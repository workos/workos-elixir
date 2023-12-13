defmodule WorkOS.MFA do
  @moduledoc """
  This module is deprecated.
  """

  @deprecated "MFA has been replaced by the User Management Multi-Factor API."

  alias WorkOS.Empty
  alias WorkOS.MFA.AuthenticationFactor
  alias WorkOS.MFA.AuthenticationChallenge
  alias WorkOS.MFA.VerifyChallenge

  @doc """
  Enrolls an Authentication Factor.

  Parameter options:

    * `:type` - The type of the factor to enroll. Only option available is `totp`. (required)
    * `:totp_issuer` - For `totp` factors. Typically your application or company name, this helps users distinguish between factors in authenticator apps.
    * `:totp_user` - For `totp` factors. Used as the account name in authenticator apps. Defaults to the user's email.
    * `:phone_number` - A valid phone number for an SMS-enabled device. Required when type is sms.

  """
  @spec enroll_factor(map()) :: WorkOS.Client.response(AuthenticationFactor.t())
  @spec enroll_factor(WorkOS.Client.t(), map()) ::
          WorkOS.Client.response(AuthenticationFactor.t())
  def enroll_factor(client \\ WorkOS.client(), opts) when is_map_key(opts, :type) do
    WorkOS.Client.post(
      client,
      AuthenticationFactor,
      "/auth/factors/enroll",
      %{
        type: opts[:type],
        totp_issuer: opts[:totp_issuer],
        totp_user: opts[:totp_user],
        phone_number: opts[:phone_number]
      }
    )
  end

  @doc """
  Creates a Challenge for an Authentication Factor.

  Parameter options:

    * `:authentication_factor_id` - The ID of the Authentication Factor. (required)
    * `:sms_template` - A valid phone number for an SMS-enabled device. Required when type is sms.

  """
  @spec challenge_factor(map()) :: WorkOS.Client.response(AuthenticationChallenge.t())
  @spec challenge_factor(WorkOS.Client.t(), map()) ::
          WorkOS.Client.response(AuthenticationChallenge.t())
  def challenge_factor(client \\ WorkOS.client(), opts)
      when is_map_key(opts, :authentication_factor_id) do
    WorkOS.Client.post(
      client,
      AuthenticationChallenge,
      "/auth/factors/:id/challenge",
      %{
        sms_template: opts[:sms_template]
      },
      opts: [
        path_params: [id: opts[:authentication_factor_id]]
      ]
    )
  end

  @doc """
  Verifies Authentication Challenge.

  Parameter options:

    * `:code` - The 6 digit code to be verified. (required)

  """
  @spec verify_challenge(String.t(), map()) :: WorkOS.Client.response(VerifyChallenge.t())
  @spec verify_challenge(WorkOS.Client.t(), String.t(), map()) ::
          WorkOS.Client.response(VerifyChallenge.t())
  def verify_challenge(client \\ WorkOS.client(), authentication_challenge_id, opts)
      when is_map_key(opts, :code) do
    WorkOS.Client.post(
      client,
      VerifyChallenge,
      "/auth/challenges/:id/verify",
      %{
        code: opts[:code]
      },
      opts: [
        path_params: [id: authentication_challenge_id]
      ]
    )
  end

  @doc """
  Gets an Authentication Factor.
  """
  @spec get_factor(String.t()) ::
          WorkOS.Client.response(AuthenticationFactor.t())
  @spec get_factor(WorkOS.Client.t(), String.t()) ::
          WorkOS.Client.response(AuthenticationFactor.t())
  def get_factor(client \\ WorkOS.client(), authentication_factor_id) do
    WorkOS.Client.get(
      client,
      AuthenticationFactor,
      "/auth/factors/:id",
      opts: [
        path_params: [id: authentication_factor_id]
      ]
    )
  end

  @doc """
  Deletes an Authentication Factor.
  """
  @spec delete_factor(String.t()) :: WorkOS.Client.response(nil)
  @spec delete_factor(WorkOS.Client.t(), String.t()) :: WorkOS.Client.response(nil)
  def delete_factor(client \\ WorkOS.client(), authentication_factor_id) do
    WorkOS.Client.delete(client, Empty, "/auth/factors/:id", %{},
      opts: [
        path_params: [id: authentication_factor_id]
      ]
    )
  end
end
