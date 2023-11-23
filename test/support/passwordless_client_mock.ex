defmodule WorkOS.Passwordless.ClientMock do
  @moduledoc false

  use ExUnit.Case

  def create_session(context, opts \\ []) do
    Tesla.Mock.mock(fn request ->
      %{api_key: api_key} = context

      assert request.method == :post
      assert request.url == "#{WorkOS.base_url()}/passwordless/sessions"

      assert Enum.find(request.headers, &(elem(&1, 0) == "Authorization")) ==
               {"Authorization", "Bearer #{api_key}"}

      body = Jason.decode!(request.body)

      for {field, value} <-
            Keyword.get(opts, :assert_fields, []) do
        assert body[to_string(field)] == value
      end

      success_body = %{
        "id" => "passwordless_session_01EHDAK2BFGWCSZXP9HGZ3VK8C",
        "email" => "passwordless_session_email@workos.com",
        "expires_at" => "2020-08-13T05:50:00.000Z",
        "link" => "https://auth.workos.com/passwordless/token/confirm",
        "object" => "passwordless_session"
      }

      {status, body} = Keyword.get(opts, :respond_with, {200, success_body})
      %Tesla.Env{status: status, body: body}
    end)
  end

  def send_session(context, opts \\ []) do
    Tesla.Mock.mock(fn request ->
      %{api_key: api_key} = context

      session_id = opts |> Keyword.get(:assert_fields) |> Keyword.get(:session_id)
      assert request.method == :post
      assert request.url == "#{WorkOS.base_url()}/passwordless/sessions/#{session_id}"

      assert Enum.find(request.headers, &(elem(&1, 0) == "Authorization")) ==
               {"Authorization", "Bearer #{api_key}"}

      body = Jason.decode!(request.body)

      for {field, value} <-
            Keyword.get(opts, :assert_fields, []) |> Keyword.delete(:session_id) do
        assert body[to_string(field)] == value
      end

      success_body = %{
        "success" => true
      }

      {status, body} = Keyword.get(opts, :respond_with, {200, success_body})
      %Tesla.Env{status: status, body: body}
    end)
  end
end
