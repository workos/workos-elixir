defmodule WorkOS.HackneyClient do
  @behaviour WorkOS.HTTPClient

  @moduledoc """
  The built-in HTTP client.

  This client implements the `WorkOS.HTTPClient` behaviour.

  It's based on the [hackney](https://github.com/benoitc/hackney) Erlang HTTP client,
  which is an *optional dependency* of this library. If you wish to use another
  HTTP client, you'll have to implement your own `WorkOS.HTTPClient`. See the
  documentation for `WorkOS.HTTPClient` for more information.

  WorkOS SDK starts its own hackney pool called `:workos_pool`. If you need to set other
  [hackney configuration options](https://github.com/benoitc/hackney/blob/master/doc/hackney.md#request5)
  for things such as proxies, using your own pool, or response timeouts, the `:hackney_opts`
  configuration is passed directly to hackney for each request. See the configuration
  documentation in the `WorkOS` module.
  """

  @hackney_pool_name :workos_pool

  @impl true
  def child_spec do
    :hackney_pool.child_spec(
      @hackney_pool_name,
      timeout: WorkOS.Config.hackney_timeout(),
      max_connections: WorkOS.Config.max_hackney_connections()
    )
  end

  @impl true
  def post(url, headers, body) do
    hackney_opts =
      WorkOS.Config.hackney_opts()
      |> Keyword.put_new(:pool, @hackney_pool_name)

    case :hackney.request(:post, url, headers, body, [:with_body] ++ hackney_opts) do
      {:ok, _status, _headers, _body} = result -> result
      {:error, _reason} = error -> error
    end
  end
end
