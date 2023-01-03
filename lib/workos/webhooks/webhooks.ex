defmodule WorkOS.Webhooks do
  @moduledoc """
  The Webhooks module provides convenience methods for working with WorkOS webhooks

  See https://workos.com/docs/webhooks
  """
  alias Plug.Crypto.MessageVerifier
  @three_minute_default_tolerance 60 * 3

  @doc """
  Construct a Webhook Event.
  """
  @spec construct_event(
          payload :: String.t(),
          sig_header :: String.t(),
          secret :: String.t(),
          tolerance :: pos_integer()
        ) :: {:ok, payload :: map()} | {:error, message :: String.t()}
  def construct_event(payload, sig_header, secret, tolerance \\ @three_minute_default_tolerance) do
    with {:ok, %{timestamp: timestamp, signature_hash: signature_hash}} <-
           get_timestamp_and_signature_hash(sig_header),
         :ok <- verify_time_tolerance(timestamp, tolerance),
         {:ok, expected_sig} <- compute_signature(timestamp, payload, secret),
         :ok <- compare_signatures(expected_sig, signature_hash) do
      {:ok, payload |> Jason.decode!()}
    end
  end

  defp compare_signatures(expected_sig, hashed_sig) do
    if Plug.Crypto.secure_compare(expected_sig, hashed_sig) do
      :ok
    else
      {:error, "Signature hash does not match the expected signature hash for payload"}
    end
  end

  defp compute_signature(timestamp, payload, secret) do
    unhashed_string = "#{timestamp}.#{payload}"

    {:ok, MessageVerifier.sign(unhashed_string, secret, :sha256)}
  end

  defp verify_time_tolerance(timestamp, tolerance) do
    timestamp_date = DateTime.from_unix!(timestamp |> String.to_integer(), :millisecond)

    latest_allowed_date = DateTime.utc_now() |> DateTime.add(tolerance * -1)

    if DateTime.compare(timestamp_date, latest_allowed_date) == :gt do
      :ok
    else
      {:error, "Timestamp outside the tolerance zone"}
    end
  end

  @sig_header_regex ~r/t=(?<ts>\d+).+v1=(?<sh>.+)/
  defp get_timestamp_and_signature_hash(sig_header) do
    @sig_header_regex
    |> Regex.named_captures(sig_header)
    |> parse_captures()
  end

  defp parse_captures(%{"ts" => timestamp, "sh" => signature_hash}) do
    {:ok, %{timestamp: timestamp, signature_hash: signature_hash}}
  end

  defp parse_captures(_), do: {:error, "Signature or timestamp missing"}
end
