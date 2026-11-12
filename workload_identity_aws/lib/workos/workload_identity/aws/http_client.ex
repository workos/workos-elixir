# @oagen-ignore-file

defmodule WorkOS.WorkloadIdentity.AWS.HTTPClient do
  @moduledoc false

  # Sends the request that `aws` has already built and signed, using `:httpc`
  # from OTP. `aws` ships adapters for hackney and Finch only; this one keeps
  # the package free of an HTTP client dependency.

  @behaviour AWS.HTTPClient

  @timeout_ms 10_000

  @impl AWS.HTTPClient
  def request(method, url, body, headers, _options) do
    {content_type, headers} = pop_content_type(headers)

    request =
      {String.to_charlist(url), Enum.map(headers, &to_charlists/1), content_type,
       IO.iodata_to_binary(body)}

    http_options =
      [timeout: @timeout_ms, connect_timeout: @timeout_ms, autoredirect: false] ++
        ssl_options(url)

    case :httpc.request(method, request, http_options, body_format: :binary) do
      {:ok, {{_version, status, _reason}, response_headers, response_body}} ->
        {:ok,
         %{
           status_code: status,
           headers: Enum.map(response_headers, fn {k, v} -> {to_string(k), to_string(v)} end),
           body: response_body
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # `:httpc` takes the content type apart from the other headers.
  defp pop_content_type(headers) do
    case Enum.split_with(headers, fn {name, _value} -> String.downcase(name) == "content-type" end) do
      {[{_name, content_type} | _], rest} -> {String.to_charlist(content_type), rest}
      {[], rest} -> {~c"application/octet-stream", rest}
    end
  end

  defp to_charlists({name, value}), do: {String.to_charlist(name), String.to_charlist(value)}

  # Verify the endpoint's certificate against the operating system's trust
  # store. OTP releases before 26 do not verify unless told to.
  defp ssl_options("https://" <> _rest) do
    [
      ssl: [
        verify: :verify_peer,
        cacerts: :public_key.cacerts_get(),
        depth: 10,
        customize_hostname_check: [
          match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
        ]
      ]
    ]
  end

  defp ssl_options(_url), do: []
end
