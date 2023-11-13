defmodule WorkOS.Passwordless.Session.Send do
  @moduledoc """
  WorkOS Send Passwordless session struct.
  """

  @behaviour WorkOS.Castable

  @type t() :: %__MODULE__{
          success: Boolean.t()
        }

  @enforce_keys [:success]
  defstruct [
    :success
  ]

  @impl true
  def cast(map) do
    %__MODULE__{
      success: map["success"]
    }
  end
end
