defmodule WorkOS.Portal.Link do
  @moduledoc """
  WorkOS Portal Link struct.
  """

  @behaviour WorkOS.Castable

  @type t() :: %__MODULE__{
          link: String.t()
        }

  @enforce_keys [
    :link
  ]
  defstruct [
    :link
  ]

  @impl true
  def cast(map) do
    %__MODULE__{
      link: map["link"]
    }
  end
end
