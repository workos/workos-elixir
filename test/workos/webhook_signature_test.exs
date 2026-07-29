# @oagen-ignore-file — hand-maintained tests for webhook signature verification.

defmodule WorkOS.Webhooks.SignatureTest do
  use ExUnit.Case, async: true

  alias WorkOS.Webhooks.Signature

  @secret "webhook_secret_123"
  @body ~s({"id":"event_123","event":"dsync.user.created","data":{"id":"user_123"},"created_at":"2026-01-01T00:00:00.000Z"})

  defp signed_header(body, now_ms, secret \\ @secret) do
    timestamp = Integer.to_string(now_ms)
    "t=#{timestamp}, v1=#{Signature.compute_signature(secret, timestamp, body)}"
  end

  test "construct_event verifies and deserializes a valid payload" do
    now_ms = System.system_time(:millisecond)
    header = signed_header(@body, now_ms)

    assert {:ok, %WorkOS.EventSchema{} = event} =
             Signature.construct_event(header, @body, @secret)

    assert event.id == "event_123"
    assert event.event == "dsync.user.created"
    assert event.data["id"] == "user_123"
  end

  test "verify_payload returns the verified body" do
    now_ms = System.system_time(:millisecond)
    header = signed_header(@body, now_ms)

    assert {:ok, @body} = Signature.verify_payload(header, @body, @secret)
  end

  test "rejects a tampered body" do
    now_ms = System.system_time(:millisecond)
    header = signed_header(@body, now_ms)

    assert {:error, :no_valid_signature} =
             Signature.verify_payload(header, @body <> "tampered", @secret)
  end

  test "rejects the wrong secret" do
    now_ms = System.system_time(:millisecond)
    header = signed_header(@body, now_ms, "other_secret")

    assert {:error, :no_valid_signature} = Signature.verify_payload(header, @body, @secret)
  end

  test "rejects a missing header" do
    assert {:error, :not_signed} = Signature.verify_payload("", @body, @secret)
    assert {:error, :not_signed} = Signature.verify_payload(nil, @body, @secret)
  end

  test "rejects a timestamp outside the tolerance" do
    stale_ms = System.system_time(:millisecond) - :timer.minutes(10)
    header = signed_header(@body, stale_ms)

    assert {:error, :outside_tolerance} = Signature.verify_payload(header, @body, @secret)
  end

  test "accepts an old timestamp within a custom tolerance" do
    stale_ms = System.system_time(:millisecond) - :timer.minutes(10)
    header = signed_header(@body, stale_ms)

    assert {:ok, @body} =
             Signature.verify_payload(header, @body, @secret, tolerance: 3600)
  end

  test "parse_signature_header extracts timestamp and signature" do
    assert {:ok, "1700000000000", "abc123"} =
             Signature.parse_signature_header("t=1700000000000, v1=abc123")

    assert {:ok, "1700000000000", "abc123"} =
             Signature.parse_signature_header("t=1700000000000,v1=abc123")

    assert {:error, :invalid_header} = Signature.parse_signature_header("t=17, nonsense")
    assert {:error, :invalid_header} = Signature.parse_signature_header("v1=abc123")
    assert {:error, :not_signed} = Signature.parse_signature_header("")
  end

  test "rejects a non-numeric timestamp" do
    assert {:error, :invalid_timestamp} =
             Signature.verify_payload("t=soon, v1=abc", @body, @secret)
  end

  test "compute_signature produces lowercase hex HMAC-SHA256" do
    signature = Signature.compute_signature(@secret, "1700000000000", @body)

    assert String.length(signature) == 64
    assert signature == String.downcase(signature)

    expected =
      :hmac
      |> :crypto.mac(:sha256, @secret, "1700000000000.#{@body}")
      |> Base.encode16(case: :lower)

    assert signature == expected
  end
end
