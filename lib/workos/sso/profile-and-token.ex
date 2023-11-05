defmodule WorkOS.SSO.ProfileAndToken do
  alias WorkOS.SSO.Profile

  @behaviour WorkOS.Castable

  @type t() :: %__MODULE__{
          access_token: String.t(),
          profile: Profile.t()
        }

  @enforce_keys [:access_token, :profile]
  defstruct [
    :access_token,
    :profile
  ]

  @impl true
  def cast(map) do
    %__MODULE__{
      access_token: map["access_token"],
      profile: map["profile"]
    }
  end
end
