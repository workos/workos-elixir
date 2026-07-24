# @oagen-ignore-file — hand-maintained; not produced from the OpenAPI spec.

defmodule WorkOS.PKCE do
  @moduledoc """
  PKCE (Proof Key for Code Exchange, [RFC 7636](https://datatracker.ietf.org/doc/html/rfc7636))
  utilities for public-client authentication flows.

      pair = WorkOS.PKCE.generate_pair()
      pair.code_verifier
      pair.code_challenge
      pair.code_challenge_method
      #=> "S256"
  """

  @min_length 43
  @max_length 128
  @default_length 43

  @typedoc "A PKCE code verifier/challenge pair. The challenge method is always `\"S256\"`."
  @type pair :: %{
          code_verifier: String.t(),
          code_challenge: String.t(),
          code_challenge_method: String.t()
        }

  @doc """
  Generates a cryptographically random PKCE code verifier.

  `length` must be between #{@min_length} and #{@max_length} characters
  (default #{@default_length}), per RFC 7636.
  """
  @spec generate_code_verifier(pos_integer()) :: String.t()
  def generate_code_verifier(length \\ @default_length)

  def generate_code_verifier(length) when length in @min_length..@max_length do
    # base64url yields 4 characters per 3 bytes; generate enough bytes to
    # cover `length` characters, then trim.
    byte_length = div(length * 3 + 3, 4)

    byte_length
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64(padding: false)
    |> binary_part(0, length)
  end

  def generate_code_verifier(length) do
    raise ArgumentError,
          "PKCE code verifier length must be between #{@min_length} and #{@max_length}, " <>
            "got #{inspect(length)}"
  end

  @doc """
  Computes the S256 code challenge for a code verifier.
  """
  @spec generate_code_challenge(String.t()) :: String.t()
  def generate_code_challenge(code_verifier) when is_binary(code_verifier) do
    :sha256
    |> :crypto.hash(code_verifier)
    |> Base.url_encode64(padding: false)
  end

  @doc """
  Generates a complete PKCE pair (verifier + S256 challenge).
  """
  @spec generate_pair() :: pair()
  def generate_pair do
    code_verifier = generate_code_verifier()

    %{
      code_verifier: code_verifier,
      code_challenge: generate_code_challenge(code_verifier),
      code_challenge_method: "S256"
    }
  end
end
