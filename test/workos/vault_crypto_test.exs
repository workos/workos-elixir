# @oagen-ignore-file — hand-maintained tests for client-side Vault crypto.

defmodule WorkOS.Vault.CryptoTest do
  use ExUnit.Case, async: true

  @data_key :crypto.strong_rand_bytes(32)
  @data_key_b64 Base.encode64(@data_key)
  # Over 127 bytes so the LEB128 length prefix takes more than one byte.
  @encrypted_keys :crypto.strong_rand_bytes(200)
  @encrypted_keys_b64 Base.encode64(@encrypted_keys)

  defp build_client do
    WorkOS.Client.new(
      api_key: "sk_test_key",
      req_options: [plug: {Req.Test, WorkOS.Client}]
    )
  end

  defp key_pair do
    %WorkOS.CreateDataKeyResponse{
      context: %{"org" => "org_123"},
      data_key: @data_key_b64,
      encrypted_keys: @encrypted_keys_b64,
      id: "key_123"
    }
  end

  defp decrypt_key do
    %WorkOS.DecryptResponse{data_key: @data_key_b64, id: "key_123"}
  end

  describe "local encrypt/decrypt" do
    test "roundtrips data without touching the API" do
      assert {:ok, encrypted} = WorkOS.Vault.Crypto.local_encrypt("my secret", key_pair())
      assert {:ok, "my secret"} = WorkOS.Vault.Crypto.local_decrypt(encrypted, decrypt_key())
    end

    test "roundtrips with associated data" do
      assert {:ok, encrypted} =
               WorkOS.Vault.Crypto.local_encrypt("my secret", key_pair(), "aad-123")

      assert {:ok, "my secret"} =
               WorkOS.Vault.Crypto.local_decrypt(encrypted, decrypt_key(), "aad-123")
    end

    test "fails when associated data does not match" do
      assert {:ok, encrypted} =
               WorkOS.Vault.Crypto.local_encrypt("my secret", key_pair(), "aad-123")

      assert {:error, :decryption_failed} =
               WorkOS.Vault.Crypto.local_decrypt(encrypted, decrypt_key(), "aad-456")
    end

    test "fails with the wrong data key" do
      assert {:ok, encrypted} = WorkOS.Vault.Crypto.local_encrypt("my secret", key_pair())

      wrong = %WorkOS.DecryptResponse{data_key: Base.encode64(:crypto.strong_rand_bytes(32))}
      assert {:error, :decryption_failed} = WorkOS.Vault.Crypto.local_decrypt(encrypted, wrong)
    end

    test "embeds the encrypted keys ahead of the payload" do
      assert {:ok, encrypted} = WorkOS.Vault.Crypto.local_encrypt("my secret", key_pair())

      raw = Base.decode64!(encrypted)
      # 200 encodes as two LEB128 bytes: 0xC8 0x01.
      assert <<0xC8, 0x01, keys::binary-size(200), _rest::binary>> = raw
      assert keys == @encrypted_keys
    end

    test "rejects truncated input" do
      assert {:error, :encrypted_data_too_short} =
               WorkOS.Vault.Crypto.local_decrypt(Base.encode64(<<5, 1, 2>>), decrypt_key())
    end
  end

  describe "encrypt/decrypt via the data-key API" do
    test "encrypt fetches a data key and decrypt round-trips it" do
      Req.Test.stub(WorkOS.Client, fn conn ->
        {:ok, req_body, conn} = Plug.Conn.read_body(conn)
        req_body = JSON.decode!(req_body)

        case conn.request_path do
          "/vault/v1/keys/data-key" ->
            assert req_body["context"] == %{"org" => "org_123"}

            Req.Test.json(conn, %{
              "id" => "key_123",
              "context" => %{"org" => "org_123"},
              "data_key" => @data_key_b64,
              "encrypted_keys" => @encrypted_keys_b64
            })

          "/vault/v1/keys/decrypt" ->
            assert req_body["keys"] == @encrypted_keys_b64
            Req.Test.json(conn, %{"id" => "key_123", "data_key" => @data_key_b64})
        end
      end)

      client = build_client()

      assert {:ok, result} =
               WorkOS.Vault.Crypto.encrypt(client, "my secret", %{"org" => "org_123"})

      assert result.encrypted_keys == @encrypted_keys_b64
      assert result.key_context == %{"org" => "org_123"}

      assert {:ok, "my secret"} = WorkOS.Vault.Crypto.decrypt(client, result.encrypted_data)
    end

    test "decrypt surfaces API errors from the key exchange" do
      Req.Test.stub(WorkOS.Client, fn conn ->
        conn
        |> Plug.Conn.put_status(403)
        |> Req.Test.json(%{"message" => "Forbidden"})
      end)

      {:ok, encrypted} = WorkOS.Vault.Crypto.local_encrypt("my secret", key_pair())

      assert {:error, %WorkOS.ApiError{status: 403}} =
               WorkOS.Vault.Crypto.decrypt(build_client(), encrypted)
    end
  end
end
