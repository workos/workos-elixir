defmodule WorkOS.UserManagement.MagicAuth.SendMagicAuthCode do
  @moduledoc """
  WorkOS Send Magic Auth Code struct.
  """

  @behaviour WorkOS.Castable

  @type t() :: %__MODULE__{
          email: String.t()
        }

  @enforce_keys [
    :email
  ]
  defstruct [
    :email
  ]

  @impl true
  def cast(map) do
    %__MODULE__{
      email: map["email"]
    }
  end
end
