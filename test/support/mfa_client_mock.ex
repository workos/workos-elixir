defmodule WorkOS.MFA.ClientMock do
  @moduledoc false

  import ExUnit.Assertions, only: [assert: 1]

  @authentication_challenge_mock %{
    "object" => "authentication_challenge",
    "id" => "auth_challenge_1234",
    "created_at" => "2022-03-15T20:39:19.892Z",
    "updated_at" => "2022-03-15T20:39:19.892Z",
    "expires_at" => "2022-03-15T21:39:19.892Z",
    "code" => "12345",
    "authentication_factor_id" => "auth_factor_1234"
  }

  @authentication_factor_mock %{
    "object" => "authentication_factor",
    "id" => "auth_factor_1234",
    "created_at" => "2022-03-15T20:39:19.892Z",
    "updated_at" => "2022-03-15T20:39:19.892Z",
    "type" => "totp",
    "totp" => %{
      "issuer" => "WorkOS",
      "user" => "some_user"
    }
  }

  def enroll_factor(context, opts \\ []) do
    Tesla.Mock.mock(fn request ->
      %{api_key: api_key} = context

      assert request.method == :post

      assert request.url ==
               "#{WorkOS.base_url()}/auth/factors/enroll"

      assert Enum.find(request.headers, &(elem(&1, 0) == "Authorization")) ==
               {"Authorization", "Bearer #{api_key}"}

      body = Jason.decode!(request.body)

      for {field, value} <- Keyword.get(opts, :assert_fields, []) do
        assert body[to_string(field)] == value
      end

      success_body = @authentication_factor_mock

      {status, body} = Keyword.get(opts, :respond_with, {200, success_body})
      %Tesla.Env{status: status, body: body}
    end)
  end

  def challenge_factor(context, opts \\ []) do
    Tesla.Mock.mock(fn request ->
      %{api_key: api_key} = context

      authentication_factor_id =
        opts |> Keyword.get(:assert_fields) |> Keyword.get(:authentication_factor_id)

      assert request.method == :post

      assert request.url ==
               "#{WorkOS.base_url()}/auth/factors/#{authentication_factor_id}/challenge"

      assert Enum.find(request.headers, &(elem(&1, 0) == "Authorization")) ==
               {"Authorization", "Bearer #{api_key}"}

      body = Jason.decode!(request.body)

      for {field, value} <-
            Keyword.get(opts, :assert_fields, []) |> Keyword.delete(:authentication_factor_id) do
        assert body[to_string(field)] == value
      end

      success_body = @authentication_challenge_mock

      {status, body} = Keyword.get(opts, :respond_with, {200, success_body})
      %Tesla.Env{status: status, body: body}
    end)
  end

  def verify_challenge(context, opts \\ []) do
    Tesla.Mock.mock(fn request ->
      %{api_key: api_key} = context

      authentication_challenge_id =
        opts |> Keyword.get(:assert_fields) |> Keyword.get(:authentication_challenge_id)

      assert request.method == :post

      assert request.url ==
               "#{WorkOS.base_url()}/auth/challenges/#{authentication_challenge_id}/verify"

      assert Enum.find(request.headers, &(elem(&1, 0) == "Authorization")) ==
               {"Authorization", "Bearer #{api_key}"}

      body = Jason.decode!(request.body)

      for {field, value} <-
            Keyword.get(opts, :assert_fields, []) |> Keyword.delete(:authentication_challenge_id) do
        assert body[to_string(field)] == value
      end

      success_body = %{
        "challenge" => @authentication_challenge_mock,
        "valid" => true
      }

      {status, body} = Keyword.get(opts, :respond_with, {200, success_body})
      %Tesla.Env{status: status, body: body}
    end)
  end

  def get_factor(context, opts \\ []) do
    Tesla.Mock.mock(fn request ->
      %{api_key: api_key} = context

      authentication_factor_id =
        opts |> Keyword.get(:assert_fields) |> Keyword.get(:authentication_factor_id)

      assert request.method == :get
      assert request.url == "#{WorkOS.base_url()}/auth/factors/#{authentication_factor_id}"

      assert Enum.find(request.headers, &(elem(&1, 0) == "Authorization")) ==
               {"Authorization", "Bearer #{api_key}"}

      success_body = @authentication_factor_mock

      {status, body} = Keyword.get(opts, :respond_with, {200, success_body})
      %Tesla.Env{status: status, body: body}
    end)
  end

  def delete_factor(context, opts \\ []) do
    Tesla.Mock.mock(fn request ->
      %{api_key: api_key} = context

      authentication_factor_id =
        opts |> Keyword.get(:assert_fields) |> Keyword.get(:authentication_factor_id)

      assert request.method == :delete
      assert request.url == "#{WorkOS.base_url()}/auth/factors/#{authentication_factor_id}"

      assert Enum.find(request.headers, &(elem(&1, 0) == "Authorization")) ==
               {"Authorization", "Bearer #{api_key}"}

      {status, body} = Keyword.get(opts, :respond_with, {204, %{}})
      %Tesla.Env{status: status, body: body}
    end)
  end
end
