defmodule WorkOS.Portal do
  import WorkOS.API

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
     link. Valid values are: ["sso"]
    - organization (string) The ID of the organization the Admin
     Portal link will be generated for.
    - return_url (string) The URL that the end user will be redirected to upon
     exiting the generated Admin Portal. If none is provided, the default
     redirect link set in your WorkOS Dashboard will be used.

  ### Example
  WorkOS.Portal.generate_link(%{
    intent: "sso",
    organization: "org_1234"
  })
  """
  def generate_link(params, opts \\ [])

  def generate_link(params, opts) when is_map_key(params, :organization) do
    query = process_params(params, [:intent, :organization, :return_url], %{intent: "sso"})
    post("/portal/generate_link", query, opts)
  end

  def generate_link(_params, _opts),
    do: raise(ArgumentError, message: "need both intent and organization in params")
end
