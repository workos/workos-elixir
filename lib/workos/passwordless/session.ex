defmodule WorkOS.Passwordless.Session do
  @moduledoc """
  WorkOS Passwordless session struct.
  """

  alias WorkOS.Util

  @behaviour WorkOS.Castable

  @type t() :: %__MODULE__{
          id: String.t(),
          email: String.t(),
          link: String.t(),
          object: String.t(),
          expires_at: DateTime.t(),
        }

  @enforce_keys [:id, :email, :link, :object, :expires_at]
  defstruct [
    :id,
    :email,
    :link,
    :object,
    :expires_at,
  ]

  @impl true
  def cast(map) do
    %__MODULE__{
      id: map["id"],
      email: map["email"],
      link: map["link"],
      object: map["object"],
      expires_at: Util.parse_iso8601(map["expires_at"]),
    }
  end
end
