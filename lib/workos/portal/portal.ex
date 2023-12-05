defmodule WorkOS.Portal do
  import WorkOS.API

  @generate_link_intents ["sso", "dsync", "audit_logs", "log_streams", "domain_verification"]

  @moduledoc """
  The Portal module provides resource methods for working with the Admin
  Portal product

  @see https://workos.com/docs/admin-portal/guide
  """

  @doc """
  Generate a link to grant access to an organization's Admin Portal

  ### Parameters
  - params (map)
    - intent (string) The access scope for the generated Admin Portal
    link. Valid values are: ["sso", "dsync", "audit_logs", "log_streams"]
    - organization (string) The ID of the organization the Admin
    Portal link will be generated for.
    - return_url (string) The URL that the end user will be redirected to upon
    exiting the generated Admin Portal. If none is provided, the default
    redirect link set in your WorkOS Dashboard will be used.
    - success_url (string) he URL to which WorkOS will redirect users to upon
    successfully setting up Single Sign On or Directory Sync.

  ### Example
  WorkOS.Portal.generate_link(%{
    intent: "sso",
    organization: "org_1234"
  })
  """
  def generate_link(params, opts \\ [])

  def generate_link(%{intent: intent} = _params, _opts)
      when intent not in @generate_link_intents,
      do:
        raise(ArgumentError,
          message:
            "invalid intent, must be one of the following: sso, dsync, audit_logs or log_streams"
        )

  def generate_link(params, opts)
      when is_map_key(params, :organization) and is_map_key(params, :intent) do
    query = process_params(params, [:intent, :organization, :return_url, :success_url])
    post("/portal/generate_link", query, opts)
  end

  def generate_link(_params, _opts),
    do: raise(ArgumentError, message: "need both intent and organization in params")
end
