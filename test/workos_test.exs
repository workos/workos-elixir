defmodule WorkOSTest do
  use ExUnit.Case

  alias WorkOS.Client

  setup do
    prev_config = Application.get_env(:workos, WorkOS.Client)

    config = [
      api_key: "sk_test",
      client_id: "client_123",
      base_url: "https://custom.workos.com",
      client: WorkOS.Client.TeslaClient
    ]

    Application.put_env(:workos, WorkOS.Client, config)

    on_exit(fn ->
      if prev_config == nil do
        Application.delete_env(:workos, WorkOS.Client)
      else
        Application.put_env(:workos, WorkOS.Client, prev_config)
      end
    end)

    %{config: config, prev_config: prev_config}
  end

  describe "client/0 and client/1" do
    test "returns a client struct from config" do
      client = WorkOS.client()
      assert %Client{api_key: "sk_test", client_id: "client_123"} = client
    end

    test "returns a client struct from explicit config" do
      config = [api_key: "sk_test2", client_id: "client_456"]
      client = WorkOS.client(config)
      assert %Client{api_key: "sk_test2", client_id: "client_456"} = client
    end
  end

  describe "config/0" do
    test "loads config from application env", %{config: config} do
      assert WorkOS.config() == config
    end

    test "raises if config is missing" do
      Application.delete_env(:workos, WorkOS.Client)

      assert_raise RuntimeError, ~r/Missing client configuration/, fn ->
        WorkOS.config()
      end
    end

    test "raises if api_key is missing" do
      Application.put_env(:workos, WorkOS.Client, client_id: "client_123")

      assert_raise WorkOS.ApiKeyMissingError, fn ->
        WorkOS.config()
      end
    end

    test "raises if client_id is missing" do
      Application.put_env(:workos, WorkOS.Client, api_key: "sk_test")

      assert_raise WorkOS.ClientIdMissingError, fn ->
        WorkOS.config()
      end
    end
  end

  describe "base_url/0 and default_base_url/0" do
    test "returns custom base_url from config" do
      assert WorkOS.base_url() == "https://custom.workos.com"
    end

    test "returns default base_url if not set" do
      Application.put_env(:workos, WorkOS.Client, api_key: "sk_test", client_id: "client_123")
      assert WorkOS.base_url() == WorkOS.default_base_url()
    end
  end

  describe "client_id/0 and client_id/1" do
    test "returns client_id from config" do
      assert WorkOS.client_id() == "client_123"
    end

    test "returns client_id from client struct" do
      client = %Client{api_key: "sk_test", client_id: "client_123", base_url: nil, client: nil}
      assert WorkOS.client_id(client) == "client_123"
    end

    test "returns nil if client_id not set in config" do
      Application.put_env(:workos, WorkOS.Client, api_key: "sk_test")
      assert WorkOS.client_id() == nil
    end
  end

  describe "api_key/0 and api_key/1" do
    test "returns api_key from config" do
      assert WorkOS.api_key() == "sk_test"
    end

    test "returns api_key from client struct" do
      client = %Client{api_key: "sk_test", client_id: "client_123", base_url: nil, client: nil}
      assert WorkOS.api_key(client) == "sk_test"
    end
  end

  describe "coverage for fallback branches" do
    test "base_url/0 returns default_base_url if config is not a list" do
      Application.put_env(:workos, WorkOS.Client, "not_a_list")
      assert WorkOS.base_url() == WorkOS.default_base_url()
    end

    test "base_url/0 returns default_base_url if config is missing" do
      Application.delete_env(:workos, WorkOS.Client)
      assert WorkOS.base_url() == WorkOS.default_base_url()
    end

    test "client_id/0 returns nil if config is not a list" do
      Application.put_env(:workos, WorkOS.Client, "not_a_list")
      assert WorkOS.client_id() == nil
    end

    test "client_id/0 returns nil if config is missing" do
      Application.delete_env(:workos, WorkOS.Client)
      assert WorkOS.client_id() == nil
    end
  end
end
