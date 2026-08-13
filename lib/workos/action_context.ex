# @oagen-ignore-file — hand-maintained; AuthKit Actions request context.

defmodule WorkOS.ActionContext do
  @moduledoc """
  A verified, deserialized AuthKit Action request.

  WorkOS sends a flat context object discriminated by `object`, not the
  webhook event envelope:

    * `"authentication_action_context"` — `user`, `organization`,
      `organization_membership`, `issuer`
    * `"user_registration_action_context"` — `user_data`, `invitation`

  `authentication_method`, `ip_address`, `user_agent`, and
  `device_fingerprint` are shared by both context types; fields specific to
  the other variant are `nil`.
  """

  defstruct [
    :object,
    :id,
    :authentication_method,
    :ip_address,
    :user_agent,
    :device_fingerprint,
    :user,
    :organization,
    :organization_membership,
    :issuer,
    :user_data,
    :invitation
  ]

  @type t :: %__MODULE__{
          object: String.t() | nil,
          id: String.t() | nil,
          authentication_method: WorkOS.AuthenticateResponseAuthenticationMethod.t() | nil,
          ip_address: String.t() | nil,
          user_agent: String.t() | nil,
          device_fingerprint: String.t() | nil,
          user: WorkOS.User.t() | nil,
          organization: WorkOS.Organization.t() | nil,
          organization_membership: WorkOS.OrganizationMembership.t() | nil,
          issuer: String.t() | nil,
          user_data: WorkOS.ActionUserData.t() | nil,
          invitation: WorkOS.Invitation.t() | nil
        }

  @doc false
  @spec from_map(map()) :: t()
  def from_map(map) when is_map(map) do
    %__MODULE__{
      object: map["object"],
      id: map["id"],
      authentication_method:
        WorkOS.Cast.enum(
          map["authentication_method"],
          &WorkOS.AuthenticateResponseAuthenticationMethod.cast/1
        ),
      ip_address: map["ip_address"],
      user_agent: map["user_agent"],
      device_fingerprint: map["device_fingerprint"],
      user: WorkOS.Cast.nested(map["user"], &WorkOS.User.from_map/1),
      organization: WorkOS.Cast.nested(map["organization"], &WorkOS.Organization.from_map/1),
      organization_membership:
        WorkOS.Cast.nested(
          map["organization_membership"],
          &WorkOS.OrganizationMembership.from_map/1
        ),
      issuer: map["issuer"],
      user_data: WorkOS.Cast.nested(map["user_data"], &WorkOS.ActionUserData.from_map/1),
      invitation: WorkOS.Cast.nested(map["invitation"], &WorkOS.Invitation.from_map/1)
    }
  end
end
