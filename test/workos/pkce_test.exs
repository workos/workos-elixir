# @oagen-ignore-file — hand-maintained tests for PKCE utilities.

defmodule WorkOS.PKCETest do
  use ExUnit.Case, async: true

  test "generate_code_verifier defaults to 43 characters" do
    verifier = WorkOS.PKCE.generate_code_verifier()

    assert String.length(verifier) == 43
    assert verifier =~ ~r/^[A-Za-z0-9_-]+$/
  end

  test "generate_code_verifier honors a custom length" do
    assert String.length(WorkOS.PKCE.generate_code_verifier(128)) == 128
    assert String.length(WorkOS.PKCE.generate_code_verifier(64)) == 64
  end

  test "generate_code_verifier rejects out-of-range lengths" do
    assert_raise ArgumentError, fn -> WorkOS.PKCE.generate_code_verifier(42) end
    assert_raise ArgumentError, fn -> WorkOS.PKCE.generate_code_verifier(129) end
  end

  test "generate_code_challenge matches the RFC 7636 appendix B vector" do
    assert WorkOS.PKCE.generate_code_challenge("dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk") ==
             "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM"
  end

  test "generate_pair returns a consistent verifier/challenge pair" do
    pair = WorkOS.PKCE.generate_pair()

    assert pair.code_challenge_method == "S256"
    assert pair.code_challenge == WorkOS.PKCE.generate_code_challenge(pair.code_verifier)
  end

  test "verifiers are unique" do
    verifiers = for _ <- 1..50, do: WorkOS.PKCE.generate_code_verifier()
    assert length(Enum.uniq(verifiers)) == 50
  end
end
