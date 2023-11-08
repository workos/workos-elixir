defmodule WorkOS.Client.TeslaClient do
  @moduledoc """
  Tesla client for WorkOS. This is the default HTTP client used.
  """
  @behaviour WorkOS.Client

  @doc """
  Sends a request to a WorkOS API endpoint, given list of request opts.
  """
  @spec request(WorkOS.Client.t(), Keyword.t()) ::
          {:ok, %{body: map(), status: pos_integer()}} | {:error, any()}
  def request(client, opts) do
    opts = Keyword.take(opts, [:method, :url, :query, :headers, :body, :opts])
    access_token = opts |> Keyword.get(:opts, []) |> Keyword.get(:access_token, client.api_key)

    Tesla.request(new(client, access_token), opts)
  end

  @doc """
  Returns a new `Tesla.Client`, configured for calling the WorkOS API.
  """
  @spec new(WorkOS.Client.t(), String.t()) :: Tesla.Client.t()
  def new(client, access_token) do
    Tesla.client([
      Tesla.Middleware.Logger,
      {Tesla.Middleware.BaseUrl, client.base_url},
      Tesla.Middleware.PathParams,
      Tesla.Middleware.JSON,
      {Tesla.Middleware.Headers, [{"Authorization", "Bearer #{access_token}"}]}
    ])
  end
end
