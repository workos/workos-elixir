defmodule WorkOS.Organizations.ClientMock do
  @moduledoc false

  import ExUnit.Assertions, only: [assert: 1]

  def list_organizations(context, opts \\ []) do
    Tesla.Mock.mock(fn request ->
      %{api_key: api_key} = context

      assert request.method == :get
      assert request.url == "#{WorkOS.base_url()}/organizations"

      assert Enum.find(request.headers, &(elem(&1, 0) == "Authorization")) ==
               {"Authorization", "Bearer #{api_key}"}

      success_body = %{
        "data" => [
          %{
            "id" => "org_01EHT88Z8J8795GZNQ4ZP1J81T",
            "object" => "organization",
            "name" => "Test Organization 1",
            "allow_profiles_outside_organization" => false,
            "domains" => [
              %{
                "domain" => "example.com",
                "object" => "organization_domain",
                "id" => "org_domain_01EHT88Z8WZEFWYPM6EC9BX2R8"
              }
            ],
            "created_at" => "2023-07-17T20:07:20.055Z",
            "updated_at" => "2023-07-17T20:07:20.055Z"
          },
          %{
            "id" => "org_01EGPJWMT2EQMK7FMPR3TBC861",
            "object" => "organization",
            "name" => "Test Organization 2",
            "allow_profiles_outside_organization" => true,
            "domains" => [
              %{
                "domain" => "workos.com",
                "object" => "organization_domain",
                "id" => "org_domain_01EGPJWMTHRB5FP6MKE14RZ9BQ"
              }
            ],
            "created_at" => "2023-07-17T20:07:20.055Z",
            "updated_at" => "2023-07-17T20:07:20.055Z"
          }
        ],
        "list_metadata" => %{
          "before" => "before-id",
          "after" => "after-id"
        }
      }

      {status, body} = Keyword.get(opts, :respond_with, {200, success_body})
      %Tesla.Env{status: status, body: body}
    end)
  end

  def delete_organization(context, opts \\ []) do
    Tesla.Mock.mock(fn request ->
      %{api_key: api_key} = context

      organization_id = opts |> Keyword.get(:assert_fields) |> Keyword.get(:organization_id)
      assert request.method == :delete
      assert request.url == "#{WorkOS.base_url()}/organizations/#{organization_id}"

      assert Enum.find(request.headers, &(elem(&1, 0) == "Authorization")) ==
               {"Authorization", "Bearer #{api_key}"}

      {status, body} = Keyword.get(opts, :respond_with, {204, %{}})
      %Tesla.Env{status: status, body: body}
    end)
  end

  def get_organization(context, opts \\ []) do
    Tesla.Mock.mock(fn request ->
      %{api_key: api_key} = context

      organization_id = opts |> Keyword.get(:assert_fields) |> Keyword.get(:organization_id)
      assert request.method == :get
      assert request.url == "#{WorkOS.base_url()}/organizations/#{organization_id}"

      assert Enum.find(request.headers, &(elem(&1, 0) == "Authorization")) ==
               {"Authorization", "Bearer #{api_key}"}

      success_body = %{
        "id" => "org_01EHT88Z8J8795GZNQ4ZP1J81T",
        "object" => "organization",
        "name" => "Test Organization",
        "allow_profiles_outside_organization" => false,
        "domains" => [
          %{
            "domain" => "example.com",
            "object" => "organization_domain",
            "id" => "org_domain_01EHT88Z8WZEFWYPM6EC9BX2R8"
          }
        ],
        "created_at" => "2023-07-17T20:07:20.055Z",
        "updated_at" => "2023-07-17T20:07:20.055Z"
      }

      {status, body} = Keyword.get(opts, :respond_with, {200, success_body})
      %Tesla.Env{status: status, body: body}
    end)
  end

  def get_organization_by_external_id(context, opts \\ []) do
    Tesla.Mock.mock(fn request ->
      %{api_key: api_key} = context

      external_id = opts |> Keyword.get(:assert_fields) |> Keyword.get(:external_id)
      assert request.method == :get
      assert request.url == "#{WorkOS.base_url()}/organizations/external_id/#{external_id}"

      assert Enum.find(request.headers, &(elem(&1, 0) == "Authorization")) ==
               {"Authorization", "Bearer #{api_key}"}

      success_body = %{
        "id" => "org_01EHT88Z8J8795GZNQ4ZP1J81T",
        "object" => "organization",
        "name" => "Test Organization",
        "allow_profiles_outside_organization" => false,
        "external_id" => external_id,
        "domains" => [
          %{
            "domain" => "example.com",
            "object" => "organization_domain",
            "id" => "org_domain_01EHT88Z8WZEFWYPM6EC9BX2R8"
          }
        ],
        "created_at" => "2023-07-17T20:07:20.055Z",
        "updated_at" => "2023-07-17T20:07:20.055Z"
      }

      {status, body} = Keyword.get(opts, :respond_with, {200, success_body})
      %Tesla.Env{status: status, body: body}
    end)
  end

  def create_organization(context, opts \\ []) do
    Tesla.Mock.mock(fn request ->
      %{api_key: api_key} = context

      assert request.method == :post
      assert request.url == "#{WorkOS.base_url()}/organizations"

      assert Enum.find(request.headers, &(elem(&1, 0) == "Authorization")) ==
               {"Authorization", "Bearer #{api_key}"}

      assert Enum.find(request.headers, fn {header, _} -> header == "Idempotency-Key" end) != nil

      body = Jason.decode!(request.body)

      for {field, value} <-
            Keyword.get(opts, :assert_fields, []) |> Keyword.delete(:idempotency_key) do
        assert body[to_string(field)] == value
      end

      success_body = %{
        "id" => "org_01EHT88Z8J8795GZNQ4ZP1J81T",
        "object" => "organization",
        "name" => body[:name],
        "allow_profiles_outside_organization" => false,
        "domains" => [
          %{
            "domain" => "example.com",
            "object" => "organization_domain",
            "id" => "org_domain_01EHT88Z8WZEFWYPM6EC9BX2R8"
          }
        ],
        "created_at" => "2023-07-17T20:07:20.055Z",
        "updated_at" => "2023-07-17T20:07:20.055Z"
      }

      {status, body} = Keyword.get(opts, :respond_with, {200, success_body})
      %Tesla.Env{status: status, body: body}
    end)
  end

  def update_organization(context, opts \\ []) do
    Tesla.Mock.mock(fn request ->
      %{api_key: api_key} = context

      organization_id = opts |> Keyword.get(:assert_fields) |> Keyword.get(:organization_id)
      assert request.method == :put
      assert request.url == "#{WorkOS.base_url()}/organizations/#{organization_id}"

      assert Enum.find(request.headers, &(elem(&1, 0) == "Authorization")) ==
               {"Authorization", "Bearer #{api_key}"}

      body = Jason.decode!(request.body)

      for {field, value} <-
            Keyword.get(opts, :assert_fields, []) |> Keyword.delete(:organization_id) do
        assert body[to_string(field)] == value
      end

      success_body = %{
        "id" => "org_01EHT88Z8J8795GZNQ4ZP1J81T",
        "object" => "organization",
        "name" => body[:name],
        "allow_profiles_outside_organization" => false,
        "domains" => [
          %{
            "domain" => "example.com",
            "object" => "organization_domain",
            "id" => "org_domain_01EHT88Z8WZEFWYPM6EC9BX2R8"
          }
        ],
        "created_at" => "2023-07-17T20:07:20.055Z",
        "updated_at" => "2023-07-17T20:07:20.055Z"
      }

      {status, body} = Keyword.get(opts, :respond_with, {200, success_body})
      %Tesla.Env{status: status, body: body}
    end)
  end
end
