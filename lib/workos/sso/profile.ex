defmodule WorkOS.SSO.Profile do

  @behaviour WorkOS.Castable

  @type t() :: %__MODULE__{
          id: String.t(),
          idp_id: String.t(),
          organization_id: String.t() | nil,
          connection_id: String.t(),
          # TODO - Add type for connection type
          connection_type: String.t(),
          email: String.t(),
          first_name: String.t() | nil,
          last_name: String.t() | nil,
          groups: [String.t()] | nil,
          raw_attributes: %{String.t() => any()} | nil
        }

  @enforce_keys [:id, :idp_id, :connection_id, :connection_type, :email]
  defstruct [
    :id,
    :idp_id,
    :organization_id,
    :connection_id,
    :connection_type,
    :email,
    :first_name,
    :last_name,
    :groups,
    :raw_attributes
  ]

  @impl true
  def cast(map) do
    %__MODULE__{
      id: map["id"],
      idp_id: map["idp_id"],
      organization_id: map["organization_id"],
      connection_id: map["connection_id"],
      connection_type: map["connection_type"],
      email: map["email"],
      first_name: map["last_name"],
      groups: map["groups"],
      raw_attributes: map["raw_attributes"]
    }
  end
end
