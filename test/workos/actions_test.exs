# @oagen-ignore-file — hand-maintained tests for AuthKit Actions helpers.

defmodule WorkOS.ActionsTest do
  use ExUnit.Case, async: true

  alias WorkOS.Webhooks.Signature

  @secret "actions_secret_123"
  @payload ~s({"object":"authentication_action_context","id":"action_01","authentication_method":"Password","user":{"object":"user","id":"user_01","email":"test@example.com"},"ip_address":"1.2.3.4","device_fingerprint":"fp_123","issuer":"https://auth.example.com"})

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

  test "construct_action verifies and deserializes an authentication request" do
    header = signed_header(@payload, System.system_time(:millisecond))

    assert {:ok, %WorkOS.ActionContext{} = action} =
             WorkOS.Actions.construct_action(@payload, header, @secret)

    assert action.object == "authentication_action_context"
    assert action.id == "action_01"
    assert action.authentication_method == :password
    assert action.user.id == "user_01"
    assert action.user.email == "test@example.com"
    assert action.ip_address == "1.2.3.4"
    assert action.issuer == "https://auth.example.com"
  end

  test "construct_action deserializes a user_registration request" do
    payload =
      ~s({"object":"user_registration_action_context","id":"action_02","authentication_method":"GoogleOAuth","user_data":{"object":"user_data","email":"new@example.com","first_name":"New","last_name":"User","name":null},"ip_address":"5.6.7.8","device_fingerprint":"fp_456"})

    header = signed_header(payload, System.system_time(:millisecond))

    assert {:ok, %WorkOS.ActionContext{} = action} =
             WorkOS.Actions.construct_action(payload, header, @secret)

    assert action.object == "user_registration_action_context"
    assert action.authentication_method == :google_oauth
    assert action.user_data.email == "new@example.com"
    assert action.user_data.first_name == "New"
    assert action.user == nil
  end

  test "sign_response produces a workos-node-compatible Allow response" do
    now_ms = 1_700_000_000_000

    assert {:ok, %{object: object, payload: payload, signature: signature}} =
             WorkOS.Actions.sign_response(
               %{type: "authentication", verdict: "Allow"},
               @secret,
               now_ms: now_ms
             )

    assert object == "authentication_action_response"
    assert payload == %{"timestamp" => now_ms, "verdict" => "Allow"}

    expected =
      Signature.compute_signature(@secret, Integer.to_string(now_ms), JSON.encode!(payload))

    assert signature == expected
  end

  test "sign_response carries a deny error message" do
    now_ms = 1_700_000_000_000

    assert {:ok, %{object: object, payload: payload, signature: signature}} =
             WorkOS.Actions.sign_response(
               %{type: "user_registration", verdict: "Deny", error_message: "Blocked"},
               @secret,
               now_ms: now_ms
             )

    assert object == "user_registration_action_response"
    assert payload == %{"timestamp" => now_ms, "verdict" => "Deny", "error_message" => "Blocked"}

    expected =
      Signature.compute_signature(@secret, Integer.to_string(now_ms), JSON.encode!(payload))

    assert signature == expected
  end
end
