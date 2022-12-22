defmodule WorkOS.MFATest do
  use ExUnit.Case
  doctest WorkOS.MFA
  import Tesla.Mock

  setup do
    mock(fn
      %{
        method: :post,
        url: "https://api.workos.com/auth/factors/enroll",
        body: "{\"phone_number\":\"+15555555555\",\"type\":\"sms\"}"
      } ->
        %Tesla.Env{
          status: 201,
          body: %{
            object: "authentication_factor",
            id: "auth_factor_01FVYZ5QM8N98T9ME5BCB2BBMJ",
            created_at: "2022-02-15T15:14:19.392Z",
            updated_at: "2022-02-15T15:14:19.392Z",
            type: "sms",
            sms: %{
              phone_number: "+15555555555"
            }
          }
        }

      %{
        method: :post,
        url: "https://api.workos.com/auth/factors/enroll",
        body: "{\"totp_issuer\":\"Foo Corp\",\"totp_user\":\"user_01GBTCQ2\",\"type\":\"totp\"}"
      } ->
        %Tesla.Env{
          status: 201,
          body: %{
            object: "authentication_factor",
            id: "auth_factor_01FVYZ5QM8N98T9ME5BCB2BBMJ",
            created_at: "2022-02-15T15:14:19.392Z",
            updated_at: "2022-02-15T15:14:19.392Z",
            type: "totp",
            totp: %{
              qr_code: "data:image/png;base64,{base64EncodedPng}",
              secret: "NAGCCFS3EYRB422HNAKAKY3XDUORMSRF",
              uri: "otpauth://totp/FooCorp:user_01GB"
            }
          }
        }

      %{
        method: :post,
        url:
          "https://api.workos.com/auth/factors/auth_factor_01FVYZ5QM8N98T9ME5BCB2BBMJ/challenge",
        body: "{\"authentication_factor_id\":\"auth_factor_01FVYZ5QM8N98T9ME5BCB2BBMJ\"}"
      } ->
        %Tesla.Env{
          status: 201,
          body: %{
            object: "authentication_factor_challenge",
            id: "auth_factor_challenge_01FVYZ5QM8N98T9ME5BCB2BBMJ",
            created_at: "2022-02-15T15:26:53.274Z",
            updated_at: "2022-02-15T15:26:53.274Z",
            expires_at: "2022-02-15T15:36:53.279Z",
            authentication_factor_id: "auth_factor_01FVYZ5QM8N98T9ME5BCB2BBMJ"
          }
        }

      %{
        method: :post,
        url:
          "https://api.workos.com/auth/factors/auth_factor_01FVYZ5QM8N98T9ME5BCB2BBMJ/challenge",
        body:
          "{\"authentication_factor_id\":\"auth_factor_01FVYZ5QM8N98T9ME5BCB2BBMJ\",\"sms_template\":\"sms_template\"}"
      } ->
        %Tesla.Env{
          status: 201,
          body: %{
            object: "authentication_factor_challenge",
            id: "auth_factor_challenge_01FVYZ5QM8N98T9ME5BCB2BBMJ",
            created_at: "2022-02-15T15:26:53.274Z",
            updated_at: "2022-02-15T15:26:53.274Z",
            expires_at: "2022-02-15T15:36:53.279Z",
            authentication_factor_id: "auth_factor_01FVYZ5QM8N98T9ME5BCB2BBMJ"
          }
        }

      %{
        method: :post,
        url:
          "https://api.workos.com/auth/challeneges/auth_factor_01FVYZ5QM8N98T9ME5BCB2BBMJ/verify",
        body:
          "{\"authentication_factor_id\":\"auth_factor_01FVYZ5QM8N98T9ME5BCB2BBMJ\",\"code\":\"123456\"}"
      } ->
        %Tesla.Env{
          status: 201,
          body: %{
            challenge: %{
              object: "authentication_factor_challenge",
              id: "auth_factor_challenge_01FVYZ5QM8N98T9ME5BCB2BBMJ",
              created_at: "2022-02-15T15:26:53.274Z",
              updated_at: "2022-02-15T15:26:53.274Z",
              expires_at: "2022-02-15T15:36:53.279Z",
              authentication_factor_id: "auth_factor_01FVYZ5QM8N98T9ME5BCB2BBMJ"
            },
            valid: true
          }
        }

      %{
        method: :get,
        url:
          "https://api.workos.com/auth/factors/auth_factor_challenge_01FVYZ5QM8N98T9ME5BCB2BBMJ"
      } ->
        %Tesla.Env{
          status: 200,
          body: %{
            object: "authentication_factor",
            id: "auth_factor_01FVYZ5QM8N98T9ME5BCB2BBMJ",
            created_at: "2022-02-15T15:14:19.392Z",
            updated_at: "2022-02-15T15:14:19.392Z",
            type: "totp",
            totp: %{
              qr_code: "data:image/png;base64,{base64EncodedPng}",
              secret: "NAGCCFS3EYRB422HNAKAKY3XDUORMSRF",
              uri:
                "otpauth://totp/FooCorp:alan.turing@foo-corp.com?secret=NAGCCFS3EYRB422HNAKAKY3XDUORMSRF&issuer=FooCorp"
            }
          }
        }

      %{
        method: :delete,
        url: "https://api.workos.com/auth/factors/auth_factor_01FVYZ5QM8N98T9ME5BCB2BBMJ"
      } ->
        %Tesla.Env{
          status: 204,
          body: ""
        }
    end)
  end

  describe "#enroll_factor/1 with type sms and valid params" do
    test "returns a valid response" do
      assert {:ok,
              %{
                object: "authentication_factor",
                id: "auth_factor_01FVYZ5QM8N98T9ME5BCB2BBMJ",
                created_at: "2022-02-15T15:14:19.392Z",
                updated_at: "2022-02-15T15:14:19.392Z",
                type: "sms",
                sms: %{
                  phone_number: "+15555555555"
                }
              }} =
               WorkOS.MFA.enroll_factor(%{
                 type: "sms",
                 phone_number: "+15555555555"
               })
    end
  end

  describe "#enroll_factor/1 with type totp and valid params" do
    test "returns a valid response" do
      assert {:ok,
              %{
                object: "authentication_factor",
                id: "auth_factor_01FVYZ5QM8N98T9ME5BCB2BBMJ",
                created_at: "2022-02-15T15:14:19.392Z",
                updated_at: "2022-02-15T15:14:19.392Z",
                type: "totp",
                totp: %{
                  qr_code: "data:image/png;base64,{base64EncodedPng}",
                  secret: "NAGCCFS3EYRB422HNAKAKY3XDUORMSRF",
                  uri: "otpauth://totp/FooCorp:user_01GB"
                }
              }} =
               WorkOS.MFA.enroll_factor(%{
                 type: "totp",
                 totp_issuer: "Foo Corp",
                 totp_user: "user_01GBTCQ2"
               })
    end
  end

  describe "#enroll_factor/1 with invalid type" do
    test "raises an ArgumentError" do
      assert_raise ArgumentError, fn ->
        WorkOS.MFA.enroll_factor(%{type: "invalid"})
      end
    end
  end

  describe "#enroll_factor/1 with type sms when phone_number is missing" do
    test "raises an ArgumentError" do
      assert_raise ArgumentError, fn ->
        WorkOS.MFA.enroll_factor(%{type: "sms"})
      end
    end
  end

  describe "#enroll_factor/1 with type totp when totp_issuer is missing" do
    test "raises an ArgumentError" do
      assert_raise ArgumentError, fn ->
        WorkOS.MFA.enroll_factor(%{type: "totp", totp_user: "user_01GBTCQ2"})
      end
    end
  end

  describe "#enroll_factor/1 with type totp when totp_user is missing" do
    test "raises an ArgumentError" do
      assert_raise ArgumentError, fn ->
        WorkOS.MFA.enroll_factor(%{type: "totp", totp_issuer: "Foo Corp"})
      end
    end
  end

  describe "#enroll_factor/1 with type totp when totp_issuer and totp_user are missing" do
    test "raises an ArgumentError" do
      assert_raise ArgumentError, fn ->
        WorkOS.MFA.enroll_factor(%{type: "totp"})
      end
    end
  end

  describe "#chanllenge_factor/1 without sms_template" do
    test "returns a valid response" do
      assert {:ok,
              %{
                object: "authentication_factor_challenge",
                id: "auth_factor_challenge_01FVYZ5QM8N98T9ME5BCB2BBMJ",
                created_at: "2022-02-15T15:26:53.274Z",
                updated_at: "2022-02-15T15:26:53.274Z",
                expires_at: "2022-02-15T15:36:53.279Z",
                authentication_factor_id: "auth_factor_01FVYZ5QM8N98T9ME5BCB2BBMJ"
              }} =
               WorkOS.MFA.challenge_factor(%{
                 authentication_factor_id: "auth_factor_01FVYZ5QM8N98T9ME5BCB2BBMJ"
               })
    end
  end

  describe "#challenge_factor/1 with sms_template" do
    test "returns a valid response" do
      assert {:ok,
              %{
                object: "authentication_factor_challenge",
                id: "auth_factor_challenge_01FVYZ5QM8N98T9ME5BCB2BBMJ",
                created_at: "2022-02-15T15:26:53.274Z",
                updated_at: "2022-02-15T15:26:53.274Z",
                expires_at: "2022-02-15T15:36:53.279Z",
                authentication_factor_id: "auth_factor_01FVYZ5QM8N98T9ME5BCB2BBMJ"
              }} =
               WorkOS.MFA.challenge_factor(%{
                 authentication_factor_id: "auth_factor_01FVYZ5QM8N98T9ME5BCB2BBMJ",
                 sms_template: "sms_template"
               })
    end
  end

  describe "#verify_challenge/1 with missing authentication_factor_id" do
    test "raises an ArgumentError" do
      assert_raise ArgumentError, fn ->
        WorkOS.MFA.verify_challenge(%{code: "123456"})
      end
    end
  end

  describe "#verify_challenge/1 with missing code" do
    test "raises an ArgumentError" do
      assert_raise ArgumentError, fn ->
        WorkOS.MFA.verify_challenge(%{
          authentication_factor_id: "auth_factor_01FVYZ5QM8N98T9ME5BCB2BBMJ"
        })
      end
    end
  end

  describe "#get_factor/1 with id" do
    test "returns a valid response" do
      assert {:ok,
              %{
                object: "authentication_factor",
                id: "auth_factor_01FVYZ5QM8N98T9ME5BCB2BBMJ",
                created_at: "2022-02-15T15:14:19.392Z",
                updated_at: "2022-02-15T15:14:19.392Z",
                type: "totp",
                totp: %{
                  qr_code: "data:image/png;base64,{base64EncodedPng}",
                  secret: "NAGCCFS3EYRB422HNAKAKY3XDUORMSRF",
                  uri:
                    "otpauth://totp/FooCorp:alan.turing@foo-corp.com?secret=NAGCCFS3EYRB422HNAKAKY3XDUORMSRF&issuer=FooCorp"
                }
              }} = WorkOS.MFA.get_factor("auth_factor_challenge_01FVYZ5QM8N98T9ME5BCB2BBMJ")
    end
  end

  describe "#delete_factor/1" do
    test "returns a valid response" do
      assert {:ok, ""} = WorkOS.MFA.delete_factor("auth_factor_01FVYZ5QM8N98T9ME5BCB2BBMJ")
    end
  end
end
