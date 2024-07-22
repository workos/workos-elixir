defmodule WorkOS.UserManagement.Authentication do
  @moduledoc """
  WorkOS Authentication struct.
  """

  alias WorkOS.UserManagement.User

  @behaviour WorkOS.Castable

  @type t() :: %__MODULE__{
          user: User.t(),
          organization_id: String.t() | nil,
          access_token: String.t() | nil,
          refresh_token: String.t() | nil,
          impersonator: User.t() | nil,
          authentication_method: String.t()
        }

  @enforce_keys [
    :user,
    :authentication_method
  ]
  defstruct [
    :user,
    :organization_id,
    :access_token,
    :refresh_token,
    :impersonator,
    :authentication_method
  ]

  @impl true
  def cast(map) do
    %__MODULE__{
      user: map["user"],
      organization_id: map["organization_id"],
      access_token: map["access_token"],
      refresh_token: map["refresh_token"],
      impersonator: map["impersonator"],
      authentication_method: map["authentication_method"]
    }
  end
end
