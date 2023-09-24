defmodule WorkOS.API do
  @moduledoc """
  Provides core API communication and data processing functionality.
  """

  @doc """
  Generates the HTTP client used to make requests to WorkOS
  """
  def client(http_client, opts \\ []) do
    auth = opts |> Keyword.get(:access_token, WorkOS.api_key(opts))

    http_client.new(opts: opts, auth: auth)
  end

  @doc """
  Performs a GET request
  """
  def get(http_client, url, query \\ [], opts \\ []) do
    http_client.get(url, query, opts)
    |> handle_response()
  end

  @doc """
  Performs a POST request
  """
  def post(http_client, url, body, opts \\ []) do
    http_client.post(url, body, opts)
    |> handle_response()
  end

  @doc """
  Performs a DELETE request
  """
  def delete(http_client, url, query \\ [], opts \\ []) do
    http_client.delete(url, query, opts)
    |> handle_response()
  end

  @doc """
  Performs a PUT request
  """
  def put(http_client, url, body, opts \\ []) do
    http_client.put(url, body, opts)
    |> handle_response()
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
