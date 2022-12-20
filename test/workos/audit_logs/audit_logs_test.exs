defmodule WorkOS.AuditLogsTest do
  use ExUnit.Case
  doctest WorkOS.AuditLogs
  import Tesla.Mock

  setup do
    mock(fn
      %{method: :post, url: "https://api.workos.com/audit_logs/events"} ->
        %Tesla.Env{status: 201}

      %{method: :post, url: "https://api.workos.com/audit_logs/exports"} ->
        %Tesla.Env{
          status: 201,
          body: %{
            object: "audit_log_export",
            id: "audit_log_export_01GBZK5MP7TD1YCFQHFR22180V",
            state: "ready",
            url: "https://exports.audit-logs.com/audit-log-exports/export.csv",
            created_at: "2022-09-02T17:14:57.094Z",
            updated_at: "2022-09-02T17:14:57.094Z"
          }
        }

      %{
        method: :get,
        url:
          "https://api.workos.com/audit_logs/exports/audit_log_export_01GBZK5MP7TD1YCFQHFR22180V"
      } ->
        %Tesla.Env{
          status: 200,
          body: %{
            object: "audit_log_export",
            id: "audit_log_export_01GBZK5MP7TD1YCFQHFR22180V",
            state: "ready",
            url: "https://exports.audit-logs.com/audit-log-exports/export.csv",
            created_at: "2022-09-02T17:14:57.094Z",
            updated_at: "2022-09-02T17:14:57.094Z"
          }
        }
    end)

    :ok
  end

  describe "#create_event/1 with a valid event" do
    test "returns a 201 status" do
      assert {:ok, nil} =
               WorkOS.AuditLogs.create_event(%{
                 organization: "org_123",
                 event: %{
                   action: "user.signed_in",
                   occurred_at: "2022-09-08T19:46:03.435Z",
                   version: 1,
                   actor: %{
                     id: "user_TF4C5938",
                     type: "user",
                     name: "Jon Smith",
                     metadata: %{
                       role: "admin"
                     }
                   },
                   targets: [
                     %{
                       id: "user_98432YHF",
                       type: "user",
                       name: "Jon Smith"
                     },
                     %{
                       id: "team_J8YASKA2",
                       type: "team",
                       metadata: %{
                         owner: "user_01GBTCQ2"
                       }
                     }
                   ],
                   context: %{
                     location: "1.1.1.1",
                     user_agent: "Chrome/104.0.0"
                   },
                   metadata: %{
                     extra: "data"
                   }
                 }
               })
    end
  end

  describe "@create_event/0 missing params" do
    assert_raise ArgumentError, fn ->
      WorkOS.AuditLogs.create_event(%{})
    end
  end

  describe "@create_export/1 with valid params" do
    test "returns a 201 status" do
      assert {:ok,
              %{
                object: "audit_log_export",
                id: "audit_log_export_01GBZK5MP7TD1YCFQHFR22180V",
                state: "ready",
                url: "https://exports.audit-logs.com/audit-log-exports/export.csv",
                created_at: "2022-09-02T17:14:57.094Z",
                updated_at: "2022-09-02T17:14:57.094Z"
              }} =
               WorkOS.AuditLogs.create_export(%{
                 organization: "org_123",
                 range_start: "2022-09-08T19:46:03.435Z",
                 range_end: "2022-09-08T19:46:03.435Z",
                 actions: ["user.signed_in"],
                 actors: ["user_TF4C5938"],
                 targets: ["user_98432YHF"]
               })
    end
  end

  describe "@create_export/1 missing params" do
    assert_raise ArgumentError, fn ->
      WorkOS.AuditLogs.create_export(%{})
    end
  end

  describe "@create_export/1 missing organization param" do
    assert_raise ArgumentError, fn ->
      WorkOS.AuditLogs.create_export(%{
        range_start: "2022-09-08T19:46:03.435Z",
        range_end: "2022-09-08T19:46:03.435Z",
        actions: ["user.signed_in"],
        actors: ["user_TF4C5938"],
        targets: ["user_98432YHF"]
      })
    end
  end

  describe "@create_export/1 missing range_start param" do
    assert_raise ArgumentError, fn ->
      WorkOS.AuditLogs.create_export(%{
        organization: "org_123",
        range_end: "2022-09-08T19:46:03.435Z",
        actions: ["user.signed_in"],
        actors: ["user_TF4C5938"],
        targets: ["user_98432YHF"]
      })
    end
  end

  describe "@create_export/1 missing range_end param" do
    assert_raise ArgumentError, fn ->
      WorkOS.AuditLogs.create_export(%{
        organization: "org_123",
        range_start: "2022-09-08T19:46:03.435Z",
        actions: ["user.signed_in"],
        actors: ["user_TF4C5938"],
        targets: ["user_98432YHF"]
      })
    end
  end

  describe "@get_export/1" do
    test "returns a 200 status" do
      assert {:ok,
              %{
                object: "audit_log_export",
                id: "audit_log_export_01GBZK5MP7TD1YCFQHFR22180V",
                state: "ready",
                url: "https://exports.audit-logs.com/audit-log-exports/export.csv",
                created_at: "2022-09-02T17:14:57.094Z",
                updated_at: "2022-09-02T17:14:57.094Z"
              }} = WorkOS.AuditLogs.get_export("audit_log_export_01GBZK5MP7TD1YCFQHFR22180V")
    end
  end

  describe "@get_export/1 missing id" do
    assert_raise ArgumentError, fn ->
      WorkOS.AuditLogs.get_export(nil)
    end
  end
end
