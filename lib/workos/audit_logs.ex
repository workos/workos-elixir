defmodule WorkOS.AuditLogs do
  @moduledoc """
  Manage Audit Logs in WorkOS.

  @see https://workos.com/docs/reference/audit-logs
  """

  alias WorkOS.AuditLogs.Export
  alias WorkOS.Empty

  @doc """
  Creates an Audit Log Event.

  Parameter options:

    * `:organization_id` - The unique ID of the Organization. (required)
    * `:event` - The Audit Log Event to be created. (required)
    * `:idempotency_key` - A unique string as the value. Each subsequent request matching this unique string will return the same response.

  """
  @spec create_event(map()) :: WorkOS.Client.response(Empty.t())
  @spec create_event(WorkOS.Client.t(), map()) ::
          WorkOS.Client.response(Empty.t())
  def create_event(client \\ WorkOS.client(), opts)
      when is_map_key(opts, :organization_id) and is_map_key(opts, :event) do
    WorkOS.Client.post(
      client,
      Empty,
      "/audit_logs/events",
      %{
        organization_id: opts[:organization_id],
        event: opts[:event]
      },
      headers: [
        {"Idempotency-Key", opts[:idempotency_key]}
      ]
    )
  end

  @doc """
  Creates an Audit Log Export.

  Parameter options:

    * `:organization_id` - The unique ID of the Organization. (required)
    * `:range_start` - ISO-8601 value for start of the export range. (required)
    * `:range_end` - ISO-8601 value for end of the export range. (required)
    * `:actions` - List of actions to filter against.
    * `:actors` - List of actor names to filter against.
    * `:targets` - List of target types to filter against.

  """
  @spec create_export(map()) :: WorkOS.Client.response(Export.t())
  @spec create_export(WorkOS.Client.t(), map()) ::
          WorkOS.Client.response(Export.t())
  def create_export(client \\ WorkOS.client(), opts)
      when is_map_key(opts, :organization_id) and is_map_key(opts, :range_start) and
             is_map_key(opts, :range_end) do
    WorkOS.Client.post(client, Export, "/audit_logs/exports", %{
      organization_id: opts[:organization_id],
      range_start: opts[:range_start],
      range_end: opts[:range_end],
      actions: opts[:actions],
      actors: opts[:actors],
      targets: opts[:targets]
    })
  end

  @doc """
  Gets an Audit Log Export given an ID.
  """
  @spec get_export(String.t()) :: WorkOS.Client.response(Export.t())
  @spec get_export(WorkOS.Client.t(), String.t()) :: WorkOS.Client.response(Export.t())
  def get_export(client \\ WorkOS.client(), audit_log_export_id) do
    WorkOS.Client.get(client, Export, "/audit_logs/exports/:id",
      opts: [
        path_params: [id: audit_log_export_id]
      ]
    )
  end
end
