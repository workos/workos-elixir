defmodule WorkOS.MFATest do
  use WorkOS.TestCase

  alias WorkOS.MFA.ClientMock

  setup :setup_env

  describe "enroll_factor" do
    test "with a valid payload, enrolls auth factor", context do
      opts = [
        type: "totp"
      ]

      context |> ClientMock.enroll_factor(assert_fields: opts)

      assert {:ok,
              %WorkOS.MFA.AuthenticationFactor{
                id: id
              }} =
               WorkOS.MFA.enroll_factor(opts |> Enum.into(%{}))

      refute is_nil(id)
    end
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
end
