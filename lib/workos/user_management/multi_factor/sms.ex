defmodule WorkOS.UserManagement.MultiFactor.SMS do
  @moduledoc """
  WorkOS SMS struct.
  """

  @behaviour WorkOS.Castable

  @type t() :: %__MODULE__{
          phone_number: String.t()
        }

  @enforce_keys [
    :phone_number
  ]
  defstruct [
    :phone_number
  ]

  @impl true
  def cast(params) do
    %__MODULE__{
      phone_number: params["phone_number"]
    }
  end
end
