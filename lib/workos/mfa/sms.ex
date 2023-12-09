defmodule WorkOS.MFA.SMS do
  @moduledoc """
  This response struct is deprecated. Use the User Management Multi-Factor API instead.
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
  def cast(map) do
    %__MODULE__{
      phone_number: map["phone_number"]
    }
  end
end
