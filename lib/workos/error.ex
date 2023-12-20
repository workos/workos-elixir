defmodule WorkOS.Error do
  @moduledoc """
  Castable module for returning structured errors from the WorkOS API.
  """

  @behaviour WorkOS.Castable

  @type unprocessable_entity_error() :: %{
          field: String.t(),
          code: String.t()
        }

  @type t() :: %__MODULE__{
          code: String.t() | nil,
          error: String.t() | nil,
          errors: [unprocessable_entity_error()] | nil,
          message: String.t(),
          error_description: String.t() | nil
        }

  defstruct [
    :code,
    :error,
    :errors,
    :message,
    :error_description
  ]

  @impl true
  def cast(error) when is_map(error) do
    %__MODULE__{
      code: error["code"],
      error: error["error"],
      errors: error["errors"],
      message: error["message"],
      error_description: error["error_description"]
    }
  end
end
