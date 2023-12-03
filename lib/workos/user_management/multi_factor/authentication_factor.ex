defmodule WorkOS.UserManagement.MultiFactor.AuthenticationFactor do
  @moduledoc """
  WorkOS Authentication Factor struct.
  """

  alias WorkOS.UserManagement.MultiFactor.SMS
  alias WorkOS.UserManagement.MultiFactor.TOTP

  @behaviour WorkOS.Castable

  @type t() :: %__MODULE__{
          id: String.t(),
          type: String.t(),
          user_id: String.t() | nil,
          sms: SMS.t() | nil,
          totp: TOTP.t() | nil,
          updated_at: String.t(),
          created_at: String.t()
        }

  @enforce_keys [
    :id,
    :type,
    :updated_at,
    :created_at
  ]
  defstruct [
    :id,
    :type,
    :user_id,
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
      user_id: map["user_id"],
      sms: map["sms"],
      totp: map["totp"],
      updated_at: map["updated_at"],
      created_at: map["created_at"]
    }
  end
end
