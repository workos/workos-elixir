defmodule WorkOS.AuditLogsTest do
  use WorkOS.TestCase

  alias WorkOS.AuditLogs.ClientMock

  setup :setup_env

  @event_mock %{
    "action" => "document.updated",
    "occurred_at" => "2022-09-08T19:46:03.435Z",
    "actor" => %{
      "id" => "user_1",
      "name" => "Jon Smith",
      "type" => "user"
    },
    "targets" => [
      %{
        "id" => "document_39127",
        "type" => "document"
      }
    ],
    "context" => %{
      "location" => "192.0.0.8",
      "user_agent" => "Firefox"
    },
    "metadata" => %{
      "successful" => true
    }
  }

  describe "create_event" do
    test "with an idempotency key, includes an idempotency key with request", context do
      opts = [
        organization_id: "org_123",
        event: @event_mock,
        idempotency_key: "the-idempotency-key"
      ]

      context |> ClientMock.create_event(assert_fields: opts)

      assert {:ok, %WorkOS.Empty{}} = WorkOS.AuditLogs.create_event(opts |> Enum.into(%{}))
    end

    test "with a valid payload, creates an event", context do
      opts = [
        organization_id: "org_123",
        event: @event_mock
      ]

      context |> ClientMock.create_event(assert_fields: opts)

      assert {:ok, %WorkOS.Empty{}} = WorkOS.AuditLogs.create_event(opts |> Enum.into(%{}))
    end
  end

  describe "create_export" do
    test "with valid payload, creates an audit log export", context do
      opts = [
        organization_id: "org_01EHWNCE74X7JSDV0X3SZ3KJNY",
        range_start: "2022-06-22T15:04:19.704Z",
        range_end: "2022-08-22T15:04:19.704Z",
        actions: ["user.signed_in"],
        actors: ["Jon Smith"],
        targets: ["team"]
      ]

      context
      |> ClientMock.create_export(assert_fields: opts)

      assert {:ok, %WorkOS.AuditLogs.Export{}} =
               opts |> Map.new() |> WorkOS.AuditLogs.create_export()
    end
  end

  describe "get_export" do
    test "requests an audit log export", context do
      opts = [audit_log_export_id: "audit_log_export_1234"]

      context |> ClientMock.get_export(assert_fields: opts)

      assert {:ok, %WorkOS.AuditLogs.Export{id: id}} =
               WorkOS.AuditLogs.get_export(opts |> Keyword.get(:audit_log_export_id))

      refute is_nil(id)
    end
  end
end
