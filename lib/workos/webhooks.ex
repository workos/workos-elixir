defmodule WorkOS.Webhooks do
  @moduledoc """
  Provide convenience methods for working with WorkOS webhooks.
  Creates a WorkOS Webhook Event from the webhook's payload if signature is valid.

  See https://workos.com/docs/webhooks
  """

  alias WorkOS.Webhooks.Event
  @three_minute_default_tolerance 60 * 3

  @doc """
  Verify webhook payload and return an event.

  `payload` is the raw, unparsed content body sent by WorkOS, which can be
  retrieved with `Plug.Conn.read_body/2`, Note that `Plug.Parsers` will read
  and discard the body, so you must implement a [custom body reader][1] if the
  plug is located earlier in the pipeline.

  `sigHeader` is the value of `workos-signature` header, which can be fetched
  with `Plug.Conn.get_req_header/2`, i.e. `Plug.Conn.get_req_header(conn, "workos-signature")`.

  `secret` is your webhook endpoint's secret from the WorkOS Dashboard.

  `tolerance` is the allowed deviation in seconds from the current system time
  to the timestamp found in `signature`. Defaults to 180 seconds (3 minutes).

  WorkOS API reference:
  https://workos.com/docs/webhooks/securing-your-webhook-endpoint/validating-events-are-from-workos

  [1]: https://hexdocs.pm/plug/Plug.Parsers.html#module-custom-body-reader

  ## Example plug in your consuming application which places the constructed
     event in the conn assigns

  defmodule MyAppWeb.WorkOSWebhooksPlug do
    @behaviour Plug

    alias Plug.Conn

    def init(config), do: config

    # Match on any requests from workos, i.e. the Endpoint URL configured in
    # the WorkOS Dashboard, adjust @request_path as appropriate
    @request_path "/webhooks/workos"
    def call(%{request_path: @request_path} = conn, _) do
      signing_secret = Application.get_env(:workos, :webhook_signing_secret)
      [worksos_signature] = Conn.get_req_header(conn, "workos-signature")

      with {:ok, body, _} <- Conn.read_body(conn),
           {:ok, workos_event} <-
             WorkOS.Webhooks.construct_event(body, worksos_signature, signing_secret) do
        Conn.assign(conn, :workos_event, workos_event)
      else
        {:error, error} ->
          conn
          |> Conn.send_resp(:bad_request, error.message)
          |> Conn.halt()
      end
    end

    def call(conn, _), do: conn
  end

  As per the aforementioned note about `Plug.Parsers` the above plug would need to
  precede these in Endpoint.ex ... i.e.

  defmodule MyAppWeb.Endpoint do
    ...
    ...

    plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

    plug MyAppWeb.WorkOSWebhooksPlug

    plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()
    ...
    ...
  """
  @spec construct_event(
          payload :: String.t(),
          sigHeader :: String.t(),
          secret :: String.t(),
          tolerance :: pos_integer()
        ) :: {:ok, payload :: map()} | {:error, message :: String.t()}
  def construct_event(payload, sigHeader, secret, tolerance \\ @three_minute_default_tolerance) do
    with {:ok, %{timestamp: timestamp, expected_signature_hash: expected_signature_hash}} <-
           get_timestamp_and_expected_signature_hash(sigHeader),
         :ok <- verify_time_tolerance(timestamp, tolerance),
         {:ok, computed_signature_hash} <- compute_signature(timestamp, payload, secret),
         :ok <- compare_signatures(computed_signature_hash, expected_signature_hash) do
      {:ok, payload |> Jason.decode!() |> Event.new()}
    end
  end

  defp compare_signatures(computed_signature_hash, expected_signature_hash) do
    if Plug.Crypto.secure_compare(computed_signature_hash, expected_signature_hash) do
      :ok
    else
      {:error, "Signature hash does not match the expected signature hash for payload"}
    end
  end

  defp compute_signature(timestamp, payload, secret) do
    unhashed_string = "#{timestamp}.#{payload}"

    computed_signature =
      :crypto.mac(:hmac, :sha256, secret, unhashed_string)
      |> Base.encode16(case: :lower)

    {:ok, computed_signature}
  end

  defp verify_time_tolerance(timestamp, tolerance) do
    timestamp_date = DateTime.from_unix!(timestamp, :millisecond)

    latest_allowed_date = DateTime.utc_now() |> DateTime.add(tolerance * -1)

    if DateTime.compare(timestamp_date, latest_allowed_date) == :gt do
      :ok
    else
      {:error, "Timestamp outside the tolerance zone"}
    end
  end

  @expected_scheme "v1"
  defp get_timestamp_and_expected_signature_hash(signature) do
    parsed =
      for pair <- String.split(signature, ","),
          destructure([key, value], String.split(pair, "=", parts: 2)),
          do: {key |> String.trim(), value},
          into: %{}

    with %{"t" => timestamp, @expected_scheme => signature_hash} <- parsed,
         {timestamp, ""} <- Integer.parse(timestamp),
         true <- String.length(signature_hash) > 0 do
      {:ok, %{timestamp: timestamp, expected_signature_hash: signature_hash}}
    else
      _ -> {:error, "Signature or timestamp missing"}
    end
  end
end
