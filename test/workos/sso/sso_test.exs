defmodule WorkOS.SSOTest do
  use ExUnit.Case
  doctest WorkOS.SSO
  alias WorkOS.SSO
  import Tesla.Mock


  def parse_uri(url) do
    uri = URI.parse(url)
    %URI{uri | query: URI.query_decoder(uri.query) |> Enum.to_list()}
  end

  describe "#get_authorization_url/2 with a custom client_id" do
    setup do
      {:ok, url} =
        SSO.get_authorization_url(
          %{domain: "test", provider: "GoogleOAuth", redirect_uri: "project", state: "nope"},
          client_id: "8vf9xg"
        )

      {:ok, url: URI.parse(url)}
    end

    test "returns the expected query string", %{url: %URI{query: query}} do
      params = URI.query_decoder(query) |> Enum.to_list()
      assert {"client_id", "8vf9xg"} in params
    end
  end

  describe "#get_authorization_url/2 with a domain" do
    setup do
      {:ok, url} =
        SSO.get_authorization_url(%{
          domain: "test",
          provider: "GoogleOAuth",
          redirect_uri: "project",
          state: "nope"
        })

      {:ok, url: URI.parse(url)}
    end

    test "returns a valid URL", %{url: url} do
      assert %URI{} = url
    end

    test "returns the expected hostname", %{url: url} do
      assert url.host == WorkOS.host()
    end

    test "returns the expected query string", %{url: %URI{query: query}} do
      params = URI.query_decoder(query) |> Enum.to_list()
      assert {"domain", "test"} in params
    end
  end

  describe "#get_authorization_url/2 with a provider" do
    setup do
      {:ok, url} =
        SSO.get_authorization_url(%{
          domain: "test",
          provider: "GoogleOAuth",
          redirect_uri: "project",
          state: "nope"
        })

      {:ok, url: URI.parse(url)}
    end

    test "returns a valid URL", %{url: url} do
      assert %URI{} = url
    end

    test "returns the expected hostname", %{url: url} do
      assert url.host == WorkOS.host()
    end

    test "returns the expected query string", %{url: %URI{query: query}} do
      params = URI.query_decoder(query) |> Enum.to_list()
      assert {"domain", "test"} in params
    end
  end

  describe "#get_authorization_url/2 with a connection" do
    setup do
      {:ok, url} =
        SSO.get_authorization_url(%{
          connection: "connection_123",
          redirect_uri: "project",
          state: "nope"
        })

      {:ok, url: URI.parse(url)}
    end

    test "returns a valid URL", %{url: url} do
      assert %URI{} = url
    end

    test "returns the expected hostname", %{url: url} do
      assert url.host == WorkOS.host()
    end

    test "returns the expected query string", %{url: %URI{query: query}} do
      params = URI.query_decoder(query) |> Enum.to_list()
      assert {"connection", "connection_123"} in params
    end
  end

  describe "#get_authorization_url/2 with neither connection, domain, nor provider" do
    test "returns an error" do
      assert_raise ArgumentError, fn ->
        {:ok, url: SSO.get_authorization_url(%{redirect_uri: "project", state: "nope"})}
      end
    end
  end

  describe "#list_connections/1" do
    setup do
      mock(fn
        %{method: :get, url: "https://api.workos.com/connections"} ->
          %Tesla.Env{status: 200, body: "Success"}
      end)

      :ok
    end

    test "returns a 200 status" do
      assert {:ok, "Success"} = SSO.list_connections
    end
  end

  describe "#get_connection/2 with an valid id" do
    setup do
      mock(fn
        %{method: :get, url: "https://api.workos.com/connections/conn_12345"} ->
          %Tesla.Env{status: 200, body: "Success"}
      end)

      :ok
    end

    test "returns a 200 status" do
      assert {:ok, "Success"} = SSO.get_connection('conn_12345')
    end
  end

  describe "#delete_connection/1 with a valid id" do
    setup do
      mock(fn
        %{method: :delete, url: "https://api.workos.com/connections/conn_12345"} ->
          %Tesla.Env{status: 200, body: "Success"}
      end)

      :ok
    end

    test "returns a 200 status" do
      assert {:ok, "Success"} = SSO.delete_connection('conn_12345')
    end
  end

  describe "#delete_connection/1 with an invalid id" do
    setup do
      mock(fn
        %{method: :delete, url: "https://api.workos.com/connections/invalid"} ->
          %Tesla.Env{status: 404, body: "Not Found"}
      end)

      :ok
    end

    test "returns a 404 status" do
      assert {:error, "Not Found"} = SSO.delete_connection('invalid')
    end
  end
end
