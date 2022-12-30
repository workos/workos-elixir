defmodule WorkOS.WebhooksTest do
  use ExUnit.Case

  alias WorkOS.Webhooks

  @secret "secret"
  @timestamp DateTime.utc_now() |> DateTime.add(30) |> DateTime.to_unix(:millisecond)
  @payload """
  {"id": "wh_123","data":{"id":"directory_user_01FAEAJCR3ZBZ30D8BD1924TVG","state":"active","emails":[{"type":"work","value":"blair@foo-corp.com","primary":true}],"idp_id":"00u1e8mutl6wlH3lL4x7","object":"directory_user","username":"blair@foo-corp.com","last_name":"Lunchford","first_name":"Blair","job_title":"Software Engineer","directory_id":"directory_01F9M7F68PZP8QXP8G7X5QRHS7","raw_attributes":{"name":{"givenName":"Blair","familyName":"Lunchford","middleName":"Elizabeth","honorificPrefix":"Ms."},"title":"Software Engineer","active":true,"emails":[{"type":"work","value":"blair@foo-corp.com","primary":true}],"groups":[],"locale":"en-US","schemas":["urn:ietf:params:scim:schemas:core:2.0:User","urn:ietf:params:scim:schemas:extension:enterprise:2.0:User"],"userName":"blair@foo-corp.com","addresses":[{"region":"CA","primary":true,"locality":"San Francisco","postalCode":"94016"}],"externalId":"00u1e8mutl6wlH3lL4x7","displayName":"Blair Lunchford","urn:ietf:params:scim:schemas:extension:enterprise:2.0:User":{"manager":{"value":"2","displayName":"Kate Chapman"},"division":"Engineering","department":"Customer Success"}}},"event":"dsync.user.created"}
  """
  @unhashed_string "#{@timestamp}.#{@payload}"
  @signature_hash Plug.Crypto.MessageVerifier.sign(@unhashed_string, @secret, :sha256)
  @expectated_data_map %{
    "id" => "directory_user_01FAEAJCR3ZBZ30D8BD1924TVG",
    "state" => "active",
    "emails" => [
      %{
        "type" => "work",
        "value" => "blair@foo-corp.com",
        "primary" => true
      }
    ],
    "idp_id" => "00u1e8mutl6wlH3lL4x7",
    "object" => "directory_user",
    "username" => "blair@foo-corp.com",
    "last_name" => "Lunchford",
    "first_name" => "Blair",
    "job_title" => "Software Engineer",
    "directory_id" => "directory_01F9M7F68PZP8QXP8G7X5QRHS7",
    "raw_attributes" => %{
      "name" => %{
        "givenName" => "Blair",
        "familyName" => "Lunchford",
        "middleName" => "Elizabeth",
        "honorificPrefix" => "Ms."
      },
      "title" => "Software Engineer",
      "active" => true,
      "emails" => [
        %{
          "type" => "work",
          "value" => "blair@foo-corp.com",
          "primary" => true
        }
      ],
      "groups" => [],
      "locale" => "en-US",
      "schemas" => [
        "urn:ietf:params:scim:schemas:core:2.0:User",
        "urn:ietf:params:scim:schemas:extension:enterprise:2.0:User"
      ],
      "userName" => "blair@foo-corp.com",
      "addresses" => [
        %{
          "region" => "CA",
          "primary" => true,
          "locality" => "San Francisco",
          "postalCode" => "94016"
        }
      ],
      "externalId" => "00u1e8mutl6wlH3lL4x7",
      "displayName" => "Blair Lunchford",
      "urn:ietf:params:scim:schemas:extension:enterprise:2.0:User" => %{
        "manager" => %{
          "value" => "2",
          "displayName" => "Kate Chapman"
        },
        "division" => "Engineering",
        "department" => "Customer Success"
      }
    }
  }

  describe "construct_event/4 - valid inputs" do
    setup do
      %{sig_header: "t=#{@timestamp}, v1=#{@signature_hash}"}
    end

    test "returns a webhook event with a valid payload, sig_header, and secret", %{
      sig_header: sig_header
    } do
      {:ok, webhook} = Webhooks.construct_event(@payload, sig_header, @secret)

      assert webhook["data"] == @expectated_data_map
      assert webhook["event"] == "dsync.user.created"
      assert webhook["id"] == "wh_123"
    end

    test "returns a webhook event with a valid payload, sig_header, secret, and tolerance", %{
      sig_header: sig_header
    } do
      {:ok, webhook} = Webhooks.construct_event(@payload, sig_header, @secret, 100)

      assert webhook["data"] == @expectated_data_map
      assert webhook["event"] == "dsync.user.created"
      assert webhook["id"] == "wh_123"
    end
  end

  describe "construct_event/4 - invalid inputs" do
    setup do
      %{sig_header: "t=#{@timestamp}, v1=#{@signature_hash}"}
    end

    test "returns an error with an empty header" do
      empty_sig_header = ""

      assert {:error, "Signature or timestamp missing"} ==
               Webhooks.construct_event(@payload, empty_sig_header, @secret)
    end

    test "returns an error with an empty signature hash" do
      missing_sig_hash = "t=#{@timestamp}, v1="

      assert {:error, "Signature or timestamp missing"} ==
               Webhooks.construct_event(@payload, missing_sig_hash, @secret)
    end

    test "returns an error with an incorrect signature hash" do
      incorrect_sig_hash = "t=#{@timestamp}, v1=99999"

      assert {:error, "Signature hash does not match the expected signature hash for payload"} ==
               Webhooks.construct_event(@payload, incorrect_sig_hash, @secret)
    end

    test "returns an error with an incorrect payload", %{sig_header: sig_header} do
      invalid_payload = "invalid"

      assert {:error, "Signature hash does not match the expected signature hash for payload"} ==
               Webhooks.construct_event(invalid_payload, sig_header, @secret)
    end

    test "returns an error with an incorrect secret", %{sig_header: sig_header} do
      invalid_secret = "invalid"

      assert {:error, "Signature hash does not match the expected signature hash for payload"} ==
               Webhooks.construct_event(@payload, sig_header, invalid_secret)
    end

    test "returns an error with a timestamp outside tolerance" do
      sig_header = "t=9999, v1=#{@signature_hash}"

      assert {:error, "Timestamp outside the tolerance zone"} ==
               Webhooks.construct_event(@payload, sig_header, @secret)
    end
  end
end
