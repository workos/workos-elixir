# @oagen-ignore-file — hand-maintained; client-side request verification and response signing.

defmodule WorkOS.Actions do
  @moduledoc """
  AuthKit Actions request verification and response signing.

  Verify an incoming action request, then sign your verdict:

      {:ok, action} = WorkOS.Actions.construct_action(payload, sig_header, secret)

      {:ok, response} =
        WorkOS.Actions.sign_response(
          %{type: "authentication", verdict: "Allow"},
          secret
        )

  `response.object`, `response.payload`, and `response.signature` form the
  action webhook response body (`{object, payload, signature}`).
  """

  alias WorkOS.Webhooks.Signature

  @default_tolerance_seconds 30

  @action_type_to_response_object %{
    "authentication" => "authentication_action_response",
    "user_registration" => "user_registration_action_response"
  }

  @typedoc """
  Options for verification and signing.

    * `:tolerance` — maximum age of the signature timestamp, in seconds
      (default #{@default_tolerance_seconds})
    * `:now_ms` — current Unix time in milliseconds (defaults to the system
      clock; injectable for tests)
  """
  @type option :: {:tolerance, non_neg_integer()} | {:now_ms, integer()}

  @doc """
  Verifies the signature of an Actions request.
  """
  @spec verify_header(String.t(), String.t(), String.t(), [option()]) ::
          :ok | {:error, WorkOS.Webhooks.Signature.verification_error()}
  def verify_header(payload, sig_header, secret, opts \\ []) do
    opts = Keyword.put_new(opts, :tolerance, @default_tolerance_seconds)

    with {:ok, _body} <-
           Signature.verify_payload(sig_header, payload, secret, opts) do
      :ok
    end
  end

  @doc """
  Verifies and deserializes an Actions request into a `WorkOS.ActionContext`.
  """
  @spec construct_action(String.t(), String.t(), String.t(), [option()]) ::
          {:ok, WorkOS.ActionContext.t()}
          | {:error, WorkOS.Webhooks.Signature.verification_error()}
  def construct_action(payload, sig_header, secret, opts \\ []) do
    with :ok <- verify_header(payload, sig_header, secret, opts) do
      case JSON.decode(payload) do
        {:ok, decoded} when is_map(decoded) -> {:ok, WorkOS.ActionContext.from_map(decoded)}
        _ -> {:error, :invalid_json}
      end
    end
  end

  @doc """
  Signs an action response.

  `response` is a map with:

    * `:type` — `"authentication"` or `"user_registration"`
    * `:verdict` — `"Allow"` or `"Deny"`
    * `:error_message` — optional message shown on deny

  Returns `{:ok, %{payload: base64_payload, sig: "t=<ms>,v1=<hex>"}}`.
  """
  @spec sign_response(map(), String.t(), [option()]) ::
          {:ok, %{object: String.t(), payload: map(), signature: String.t()}}
  def sign_response(response, secret, opts \\ []) do
    now_ms = Keyword.get_lazy(opts, :now_ms, fn -> System.system_time(:millisecond) end)

    type = to_string(Map.get(response, :type) || Map.get(response, "type"))
    verdict = to_string(Map.get(response, :verdict) || Map.get(response, "verdict"))
    error_message = Map.get(response, :error_message) || Map.get(response, "error_message")

    object = Map.fetch!(@action_type_to_response_object, type)

    payload =
      if verdict == "Deny" and is_binary(error_message) and error_message != "" do
        %{"timestamp" => now_ms, "verdict" => verdict, "error_message" => error_message}
      else
        %{"timestamp" => now_ms, "verdict" => verdict}
      end

    timestamp = Integer.to_string(now_ms)
    payload_json = JSON.encode!(payload)
    signature = Signature.compute_signature(secret, timestamp, payload_json)

    {:ok, %{object: object, payload: payload, signature: signature}}
  end
end
