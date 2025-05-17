defmodule WorkOS.UserManagement.MultiFactor.TOTP do
  @moduledoc """
  WorkOS TOTP struct.
  """

  @behaviour WorkOS.Castable

  @type t() :: %__MODULE__{
          issuer: String.t(),
          user: String.t(),
          secret: String.t(),
          qr_code: String.t(),
          uri: String.t()
        }

  @enforce_keys [
    :issuer,
    :user,
    :secret,
    :qr_code,
    :uri
  ]
  defstruct [
    :issuer,
    :user,
    :secret,
    :qr_code,
    :uri
  ]

  @impl true
  def cast(params) do
    %__MODULE__{
      issuer: params["issuer"],
      user: params["user"],
      secret: params["secret"],
      qr_code: params["qr_code"],
      uri: params["uri"]
    }
  end
end
