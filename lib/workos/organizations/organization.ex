defmodule WorkOS.Organizations.Organization do
  @moduledoc """
  WorkOS Organization struct.
  """

  alias WorkOS.Util
  alias WorkOS.Castable
  alias WorkOS.SSO.Organizations.Organization.Domain

  @behaviour WorkOS.Castable

  @type t() :: %__MODULE__{
          id: String.t(),
          object: String.t(),
          name: String.t(),
          allow_profiles_outside_organization: Boolean.t(),
          domains: list(Domain.t()) | nil,
          updated_at: DateTime.t(),
          created_at: DateTime.t()
        }

  @enforce_keys [
    :id,
    :object,
    :name,
    :allow_profiles_outside_organization,
    :domains,
    :updated_at,
    :created_at
  ]
  defstruct [
    :id,
    :object,
    :name,
    :allow_profiles_outside_organization,
    :domains,
    :updated_at,
    :created_at
  ]

  @impl true
  def cast(map) do
    %__MODULE__{
      id: map["id"],
      object: map["object"],
      name: map["name"],
      domains: Castable.cast_list(Domain, map["domains"]),
      allow_profiles_outside_organization: map["allow_profiles_outside_organization"],
      updated_at: Util.parse_iso8601(map["created_at"]),
      created_at: Util.parse_iso8601(map["created_at"])
    }
  end
end
