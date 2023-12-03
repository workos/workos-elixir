defmodule WorkOS.UserManagement.MultiFactor.AuthenticationChallenge do
  @moduledoc """
  WorkOS Authentication Challenge struct.
  """

  @behaviour WorkOS.Castable

  @type t() :: %__MODULE__{
          id: String.t(),
          code: String.t() | nil,
          authentication_factor_id: String.t(),
          expires_at: String.t() | nil,
          updated_at: String.t(),
          created_at: String.t()
        }

  @enforce_keys [
    :id,
    :authentication_factor_id,
    :updated_at,
    :created_at
  ]
  defstruct [
    :id,
    :code,
    :authentication_factor_id,
    :expires_at,
    :updated_at,
    :created_at
  ]

  @impl true
  def cast(map) do
    %__MODULE__{
      id: map["id"],
      code: map["code"],
      authentication_factor_id: map["authentication_factor_id"],
      expires_at: map["expires_at"],
      updated_at: map["updated_at"],
      created_at: map["created_at"]
    }
  end
end
