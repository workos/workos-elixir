defmodule WorkOs.Client do
  @moduledoc """
  WorkOs API client.
  """

  require Logger

  alias WorkOs.Castable

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

  @spec get(t(), Castable.impl(), String.t()) :: response(any())
  @spec get(t(), Castable.impl(), String.t(), Keyword.t()) :: response(any())
  def get(client, castable_module, path, opts \\ []) do
    client_module = client.client || WorkOs.Client.TeslaClient

    opts =
      opts
      |> Keyword.put(:method, :get)
      |> Keyword.put(:url, path)

    client_module.request(client, opts)
    |> handle_response(path, castable_module)
  end

  @spec post(t(), Castable.impl(), String.t()) :: response(any())
  @spec post(t(), Castable.impl(), String.t(), map()) :: response(any())
  @spec post(t(), Castable.impl(), String.t(), map(), Keyword.t()) :: response(any())
  def post(client, castable_module, path, body \\ %{}, opts \\ []) do
    client_module = client.client || WorkOs.Client.TeslaClient

    opts =
      opts
      |> Keyword.put(:method, :post)
      |> Keyword.put(:url, path)
      |> Keyword.put(:body, body)

    client_module.request(client, opts)
    |> handle_response(path, castable_module)
  end

  @spec put(t(), Castable.impl(), String.t()) :: response(any())
  @spec put(t(), Castable.impl(), String.t(), map()) :: response(any())
  @spec put(t(), Castable.impl(), String.t(), map(), Keyword.t()) :: response(any())
  def put(client, castable_module, path, body \\ %{}, opts \\ []) do
    client_module = client.client || WorkOs.Client.TeslaClient

    opts =
      opts
      |> Keyword.put(:method, :put)
      |> Keyword.put(:url, path)
      |> Keyword.put(:body, body)

    client_module.request(client, opts)
    |> handle_response(path, castable_module)
  end

  @spec delete(t(), Castable.impl(), String.t()) :: response(any())
  @spec delete(t(), Castable.impl(), String.t(), map()) :: response(any())
  @spec delete(t(), Castable.impl(), String.t(), map(), Keyword.t()) :: response(any())
  def delete(client, castable_module, path, body \\ %{}, opts \\ []) do
    client_module = client.client || WorkOs.Client.TeslaClient

    opts =
      opts
      |> Keyword.put(:method, :delete)
      |> Keyword.put(:url, path)
      |> Keyword.put(:body, body)

    client_module.request(client, opts)
    |> handle_response(path, castable_module)
  end

  defp handle_response(response, path, castable_module) do
    case response do
      {:ok, %{body: "", status: status}} when status in 200..299 ->
        {:ok, Castable.cast(castable_module, %{})}

      {:ok, %{body: body, status: status}} when status in 200..299 ->
        {:ok, Castable.cast(castable_module, body)}

      {:ok, %{body: body}} when is_map(body) ->
        Logger.error("#{inspect(__MODULE__)} error when calling #{path}: #{inspect(body)}")
        {:error, Castable.cast(WorkOs.Error, body)}

      {:ok, %{body: body}} when is_binary(body) ->
        Logger.error("#{inspect(__MODULE__)} error when calling #{path}: #{body}")
        {:error, body}

      {:error, reason} ->
        Logger.error("#{inspect(__MODULE__)} error when calling #{path}: #{inspect(reason)}")
        {:error, :client_error}
    end
  end
end
