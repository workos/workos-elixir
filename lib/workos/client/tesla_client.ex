defmodule WorkOS.Client.TeslaClient do
  @moduledoc """
  Tesla client for WorkOS. This is the default HTTP client used.
  """

  @behaviour WorkOS.Client

  @doc """
  Sends a request to a WorkOS API endpoint, given list of request opts.
  """
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
    Tesla.client(
      [
        Tesla.Middleware.Logger,
        {Tesla.Middleware.BaseUrl, client.base_url},
        Tesla.Middleware.PathParams,
        Tesla.Middleware.JSON,
        {Tesla.Middleware.Headers,
         [
           {"Authorization", "Bearer #{access_token}"},
           {"User-Agent", user_agent()}
         ]}
      ],
      adapter()
    )
  end

  # Defer to a globally configured Tesla adapter (`config :tesla, adapter: ...`)
  # if the consuming application set one. Otherwise pin the default `:httpc`
  # adapter with explicit TLS verification, since `:httpc` performs no peer or
  # hostname verification on Erlang/OTP 25 and earlier when no `ssl` options are
  # supplied.
  defp adapter do
    case Application.get_env(:tesla, :adapter) do
      nil -> {Tesla.Adapter.Httpc, ssl: ssl_options()}
      configured -> configured
    end
  end

  defp ssl_options do
    [
      verify: :verify_peer,
      cacerts: ca_certificates(),
      customize_hostname_check: [
        match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
      ]
    ]
  end

  # OTP 25+ exposes the OS trust store via `:public_key.cacerts_get/0`. Older
  # runtimes (OTP 24 is still permitted by `elixir ~> 1.16`) fall back to the
  # bundled certifi CA store.
  defp ca_certificates do
    if function_exported?(:public_key, :cacerts_get, 0) do
      :public_key.cacerts_get()
    else
      :certifi.cacerts()
    end
  end

  defp user_agent do
    "workos-elixir/#{Application.spec(:workos, :vsn)}"
  end
end
