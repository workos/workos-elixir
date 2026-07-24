# @oagen-ignore-file — hand-maintained tests for AuthKit Actions helpers.

defmodule WorkOS.ActionsTest do
  use ExUnit.Case, async: true

  alias WorkOS.Webhooks.Signature

  @secret "actions_secret_123"
  @payload ~s({"id":"event_123","event":"authentication.action","data":{"user":{"id":"user_123"}},"created_at":"2026-01-01T00:00:00.000Z"})

  defp signed_header(payload, now_ms) do
    timestamp = Integer.to_string(now_ms)
    "t=#{timestamp}, v1=#{Signature.compute_signature(@secret, timestamp, payload)}"
  end

  test "verify_header accepts a valid signature" do
    header = signed_header(@payload, System.system_time(:millisecond))

    assert :ok = WorkOS.Actions.verify_header(@payload, header, @secret)
  end

  test "verify_header rejects a tampered payload" do
    header = signed_header(@payload, System.system_time(:millisecond))

    assert {:error, :no_valid_signature} =
             WorkOS.Actions.verify_header(@payload <> "x", header, @secret)
  end

  test "verify_header enforces its tighter default tolerance" do
    stale_ms = System.system_time(:millisecond) - :timer.minutes(2)
    header = signed_header(@payload, stale_ms)

    assert {:error, :outside_tolerance} =
             WorkOS.Actions.verify_header(@payload, header, @secret)

    assert :ok = WorkOS.Actions.verify_header(@payload, header, @secret, tolerance: 3600)
  end

  test "construct_action verifies and deserializes the request" do
    header = signed_header(@payload, System.system_time(:millisecond))

    assert {:ok, %WorkOS.EventSchema{} = action} =
             WorkOS.Actions.construct_action(@payload, header, @secret)

    assert action.event == "authentication.action"
    assert action.data["user"]["id"] == "user_123"
  end

  test "sign_response produces a payload the verifier accepts" do
    assert {:ok, %{payload: payload, sig: sig}} =
             WorkOS.Actions.sign_response(
               %{type: "authentication", verdict: "Allow"},
               @secret
             )

    decoded = payload |> Base.decode64!() |> JSON.decode!()
    assert decoded["type"] == "authentication"
    assert decoded["verdict"] == "Allow"

    # The signature is over the base64 payload, in the standard header format.
    assert :ok = WorkOS.Actions.verify_header(payload, sig, @secret)
  end

  test "sign_response carries a deny error message" do
    assert {:ok, %{payload: payload}} =
             WorkOS.Actions.sign_response(
               %{type: "user_registration", verdict: "Deny", error_message: "Blocked"},
               @secret
             )

    decoded = payload |> Base.decode64!() |> JSON.decode!()
    assert decoded["verdict"] == "Deny"
    assert decoded["error_message"] == "Blocked"
  end
end
