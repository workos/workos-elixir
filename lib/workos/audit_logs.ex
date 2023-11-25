defmodule WorkOS.AuditLogs do
  @moduledoc """
  Manage Audit Logs in WorkOS.

  @see https://workos.com/docs/reference/audit-logs
  """

  alias WorkOS.AuditLogs.Export

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
  def create_export(client \\ WorkOS.client(), opts) do
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
