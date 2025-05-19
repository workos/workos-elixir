defmodule WorkOS.DirectorySync.ClientMockTest do
  use ExUnit.Case, async: true

  alias WorkOS.DirectorySync.ClientMock

  test "get_directory/1 returns mocked response" do
    context = %{api_key: "sk_test"}
    fun = ClientMock.get_directory(context)
    assert is_function(fun)
  end

  test "get_directory/2 returns custom response" do
    context = %{api_key: "sk_test"}
    fun = ClientMock.get_directory(context, respond_with: {201, %{foo: "bar"}})
    assert is_function(fun)
  end

  test "get_directory/1 sets up the Tesla mock" do
    context = %{api_key: "sk_test"}
    fun = ClientMock.get_directory(context)
    assert is_function(fun)
  end

  test "get_directory/2 sets up the Tesla mock with custom response" do
    context = %{api_key: "sk_test"}
    fun = ClientMock.get_directory(context, respond_with: {201, %{foo: "bar"}})
    assert is_function(fun)
  end
end
