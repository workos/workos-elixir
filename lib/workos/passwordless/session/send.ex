defmodule WorkOS.Passwordless.Session.Send do
  @moduledoc """
  WorkOS Send Passwordless session struct.
  """

  @behaviour WorkOS.Castable

  @type t() :: %__MODULE__{
          message: String.t() | nil,
          success: Boolean.t()
        }

  @enforce_keys [:success]
  defstruct [
    :message,
    :success
  ]

  @impl true
  def cast(map) do
    %__MODULE__{
      message: map["message"],
      success: map["success"]
    }
  end
end
