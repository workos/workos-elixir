defmodule WorkOS.MFA.AuthenticationFactor do
  @moduledoc """
  This response struct is deprecated. Use the User Management Multi-Factor API instead.
  """

  @behaviour WorkOS.Castable

  alias WorkOS.MFA.SMS
  alias WorkOS.MFA.TOTP

  @type t() :: %__MODULE__{
          id: String.t(),
          type: String.t(),
          sms: SMS.t() | nil,
          totp: TOTP.t() | nil,
          updated_at: String.t(),
          created_at: String.t()
        }

  @enforce_keys [:id, :type, :sms, :totp, :updated_at, :created_at]
  defstruct [
    :id,
    :type,
    :sms,
    :totp,
    :updated_at,
    :created_at
  ]

  @impl true
  def cast(map) do
    %__MODULE__{
      id: map["id"],
      type: map["type"],
      sms: map["sms"],
      totp: map["totp"],
      updated_at: map["updated_at"],
      created_at: map["created_at"]
    }
  end
end
