defmodule WorkOS.DomainVerification.OrganizationDomain do
  @moduledoc """
  WorkOS OrganizationDomain struct.
  """

  @behaviour WorkOS.Castable

  @type t() :: %__MODULE__{
          id: String.t(),
          organization_id: String.t(),
          domain: String.t(),
          state: String.t(),
          verification_strategy: String.t(),
          verification_token: String.t(),
        }

  @enforce_keys [
    :id,
    :organization_id,
    :domain,
    :state,
    :verification_strategy,
    :verification_token,
  ]
  defstruct [
    :id,
    :organization_id,
    :domain,
    :state,
    :verification_strategy,
    :verification_token,
  ]

  @impl true
  def cast(map) do
    %__MODULE__{
      id: map["id"],
      organization_id: map["organization_id"],
      domain: map["domain"],
      state: map["state"],
      verification_strategy: map["verification_strategy"],
      verification_token: map["verification_token"],
    }
  end
end
