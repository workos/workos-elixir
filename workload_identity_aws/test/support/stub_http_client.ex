# @oagen-ignore-file

defmodule WorkOS.WorkloadIdentity.AWS.StubHTTPClient do
  @moduledoc false

  # An `AWS.HTTPClient` for tests. It reports the request `aws` built and
  # signed to the test process and answers with a canned response, so the
  # real request-building and response-decoding code runs with no network.

  @behaviour AWS.HTTPClient

  @impl AWS.HTTPClient
  def request(method, url, body, headers, options) do
    send(
      Keyword.fetch!(options, :test),
      {:http, %{method: method, url: url, body: IO.iodata_to_binary(body), headers: headers}}
    )

    Keyword.fetch!(options, :response)
  end
end
