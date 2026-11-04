# @oagen-ignore-file

defmodule WorkOS.AuditLogOccurredAtTest do
  use ExUnit.Case, async: true

  defp event do
    %{
      "action" => "user.signed_in",
      "actor" => %{"id" => "user_1", "type" => "user"},
      "targets" => [],
      "context" => %{"location" => "127.0.0.1"}
    }
  end

  test "omitted occurred_at stays absent when the event is serialized" do
    serialized = event() |> WorkOS.AuditLogEvent.from_map() |> WorkOS.AuditLogEvent.to_map()

    refute Map.has_key?(serialized, "occurred_at")
  end

  test "an explicit occurred_at is preserved" do
    timestamp = "2026-11-03T12:34:56.789Z"
    data = Map.put(event(), "occurred_at", timestamp)
    serialized = data |> WorkOS.AuditLogEvent.from_map() |> WorkOS.AuditLogEvent.to_map()

    assert serialized["occurred_at"] == timestamp
  end
end
