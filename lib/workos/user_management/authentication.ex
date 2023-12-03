defmodule WorkOS.UserManagement.Authentication do
  @moduledoc """
  WorkOS Authentication struct.
  """

  alias WorkOS.UserManagement.User

  @behaviour WorkOS.Castable

  @type t() :: %__MODULE__{
          user: User.t(),
          organization_id: String.t() | nil
        }

  @enforce_keys [
    :user
  ]
  defstruct [
    :user,
    :organization_id
  ]

  @impl true
  def cast(map) do
    %__MODULE__{
      user: map["user"],
      organization_id: map["organization_id"]
    }
  end
end
