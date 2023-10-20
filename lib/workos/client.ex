defmodule WorkOs.Client do
  @moduledoc """
  WorkOs API client.
  """

  require Logger

  @callback request(t(), Keyword.t()) ::
              {:ok, %{body: map(), status: pos_integer()}} | {:error, any()}

  @type response(type) :: {:ok, type} | {:error, WorkOs.Error.t() | :client_error}

  @type t() :: %__MODULE__{
          api_key: String.t(),
          base_url: String.t() | nil,
          client: module() | nil
        }

  @enforce_keys [:api_key, :base_url, :client]
  defstruct [:api_key, :base_url, :client]

  @default_opts [
    base_url: "https://api.workos.com",
    client: __MODULE__.TeslaClient
  ]

  @doc """
  Creates a new WorkOs client struct given a keyword list of config opts.
  """
  @spec new(WorkOs.config()) :: t()
  def new(config) do
    config = Keyword.take(config, [:api_key, :base_url, :client])
    struct!(__MODULE__, Keyword.merge(@default_opts, config))
  end
end
