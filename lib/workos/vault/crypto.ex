# @oagen-ignore-file — hand-maintained; client-side AES-GCM cryptography.

defmodule WorkOS.Vault.Crypto do
  @moduledoc """
  Client-side Vault encryption and decryption, layered on the WorkOS data-key
  API (`WorkOS.Vault.create_data_key/3` and `WorkOS.Vault.create_decrypt/3`).

      {:ok, result} =
        WorkOS.Vault.Crypto.encrypt(client, "my secret", %{"org" => "org_123"})

      {:ok, "my secret"} =
        WorkOS.Vault.Crypto.decrypt(client, result.encrypted_data)

  Data is encrypted locally with AES-256-GCM; only the data key is exchanged
  with the API. The wire format (before base64) is
  `LEB128(byte_size(encrypted_keys)) || encrypted_keys || nonce(12) || ciphertext || tag(16)`,
  interoperable with the other WorkOS SDKs.
  """

  @nonce_size 12
  @tag_size 16

  @typedoc "Result of `encrypt/5`."
  @type encrypt_result :: %{
          encrypted_data: String.t(),
          key_context: %{optional(String.t()) => String.t()},
          encrypted_keys: String.t()
        }

  @doc """
  Generates a data key for `key_context` and encrypts `data` locally.

  `associated_data` is optional AES-GCM additional authenticated data — the
  same value must be passed to `decrypt/4`.
  """
  @spec encrypt(WorkOS.Client.t(), String.t(), map(), String.t() | nil, keyword()) ::
          {:ok, encrypt_result()} | {:error, WorkOS.Error.error() | term()}
  def encrypt(client, data, key_context, associated_data \\ nil, opts \\ []) do
    with {:ok, key_pair} <-
           WorkOS.Vault.create_data_key(client, %{"context" => key_context}, opts),
         {:ok, encrypted_data} <- local_encrypt(data, key_pair, associated_data) do
      {:ok,
       %{
         encrypted_data: encrypted_data,
         key_context: key_pair.context,
         encrypted_keys: key_pair.encrypted_keys
       }}
    end
  end

  @doc """
  Decrypts data produced by `encrypt/5` by first decrypting the embedded data
  key via the API.
  """
  @spec decrypt(WorkOS.Client.t(), String.t(), String.t() | nil, keyword()) ::
          {:ok, String.t()} | {:error, WorkOS.Error.error() | term()}
  def decrypt(client, encrypted_data, associated_data \\ nil, opts \\ []) do
    with {:ok, encrypted_keys} <- extract_encrypted_keys(encrypted_data),
         {:ok, data_key} <-
           WorkOS.Vault.create_decrypt(client, %{"keys" => encrypted_keys}, opts) do
      local_decrypt(encrypted_data, data_key, associated_data)
    end
  end

  @doc """
  Encrypts `data` with AES-256-GCM using a pre-fetched data key pair
  (`WorkOS.CreateDataKeyResponse`). No HTTP request is made.
  """
  @spec local_encrypt(String.t(), WorkOS.CreateDataKeyResponse.t(), String.t() | nil) ::
          {:ok, String.t()} | {:error, term()}
  def local_encrypt(data, key_pair, associated_data \\ nil) do
    with {:ok, key} <- decode_key(key_pair.data_key),
         {:ok, encrypted_keys} <- decode_base64(key_pair.encrypted_keys, :invalid_encrypted_keys) do
      nonce = :crypto.strong_rand_bytes(@nonce_size)

      {ciphertext, tag} =
        :crypto.crypto_one_time_aead(:aes_256_gcm, key, nonce, data, associated_data || "", true)

      payload =
        encode_leb128(byte_size(encrypted_keys)) <> encrypted_keys <> nonce <> ciphertext <> tag

      {:ok, Base.encode64(payload)}
    end
  end

  @doc """
  Decrypts data with AES-256-GCM using a pre-fetched data key
  (`WorkOS.DecryptResponse`). No HTTP request is made.
  """
  @spec local_decrypt(String.t(), WorkOS.DecryptResponse.t(), String.t() | nil) ::
          {:ok, String.t()} | {:error, term()}
  def local_decrypt(encrypted_data, data_key, associated_data \\ nil) do
    with {:ok, raw} <- decode_base64(encrypted_data, :invalid_base64),
         {:ok, keys_length, rest} <- decode_leb128(raw),
         {:ok, body} <- skip_encrypted_keys(rest, keys_length),
         {:ok, key} <- decode_key(data_key.data_key),
         {:ok, nonce, ciphertext, tag} <- split_payload(body) do
      open(key, nonce, ciphertext, tag, associated_data || "")
    end
  end

  defp split_payload(<<nonce::binary-size(@nonce_size), payload::binary>>)
       when byte_size(payload) >= @tag_size do
    ciphertext_size = byte_size(payload) - @tag_size
    <<ciphertext::binary-size(ciphertext_size), tag::binary-size(@tag_size)>> = payload
    {:ok, nonce, ciphertext, tag}
  end

  defp split_payload(_body), do: {:error, :encrypted_data_too_short}

  defp open(key, nonce, ciphertext, tag, associated_data) do
    case :crypto.crypto_one_time_aead(
           :aes_256_gcm,
           key,
           nonce,
           ciphertext,
           associated_data,
           tag,
           false
         ) do
      plaintext when is_binary(plaintext) -> {:ok, plaintext}
      :error -> {:error, :decryption_failed}
    end
  end

  defp extract_encrypted_keys(encrypted_data) do
    with {:ok, raw} <- decode_base64(encrypted_data, :invalid_base64),
         {:ok, keys_length, rest} <- decode_leb128(raw) do
      case rest do
        <<encrypted_keys::binary-size(keys_length), _body::binary>> ->
          {:ok, Base.encode64(encrypted_keys)}

        _too_short ->
          {:error, :encrypted_data_too_short}
      end
    end
  end

  defp skip_encrypted_keys(rest, keys_length) do
    case rest do
      <<_keys::binary-size(keys_length), body::binary>> -> {:ok, body}
      _too_short -> {:error, :encrypted_data_too_short}
    end
  end

  defp decode_key(encoded) do
    case Base.decode64(to_string(encoded)) do
      {:ok, <<key::binary-size(32)>>} -> {:ok, key}
      _ -> {:error, :invalid_data_key}
    end
  end

  defp decode_base64(encoded, error) do
    case Base.decode64(to_string(encoded)) do
      {:ok, decoded} -> {:ok, decoded}
      :error -> {:error, error}
    end
  end

  # Unsigned LEB128, used to frame the encrypted-keys blob.
  defp encode_leb128(0), do: <<0>>

  defp encode_leb128(n) when n > 0 do
    rest = Bitwise.bsr(n, 7)
    byte = Bitwise.band(n, 0x7F)

    if rest > 0 do
      <<Bitwise.bor(byte, 0x80)>> <> encode_leb128(rest)
    else
      <<byte>>
    end
  end

  defp decode_leb128(binary), do: decode_leb128(binary, 0, 0)

  defp decode_leb128(_binary, shift, _acc) when shift >= 35, do: {:error, :leb128_overflow}
  defp decode_leb128(<<>>, _shift, _acc), do: {:error, :leb128_truncated}

  defp decode_leb128(<<byte, rest::binary>>, shift, acc) do
    acc = Bitwise.bor(acc, Bitwise.bsl(Bitwise.band(byte, 0x7F), shift))

    if Bitwise.band(byte, 0x80) == 0 do
      {:ok, acc, rest}
    else
      decode_leb128(rest, shift + 7, acc)
    end
  end
end
