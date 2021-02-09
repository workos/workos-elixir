defmodule WorkOS.SSOTest do
  use ExUnit.Case
  doctest WorkOS.SSO
  alias WorkOS.SSO

  def parse_uri(url) do
    uri = URI.parse(url)
    %URI{uri | query: URI.query_decoder(uri.query) |> Enum.to_list()}
  end

  describe "#get_authorization_url/2 with a custom client_id" do
    setup do
      {:ok, url} = SSO.get_authorization_url(%{domain: "test", provider: "provider", redirect_uri: "project", state: "nope"}, client_id: "8vf9xg")
      {:ok, url: URI.parse(url)}
    end

    test "returns the expected query string", %{url: %URI{query: query}} do
      params = URI.query_decoder(query) |> Enum.to_list()
      assert {"client_id", "8vf9xg"} in params
    end
  end

  describe "#get_authorization_url/2 with a domain" do
    setup do
      {:ok, url} = SSO.get_authorization_url(%{domain: "test", provider: "provider", redirect_uri: "project", state: "nope"})
      {:ok, url: URI.parse(url)}
    end

    test "returns a valid URL", %{url: url} do
      assert %URI{} = url
    end

    test "returns the expected hostname", %{url: url} do
      assert url.host == WorkOS.host
    end

    test "returns the expected query string", %{url: %URI{query: query}} do
      params = URI.query_decoder(query) |> Enum.to_list()
      assert {"domain", "test"} in params
    end
  end

  describe "#get_authorization_url/2 with a provider" do
    setup do
      {:ok, url} = SSO.get_authorization_url(%{domain: "test", provider: "provider", redirect_uri: "project", state: "nope"})
      {:ok, url: URI.parse(url)}
    end

    test "returns a valid URL", %{url: url} do
      assert %URI{} = url
    end

    test "returns the expected hostname", %{url: url} do
      assert url.host == WorkOS.host
    end

    test "returns the expected query string", %{url: %URI{query: query}} do
      params = URI.query_decoder(query) |> Enum.to_list()
      assert {"domain", "test"} in params
    end
  end

  describe "#get_authorization_url/2 with neither domain nor provider" do
    test "returns an error" do
      assert_raise ArgumentError, fn ->
        {:ok, url:  SSO.get_authorization_url(%{redirect_uri: "project", state: "nope"})}
      end
    end
  end
end
