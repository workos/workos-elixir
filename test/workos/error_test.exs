defmodule WorkOS.ErrorTest do
  use ExUnit.Case

  describe "WorkOS.ApiKeyMissingError" do
    test "struct creation and message" do
      error = %WorkOS.ApiKeyMissingError{}
      assert %WorkOS.ApiKeyMissingError{} = error
      assert error.message =~ "api_key setting is required"
    end
  end

  describe "WorkOS.ClientIdMissingError" do
    test "struct creation and message" do
      error = %WorkOS.ClientIdMissingError{}
      assert %WorkOS.ClientIdMissingError{} = error
      assert error.message =~ "client_id setting is required"
    end
  end
end
