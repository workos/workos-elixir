defmodule WorkOS.MFA.AuthenticationChallenge do
  @moduledoc """
  This response struct is deprecated. Use the User Management Multi-Factor API instead.
  """

  @behaviour WorkOS.Castable

  @type t() :: %__MODULE__{
          id: String.t(),
          authentication_factor_id: String.t(),
          expires_at: String.t(),
          updated_at: String.t(),
          created_at: String.t()
        }

  @enforce_keys [:id, :authentication_factor_id, :expires_at, :updated_at, :created_at]
  defstruct [
    :id,
    :authentication_factor_id,
    :expires_at,
    :updated_at,
    :created_at
  ]

  @impl true
  def cast(map) do
    %__MODULE__{
      id: map["id"],
      authentication_factor_id: map["authentication_factor_id"],
      expires_at: map["expires_at"],
      updated_at: map["updated_at"],
      created_at: map["created_at"]
    }
  end
end
