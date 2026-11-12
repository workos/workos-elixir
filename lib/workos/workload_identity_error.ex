# @oagen-ignore-file

defmodule WorkOS.WorkloadIdentityError do
  @moduledoc """
  A workload identity federation failure: the credentials are misconfigured,
  the identity token provider failed, or the token exchange was rejected.

    * `:code` — the OAuth error code from the token endpoint (for example
      `"invalid_grant"`), or one of the SDK's own codes: `"exchange_failed"`,
      `"invalid_response"`, `"provider_failed"`, `"invalid_configuration"`
    * `:description` — the token endpoint's `error_description`, cut to 500
      characters, or a short detail for an SDK code; `""` when there is none
    * `:hint` — one sentence on what to check; never empty
    * `:reason` — the underlying error when there is one (the provider's
      error, or the transport exception), otherwise `nil`

  The message is `<code>: <hint>`, followed by the description when there is
  one. Neither the identity token nor the access token ever appears in it.
  """

  defexception [:code, :description, :hint, :reason]

  @type t :: %__MODULE__{
          code: String.t(),
          description: String.t(),
          hint: String.t(),
          reason: term()
        }

  @description_limit 500

  # The one table of hints. The wording is pending the server's final error
  # codes, so change it here and nowhere else.
  @hints %{
    "invalid_grant" =>
      "The identity token did not match a trust rule for this application, or the token has " <>
        "expired. Check the issuer, audience and subject claims against the trust rule.",
    "invalid_target" =>
      "The resource or audience is wrong. The trust rule's audience must match the audience " <>
        "the identity token was requested with, and the resource must be registered for the " <>
        "environment.",
    "invalid_client" =>
      "Check that the client ID is the M2M application that has the trust rule.",
    "unauthorized_client" =>
      "This application is not allowed to use workload identity federation. Check that the " <>
        "feature is enabled for the environment and that the application has a trust rule.",
    "invalid_scope" =>
      "The requested scope is not allowed for this application. Fix the scope or leave it unset.",
    "invalid_request" =>
      "The token request was malformed. Check that the token URL points at the " <>
        "`/oauth2/token` endpoint.",
    "exchange_failed" =>
      "The token endpoint could not be reached or kept failing. Check the token URL and try " <>
        "again.",
    "invalid_response" =>
      "The token endpoint returned a response the SDK could not read. Check that the token " <>
        "URL points at the `/oauth2/token` endpoint.",
    "provider_failed" => "The identity token provider failed, so there was no token to exchange.",
    "invalid_configuration" => "Workload identity credentials are missing a required setting."
  }

  @other_oauth_hint "The token endpoint rejected the exchange."

  @doc false
  @spec new(String.t(), term(), term()) :: t()
  def new(code, description \\ "", reason \\ nil) when is_binary(code) do
    %__MODULE__{
      code: code,
      description: describe(description),
      hint: Map.get(@hints, code, @other_oauth_hint),
      reason: reason
    }
  end

  @impl Exception
  def message(%__MODULE__{code: code, hint: hint, description: ""}), do: "#{code}: #{hint}"

  def message(%__MODULE__{code: code, hint: hint, description: description}),
    do: "#{code}: #{hint} #{description}"

  defp describe(description) when is_binary(description),
    do: String.slice(description, 0, @description_limit)

  defp describe(_description), do: ""
end
