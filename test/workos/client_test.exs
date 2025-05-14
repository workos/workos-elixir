defmodule WorkOS.ClientTest do
  use ExUnit.Case
  alias WorkOS.Client

  defmodule DummyCastable do
    @behaviour WorkOS.Castable
    def cast(map), do: map
  end

  setup do
    client = Client.new(api_key: "sk_test", client_id: "client_123")
    %{client: client}
  end

  test "struct creation and new/1" do
    client = Client.new(api_key: "sk_test", client_id: "client_123")
    assert %Client{api_key: "sk_test", client_id: "client_123"} = client
  end

  test "default client module is used if not specified" do
    client = Client.new(api_key: "sk_test", client_id: "client_123")
    assert client.client == WorkOS.Client.TeslaClient
  end

  describe "get/4, post/5, put/5, delete/5" do
    setup %{client: client} do
      Tesla.Mock.mock(fn
        %{method: :get, url: "https://api.workos.com/ok"} ->
          %Tesla.Env{status: 200, body: %{foo: "bar"}}

        %{method: :post, url: "https://api.workos.com/ok"} ->
          %Tesla.Env{status: 200, body: %{foo: "bar"}}

        %{method: :put, url: "https://api.workos.com/ok"} ->
          %Tesla.Env{status: 200, body: %{foo: "bar"}}

        %{method: :delete, url: "https://api.workos.com/ok"} ->
          %Tesla.Env{status: 200, body: %{foo: "bar"}}

        %{method: :get, url: "https://api.workos.com/empty"} ->
          %Tesla.Env{status: 200, body: ""}

        %{method: :get, url: "https://api.workos.com/error_map"} ->
          %Tesla.Env{status: 400, body: %{"error" => "bad_request", "message" => "fail"}}

        %{method: :get, url: "https://api.workos.com/error_bin"} ->
          %Tesla.Env{status: 400, body: "fail"}

        %{method: :get, url: "https://api.workos.com/client_error"} ->
          {:error, :nxdomain}

        _ ->
          %Tesla.Env{status: 404, body: %{}}
      end)

      :ok
    end

    test "get/4 returns ok tuple", %{client: client} do
      assert {:ok, %{foo: "bar"}} = Client.get(client, DummyCastable, "/ok")
    end

    test "post/5 returns ok tuple", %{client: client} do
      assert {:ok, %{foo: "bar"}} = Client.post(client, DummyCastable, "/ok", %{})
    end

    test "put/5 returns ok tuple", %{client: client} do
      assert {:ok, %{foo: "bar"}} = Client.put(client, DummyCastable, "/ok", %{})
    end

    test "delete/5 returns ok tuple", %{client: client} do
      assert {:ok, %{foo: "bar"}} = Client.delete(client, DummyCastable, "/ok", %{})
    end

    test "get/4 returns ok tuple for empty body", %{client: client} do
      assert {:error, ""} = Client.get(client, DummyCastable, "/empty")
    end

    test "get/4 returns error tuple for error map", %{client: client} do
      assert {:error, %WorkOS.Error{error: "bad_request", message: "fail"}} =
               Client.get(client, DummyCastable, "/error_map")
    end

    test "get/4 returns error tuple for error binary", %{client: client} do
      assert {:error, "fail"} = Client.get(client, DummyCastable, "/error_bin")
    end

    test "get/4 returns error tuple for client error", %{client: client} do
      assert {:error, :client_error} = Client.get(client, DummyCastable, "/client_error")
    end
  end
end
