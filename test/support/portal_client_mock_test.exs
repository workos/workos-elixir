defmodule WorkOS.Portal.ClientMockTest do
  use ExUnit.Case, async: true

  alias WorkOS.Portal.ClientMock

  setup do
    %{context: %{api_key: "test_api_key"}}
  end

  test "generate_link/2 returns mocked response with default options", %{context: context} do
    response = ClientMock.generate_link(context)
    assert is_function(response)
    # Actually invoke the Tesla.Mock.mocked function to simulate a request
    request = %Tesla.Env{
      method: :post,
      url: "https://api.workos.com/portal/generate_link",
      headers: [{"Authorization", "Bearer test_api_key"}],
      body: Jason.encode!(%{})
    }

    env = response.(request)
    assert env.status == 200
    assert env.body["link"] =~ "https://id.workos.com/portal/launch"
  end

  test "generate_link/2 asserts fields and responds with custom status", %{context: context} do
    opts = [
      assert_fields: [foo: "bar"],
      respond_with: {201, %{"link" => "custom"}}
    ]

    response = ClientMock.generate_link(context, opts)
    assert is_function(response)

    request = %Tesla.Env{
      method: :post,
      url: "https://api.workos.com/portal/generate_link",
      headers: [{"Authorization", "Bearer test_api_key"}],
      body: Jason.encode!(%{"foo" => "bar"})
    }

    env = response.(request)
    assert env.status == 201
    assert env.body["link"] == "custom"
  end
end
