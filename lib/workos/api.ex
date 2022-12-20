defmodule WorkOS.API do
  @moduledoc """
  Provides core API communication and data processing functionality.
  """

  @doc """
  Generates the Tesla client used to make requests to WorkOS
  """
  def client(opts \\ []) do
    middleware = [
      {Tesla.Middleware.BaseUrl, WorkOS.base_url()},
      Tesla.Middleware.JSON,
      {Tesla.Middleware.Headers,
       [
         {"Authorization", "Bearer " <> WorkOS.api_key(opts)}
       ]}
    ]

    Tesla.client(middleware, WorkOS.adapter())
  end

  @doc """
  Performs a GET request
  """
  def get(path, params \\ [], opts \\ []) do
    client(opts)
    |> Tesla.get(path, query: params)
    |> handle_response
  end

  @doc """
  Performs a POST request
  """
  def post(path, params \\ "", opts \\ []) do
    client(opts)
    |> Tesla.post(path, params)
    |> handle_response
  end

  @doc """
  Performs a DELETE request
  """
  def delete(path, params \\ "", opts \\ []) do
    client(opts)
    |> Tesla.delete(path, query: params)
    |> handle_response
  end

  @doc """
  Performs a PUT request
  """
  def put(path, params \\ "", opts \\ []) do
    client(opts)
    |> Tesla.put(path, query: params)
    |> handle_response
  end

  @doc """
  Processes the HTTP response
  Converts non-200 responses (400+ status code) into error tuples
  """
  def handle_response({:ok, %{status: status} = response}) when status >= 400,
    do: handle_error({:error, response})

  def handle_response({:ok, response}) do
    {:ok, process_response(response)}
  end

  def handle_response({:error, response}), do: handle_error({:error, response})

  @doc """
  Handles request errors
  """
  def handle_error({_type, response}) do
    {:error, process_response(response)}
  end

  @doc """
  Performs data transformations on the response body to remove JSON fluff
  """
  def process_response(%{body: %{"data" => data, "listMetadata" => metadata}}) do
    %{data: data, metadata: metadata}
  end

  def process_response(%{body: %{"data" => data}}), do: data
  def process_response(%{body: %{"message" => message}}), do: message
  def process_response(%{body: body}), do: body
  def process_response(message), do: message

  def process_params(params, keys, defaults \\ %{}) do
    defaults
    |> Map.merge(params)
    |> Map.take(keys ++ Map.keys(defaults))
  end
end
