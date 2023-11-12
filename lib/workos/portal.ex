defmodule WorkOS.Portal do
  @moduledoc """
  Manage Portal in WorkOS.

  @see https://workos.com/docs/reference/admin-portal
  """

  @generate_portal_link_intent [
    "audit_logs",
    "domain_verification",
    "dsync",
    "log_streams",
    "sso"
  ]

  @doc """
  Generates a Portal Link

  Parameter options:

    * `:organization` - An Organization identifier. (required)
    * `:intent` - The intent of the Admin Portal. (required)
    * `:return_url` - The URL to which WorkOS should send users when they click on the link to return to your website.
    * `:success_url` - The URL to which WorkOS will redirect users to upon successfully setting up Single Sign-On or Directory Sync.

  """
  def generate_link(client \\ WorkOS.client(), _opts)

  def generate_link(_client, %{intent: intent} = _opts)
      when intent not in @generate_portal_link_intent,
      do:
        raise(ArgumentError,
          message:
            "Invalid intent, must be one of the following: " <>
              Enum.join(@generate_portal_link_intent, ", ")
        )

  @spec generate_link(map()) ::
          WorkOS.Client.response(String.t())
  @spec generate_link(WorkOS.Client.t(), map()) ::
          WorkOS.Client.response(String.t())
  def generate_link(client, opts)
      when is_map_key(opts, :organization) and is_map_key(opts, :intent) do
    IO.inspect(client)
  end

  def generate_link(_client, _opts),
    do: raise(ArgumentError, message: "Needs both intent and organization.")
end
