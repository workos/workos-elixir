# @oagen-ignore-file — hand-maintained tests for the public-client preset.

defmodule WorkOS.PublicClientTest do
  use ExUnit.Case, async: true

  test "new builds a client without an API key" do
    public = WorkOS.PublicClient.new("client_123")

    assert %WorkOS.PublicClient{client: %WorkOS.Client{api_key: "", client_id: "client_123"}} =
             public
  end

  test "new requires a client_id" do
    assert_raise WorkOS.ConfigurationError, fn -> WorkOS.PublicClient.new("") end
  end

  test "new honors a custom base URL" do
    public = WorkOS.PublicClient.new("client_123", base_url: "https://api.example.test/")

    result = WorkOS.PublicClient.get_authorization_url(public, %{redirect_uri: "https://cb"})
    assert String.starts_with?(result.url, "https://api.example.test/user_management/authorize")
  end

  test "get_authorization_url returns an AuthKit PKCE URL" do
    public = WorkOS.PublicClient.new("client_123")

    assert %{url: url, code_verifier: verifier, state: state} =
             WorkOS.PublicClient.get_authorization_url(public, %{
               redirect_uri: "https://example.com/cb"
             })

    query = url |> URI.parse() |> Map.fetch!(:query) |> URI.decode_query()
    assert query["client_id"] == "client_123"
    assert query["code_challenge"] == WorkOS.PKCE.generate_code_challenge(verifier)
    assert query["state"] == state
  end

  test "get_sso_authorization_url returns an SSO PKCE URL" do
    public = WorkOS.PublicClient.new("client_123")

    assert %{url: url, code_verifier: verifier} =
             WorkOS.PublicClient.get_sso_authorization_url(public, %{
               redirect_uri: "https://example.com/cb"
             })

    assert url =~ "/sso/authorize"

    query = url |> URI.parse() |> Map.fetch!(:query) |> URI.decode_query()
    assert query["code_challenge"] == WorkOS.PKCE.generate_code_challenge(verifier)
  end
end
