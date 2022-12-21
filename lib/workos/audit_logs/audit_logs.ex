defmodule WorkOS.AuditLogs do
  import WorkOS.API

  @moduledoc """
  The Audit Logs module provides convenience methods for working with the
  WorkOS Audit Logs platform. You'll need a valid API key.

  See https://workos.com/docs/audit-logs
  """

  @doc """
  Create an Audit Log Event.

  ### Parameters
  - params (map)
    - organization (string) The unique ID of the Organization
     that the event is associated with.
    - event (map) The Audit Log event

  ### Examples

      iex> WorkOS.AuditLogs.create_event(%{
      ...>  organization: "org_123",
      ...>  event: %{
      ...>    action: "user.signed_in",
      ...>    occurred_at: "2022-09-08T19:46:03.435Z",
      ...>    version: 1,
      ...>    actor: %{
      ...>      id: "user_TF4C5938",
      ...>      type: "user",
      ...>      name: "Jon Smith",
      ...>      metadata: %{
      ...>        role: "admin"
      ...>      }
      ...>    },
      ...>    targets: [
      ...>      %{
      ...>        id: "user_98432YHF",
      ...>        type: "user",
      ...>        name: "Jon Smith"
      ...>      },
      ...>      %{
      ...>        id: "team_J8YASKA2",
      ...>        type: "team",
      ...>        metadata: %{
      ...>          owner: "user_01GBTCQ2"
      ...>        }
      ...>      }
      ...>    ],
      ...>    context: %{
      ...>      location: "New York, NY",
      ...>      user_agent: "Chrome/104.0.0"
      ...>    },
      ...>    metadata: %{
      ...>      extra: "data"
      ...>    }
      ...>  }
      ...> })

      {:ok, nil}

  """

  def create_event(params, opts \\ [])

  def create_event(params, opts)
      when is_map_key(params, :organization) and is_map_key(params, :event) do
    body = process_params(params, [:organization, :event])
    post(
      "/audit_logs/events",
      body,
      opts
    )
  end

  def create_event(_params, _opts),
    do: raise(ArgumentError, message: "Missing required parameters: organization, event")

  @doc """
  Create an Export of Audit Log Events.

  ### Parameters
  - params (map)
    - organization (string) The unique ID of the Organization
     that the event is associated with.
    - range_start (string) ISO-8601 value for start of the export range.
    - range_end (string) ISO-8601 value for end of the export range.
    - actions (list of strings) List of actions to filter against.
    - actors (list of strings) List of actors to filter against.
    - targets (list of strings) List of targets to filter against.

  ### Examples

    iex> WorkOS.AuditLogs.create_export(%{
    ...>  organization: "org_123",
    ...>  range_start: "2022-09-08T19:46:03.435Z",
    ...>  range_end: "2022-09-08T19:46:03.435Z",
    ...>  actions: ["user.signed_in"],
    ...>  actors: ["user_01GBTCQ2"],
    ...>  targets: ["user_01GBTCQ2"]
    ...> })

    ok: %{
      "object": "audit_log_export",
      "id": "audit_log_export_01GBZK5MP7TD1YCFQHFR22180V",
      "state": "ready",
      "url": "https://exports.audit-logs.com/audit-log-exports/export.csv",
      "created_at": "2022-09-02T17:14:57.094Z",
      "updated_at": "2022-09-02T17:14:57.094Z"
    }
  """

  def create_export(params, opts \\ [])

  def create_export(params, opts)
      when is_map_key(params, :organization) and
             is_map_key(params, :range_start) and
             is_map_key(params, :range_end) do
    body =
      process_params(params, [
        :organization,
        :range_start,
        :range_end,
        :actions,
        :actors,
        :targets
      ])

    post(
      "/audit_logs/exports",
      body,
      opts
    )
  end

  def create_export(_params, _opts),
    do:
      raise(ArgumentError,
        message: "Missing required parameters: organization, range_start, range_end"
      )

  @doc """
  Retrieve an Export of Audit Log Events.

  ### Parameters
  - id (string) The unique ID of the Audit Log Export.

  ### Examples

    iex> WorkOS.AuditLogs.get_export("audit_log_export_01GBZK5MP7TD1YCFQHFR22180V")

    ok: %{
      "object": "audit_log_export",
      "id": "audit_log_export_01GBZK5MP7TD1YCFQHFR22180V",
      "state": "ready",
      "url": "https://exports.audit-logs.com/audit-log-exports/export.csv",
      "created_at": "2022-09-02T17:14:57.094Z",
      "updated_at": "2022-09-02T17:14:57.094Z"
    }
  """

  def get_export(id, opts \\ [])

  def get_export(id, opts) when is_binary(id) do
    get("/audit_logs/exports/#{id}", opts)
  end

  def get_export(_id, _opts),
    do: raise(ArgumentError, message: "Missing required parameters: id")
end
