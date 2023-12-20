defmodule WorkOS.MFA.TOTP do
  @moduledoc """
  This response struct is deprecated. Use the User Management Multi-Factor API instead.
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
  def cast(map) do
    %__MODULE__{
      issuer: map["issuer"],
      user: map["user"],
      secret: map["secret"],
      qr_code: map["qr_code"],
      uri: map["uri"]
    }
  end
end
