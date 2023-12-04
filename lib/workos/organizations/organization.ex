defmodule WorkOS.Organizations.Organization do
  @moduledoc """
  WorkOS Organization struct.
  """

  alias WorkOS.Castable
  alias WorkOS.Organizations.Organization.Domain

  @behaviour WorkOS.Castable

  @type t() :: %__MODULE__{
          id: String.t(),
          object: String.t(),
          name: String.t(),
          allow_profiles_outside_organization: boolean(),
          domains: list(Domain.t()) | nil,
          updated_at: String.t(),
          created_at: String.t()
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
      updated_at: map["updated_at"],
      created_at: map["created_at"]
    }
  end
end
