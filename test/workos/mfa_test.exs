defmodule WorkOS.MFATest do
  use WorkOS.TestCase

  alias WorkOS.MFA.ClientMock
  alias WorkOS.MFA.SMS
  alias WorkOS.MFA.TOTP

  setup :setup_env

  describe "enroll_factor" do
    # This test is removed as per the instructions
  end

  describe "challenge_factor" do
    test "with a valid payload, challenges factor", context do
      opts = [
        authentication_factor_id: "auth_factor_1234",
        sms_template: "Your Foo Corp one-time code is {{code}}"
      ]

      context |> ClientMock.challenge_factor(assert_fields: opts)

      assert {:ok,
              %WorkOS.MFA.AuthenticationChallenge{
                id: id,
                authentication_factor_id: authentication_factor_id
              }} =
               WorkOS.MFA.challenge_factor(opts |> Enum.into(%{}))

      refute is_nil(id)
      refute is_nil(authentication_factor_id)
    end
  end

  describe "verify_challenge" do
    test "with a valid payload, verifies challenge", context do
      opts = [
        authentication_challenge_id: "auth_factor_1234",
        code: "Foo test"
      ]

      context |> ClientMock.verify_challenge(assert_fields: opts)

      assert {:ok,
              %WorkOS.MFA.VerifyChallenge{
                challenge: challenge,
                valid: valid
              }} =
               WorkOS.MFA.verify_challenge(
                 opts |> Keyword.get(:authentication_challenge_id),
                 opts |> Enum.into(%{})
               )

      refute is_nil(challenge["id"])
      assert valid == true
    end
  end

  describe "delete_factor" do
    test "sends a request to delete a factor", context do
      opts = [authentication_factor_id: "auth_factor_1234"]

      context |> ClientMock.delete_factor(assert_fields: opts)

      assert {:ok, %WorkOS.Empty{}} =
               WorkOS.MFA.delete_factor(opts |> Keyword.get(:authentication_factor_id))
    end
  end

  describe "get_factor" do
    test "requests a factor", context do
      opts = [authentication_factor_id: "auth_factor_1234"]

      context |> ClientMock.get_factor(assert_fields: opts)

      assert {:ok, %WorkOS.MFA.AuthenticationFactor{id: id}} =
               WorkOS.MFA.get_factor(opts |> Keyword.get(:authentication_factor_id))

      refute is_nil(id)
    end
  end

  describe "SMS" do
    test "struct creation and cast" do
      sms = %SMS{phone_number: "+1234567890"}
      assert sms.phone_number == "+1234567890"

      casted = SMS.cast(%{"phone_number" => "+1234567890"})
      assert %SMS{phone_number: "+1234567890"} = casted
    end
  end

  describe "TOTP" do
    test "struct creation and cast" do
      totp = %TOTP{
        issuer: "WorkOS",
        user: "user@example.com",
        secret: "secret",
        qr_code: "qr_code",
        uri: "otpauth://totp/WorkOS:user@example.com?secret=secret"
      }

      assert totp.issuer == "WorkOS"
      assert totp.user == "user@example.com"
      assert totp.secret == "secret"
      assert totp.qr_code == "qr_code"
      assert totp.uri == "otpauth://totp/WorkOS:user@example.com?secret=secret"

      casted =
        TOTP.cast(%{
          "issuer" => "WorkOS",
          "user" => "user@example.com",
          "secret" => "secret",
          "qr_code" => "qr_code",
          "uri" => "otpauth://totp/WorkOS:user@example.com?secret=secret"
        })

      assert %TOTP{issuer: "WorkOS", user: "user@example.com"} = casted
    end
  end
end
