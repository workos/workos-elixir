# @oagen-ignore-file — hand-maintained; AuthKit Actions user registration data.

defmodule WorkOS.ActionUserData do
  @moduledoc """
  The provisional user data carried by a `user_registration` action context
  (object: `"user_data"`).
  """

  defstruct [:object, :email, :name, :first_name, :last_name]

  @type t :: %__MODULE__{
          object: String.t() | nil,
          email: String.t() | nil,
          name: String.t() | nil,
          first_name: String.t() | nil,
          last_name: String.t() | nil
        }

  @doc false
  @spec from_map(map()) :: t()
  def from_map(map) when is_map(map) do
    %__MODULE__{
      object: map["object"],
      email: map["email"],
      name: map["name"],
      first_name: map["first_name"],
      last_name: map["last_name"]
    }
  end
end
