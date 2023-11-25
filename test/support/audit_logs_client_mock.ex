defmodule WorkOS.AuditLogs.ClientMock do
  @moduledoc false

  use ExUnit.Case

  def create_event(context, opts \\ []) do
    Tesla.Mock.mock(fn request ->
      %{api_key: api_key} = context

      assert request.method == :post
      assert request.url == "#{WorkOS.base_url()}/audit_logs/events"

      assert Enum.find(request.headers, &(elem(&1, 0) == "Authorization")) ==
               {"Authorization", "Bearer #{api_key}"}

      assert Enum.find(request.headers, fn {header, _} -> header == "Idempotency-Key" end) != nil

      body = Jason.decode!(request.body)

      for {field, value} <-
            Keyword.get(opts, :assert_fields, []) |> Keyword.delete(:idempotency_key) do
        assert body[to_string(field)] == value
      end

      {status, body} = Keyword.get(opts, :respond_with, {200, %{}})
      %Tesla.Env{status: status, body: body}
    end)
  end

  def create_export(context, opts \\ []) do
    Tesla.Mock.mock(fn request ->
      %{api_key: api_key} = context

      assert request.method == :post
      assert request.url == "#{WorkOS.base_url()}/audit_logs/exports"

      assert Enum.find(request.headers, &(elem(&1, 0) == "Authorization")) ==
               {"Authorization", "Bearer #{api_key}"}

      body = Jason.decode!(request.body)

      for {field, value} <- Keyword.get(opts, :assert_fields, []) do
        assert body[to_string(field)] == value
      end

      success_body = %{
        "object" => "audit_log_export",
        "id" => "audit_log_export_1234",
        "state" => "pending",
        "url" => nil,
        "created_at" => "2022-02-15T15:26:53.274Z",
        "updated_at" => "2022-02-15T15:26:53.274Z"
      }

      {status, body} = Keyword.get(opts, :respond_with, {200, success_body})
      %Tesla.Env{status: status, body: body}
    end)
  end

  def get_export(context, opts \\ []) do
    Tesla.Mock.mock(fn request ->
      %{api_key: api_key} = context

      audit_log_export_id =
        opts |> Keyword.get(:assert_fields) |> Keyword.get(:audit_log_export_id)

      assert request.method == :get
      assert request.url == "#{WorkOS.base_url()}/audit_logs/exports/#{audit_log_export_id}"

      assert Enum.find(request.headers, &(elem(&1, 0) == "Authorization")) ==
               {"Authorization", "Bearer #{api_key}"}

      success_body = %{
        "id" => audit_log_export_id,
        "object" => "audit_logo_export",
        "state" => "pending",
        "url" => nil,
        "created_at" => "2023-07-17T20:07:20.055Z",
        "updated_at" => "2023-07-17T20:07:20.055Z"
      }

      {status, body} = Keyword.get(opts, :respond_with, {200, success_body})
      %Tesla.Env{status: status, body: body}
    end)
  end
end
