# @oagen-ignore-file — hand-maintained; client-side signature verification.

defmodule WorkOS.Webhooks.Signature do
  @moduledoc """
  WorkOS webhook signature verification.

  Verifies the `WorkOS-Signature` header (`"t=<timestamp>, v1=<hex hmac>"`)
  against the raw request body and deserializes the payload into a
  `WorkOS.EventSchema`.

      {:ok, event} =
        WorkOS.Webhooks.Signature.construct_event(sig_header, raw_body, secret)

  Lower-level primitives (`parse_signature_header/1`, `compute_signature/3`,
  `verify_payload/4`) are public for callers that need custom handling.
  """

  @default_tolerance_seconds 180

  @typedoc "Reasons signature verification can fail."
  @type verification_error ::
          :not_signed
          | :invalid_header
          | :invalid_timestamp
          | :outside_tolerance
          | :no_valid_signature
          | :invalid_json

  @typedoc """
  Verification options.

    * `:tolerance` — maximum age of the signature timestamp, in seconds
      (default #{@default_tolerance_seconds})
    * `:now_ms` — current Unix time in milliseconds (defaults to the system
      clock; injectable for tests)
  """
  @type option :: {:tolerance, non_neg_integer()} | {:now_ms, integer()}

  @doc """
  Verifies the signature header and returns the deserialized event.
  """
  @spec construct_event(String.t(), String.t(), String.t(), [option()]) ::
          {:ok, WorkOS.EventSchema.t()} | {:error, verification_error()}
  def construct_event(sig_header, body, secret, opts \\ []) do
    with {:ok, verified} <- verify_payload(sig_header, body, secret, opts) do
      case JSON.decode(verified) do
        {:ok, decoded} when is_map(decoded) -> {:ok, WorkOS.EventSchema.from_map(decoded)}
        _ -> {:error, :invalid_json}
      end
    end
  end

  @doc """
  Verifies a signature header against the raw body and returns the verified
  body on success.
  """
  @spec verify_payload(String.t(), String.t(), String.t(), [option()]) ::
          {:ok, String.t()} | {:error, verification_error()}
  def verify_payload(sig_header, body, secret, opts \\ []) do
    tolerance_ms = Keyword.get(opts, :tolerance, @default_tolerance_seconds) * 1000
    now_ms = Keyword.get_lazy(opts, :now_ms, fn -> System.system_time(:millisecond) end)

    with {:ok, timestamp, signature} <- parse_signature_header(sig_header),
         {:ok, signed_at_ms} <- parse_timestamp(timestamp),
         :ok <- check_tolerance(now_ms, signed_at_ms, tolerance_ms),
         :ok <- check_signature(secret, timestamp, body, signature) do
      {:ok, body}
    end
  end

  @doc """
  Computes the hex-encoded HMAC-SHA256 signature of `"<timestamp>.<body>"`.
  """
  @spec compute_signature(String.t(), String.t(), String.t()) :: String.t()
  def compute_signature(secret, timestamp, body) do
    :hmac
    |> :crypto.mac(:sha256, secret, "#{timestamp}.#{body}")
    |> Base.encode16(case: :lower)
  end

  @doc """
  Parses a `"t=<timestamp>, v1=<signature>"` header into its parts.
  """
  @spec parse_signature_header(String.t() | nil) ::
          {:ok, String.t(), String.t()} | {:error, :not_signed | :invalid_header}
  def parse_signature_header(header) when header in [nil, ""], do: {:error, :not_signed}

  def parse_signature_header(header) when is_binary(header) do
    parts =
      header
      |> String.split(",")
      |> Enum.map(fn part ->
        case String.split(String.trim(part), "=", parts: 2) do
          [key, value] -> {String.trim(key), String.trim(value)}
          _ -> :invalid
        end
      end)

    if :invalid in parts do
      {:error, :invalid_header}
    else
      pairs = Map.new(parts)

      case {pairs["t"], pairs["v1"]} do
        {t, v1} when t in [nil, ""] or v1 in [nil, ""] -> {:error, :invalid_header}
        {t, v1} -> {:ok, t, v1}
      end
    end
  end

  defp parse_timestamp(timestamp) do
    case Integer.parse(timestamp) do
      {ms, ""} -> {:ok, ms}
      _ -> {:error, :invalid_timestamp}
    end
  end

  defp check_tolerance(now_ms, signed_at_ms, tolerance_ms) do
    if abs(now_ms - signed_at_ms) > tolerance_ms do
      {:error, :outside_tolerance}
    else
      :ok
    end
  end

  defp check_signature(secret, timestamp, body, signature) do
    expected = compute_signature(secret, timestamp, body)

    if secure_compare(expected, signature) do
      :ok
    else
      {:error, :no_valid_signature}
    end
  end

  # Constant-time comparison to prevent timing attacks.
  defp secure_compare(a, b) when byte_size(a) == byte_size(b),
    do: :crypto.hash_equals(a, b)

  defp secure_compare(_a, _b), do: false
end
