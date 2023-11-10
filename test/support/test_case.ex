defmodule WorkOS.TestCase do
  @moduledoc false

  defmacro __using__(_opts) do
    quote do
      use ExUnit.Case
      import WorkOS.TestCase
    end
  end

  def setup_env(_context) do
    %{
      api_key: System.get_env("WORKOS_API_KEY", "sk_12345"),
      client_id: System.get_env("WORKOS_CLIENT_ID", "project_12345")
    }
  end
end
