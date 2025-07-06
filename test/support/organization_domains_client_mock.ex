defmodule WorkOS.OrganizationDomains.ClientMock do
  @moduledoc false

  import ExUnit.Assertions, only: [assert: 1]

  @organization_domain_mock %{
    "object" => "organization_domain",
    "id" => "org_domain_01HCZRAP3TPQ0X0DKJHR32TATG",
    "domain" => "workos.com",
    "state" => "verified",
    "verification_token" => nil,
    "verification_strategy" => "manual"
  }

  def get_organization_domain(context, opts \\ []) do
    Tesla.Mock.mock(fn request ->
      %{api_key: api_key} = context

      organization_domain_id =
        opts |> Keyword.get(:assert_fields) |> Keyword.get(:organization_domain_id)

      assert request.method == :get
      assert request.url == "#{WorkOS.base_url()}/organization_domains/#{organization_domain_id}"

      assert Enum.find(request.headers, &(elem(&1, 0) == "Authorization")) ==
               {"Authorization", "Bearer #{api_key}"}

      success_body = @organization_domain_mock

      case Keyword.get(opts, :respond_with, {200, success_body}) do
        {:error, reason} -> {:error, reason}
        {status, body} -> %Tesla.Env{status: status, body: body}
      end
    end)
  end

  def create_organization_domain(context, opts \\ []) do
    Tesla.Mock.mock(fn request ->
      %{api_key: api_key} = context

      assert request.method == :post
      assert request.url == "#{WorkOS.base_url()}/organization_domains"

      assert Enum.find(request.headers, &(elem(&1, 0) == "Authorization")) ==
               {"Authorization", "Bearer #{api_key}"}

      body = Jason.decode!(request.body)

      for {field, value} <-
            Keyword.get(opts, :assert_fields, []) do
        assert body[to_string(field)] == value
      end

      success_body = @organization_domain_mock

      case Keyword.get(opts, :respond_with, {200, success_body}) do
        {:error, reason} -> {:error, reason}
        {status, body} -> %Tesla.Env{status: status, body: body}
      end
    end)
  end

  def verify_organization_domain(context, opts \\ []) do
    Tesla.Mock.mock(fn request ->
      %{api_key: api_key} = context

      organization_domain_id =
        opts |> Keyword.get(:assert_fields) |> Keyword.get(:organization_domain_id)

      assert request.method == :post

      assert request.url ==
               "#{WorkOS.base_url()}/organization_domains/#{organization_domain_id}/verify"

      assert Enum.find(request.headers, &(elem(&1, 0) == "Authorization")) ==
               {"Authorization", "Bearer #{api_key}"}

      success_body = @organization_domain_mock

      case Keyword.get(opts, :respond_with, {200, success_body}) do
        {:error, reason} -> {:error, reason}
        {status, body} -> %Tesla.Env{status: status, body: body}
      end
    end)
  end
end
