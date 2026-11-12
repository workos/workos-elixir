# @oagen-ignore-file

defmodule WorkOS.WorkloadIdentity.Exchange do
  @moduledoc false

  # One jwt-bearer token exchange: call the identity token provider, POST the
  # form to the token endpoint, read the access token. Transport failures,
  # 429, 5xx and provider failures are retried with the SDK's own retry count
  # and backoff; the provider is called again and the form rebuilt for every
  # attempt. An OAuth error on any other status is final.
  #
  # `run/1` never raises and never returns either token in an error. The
  # caller (`WorkOS.WorkloadIdentity.Credentials`) bounds the whole run with
  # its deadline.

  alias WorkOS.WorkloadIdentityError

  @grant_type "urn:ietf:params:oauth:grant-type:jwt-bearer"
  @default_lifetime_seconds 300

  # Fixed for the exchange POST, whatever other Req options are in effect:
  # this module runs its own retry loop, a redirect is never followed, and no
  # Authorization header is ever sent. `post/2` also removes the deprecated
  # `:follow_redirects` option, which Req reads ahead of `:redirect`, and adds
  # a last request step that removes any `authorization` header, so it does
  # not matter which option or step put one there.
  @fixed_options [retry: false, redirect: false, decode_body: false, auth: nil]

  @redacted "[REDACTED]"

  @type result ::
          {:ok, access_token :: String.t(), lifetime_ms :: pos_integer()}
          | {:error, WorkloadIdentityError.t()}

  @spec run(map()) :: result()
  def run(config) do
    attempt(config, 0)
  rescue
    exception -> {:error, unexpected(exception.__struct__)}
  catch
    kind, _value -> {:error, unexpected(kind)}
  end

  defp attempt(config, retries) do
    case exchange_once(config) do
      {:retry, error, retry_after_ms} ->
        if retries < WorkOS.Client.default_max_retries() do
          config.sleep.(retry_after_ms || WorkOS.Client.retry_delay(retries))
          attempt(config, retries + 1)
        else
          {:error, error}
        end

      result ->
        result
    end
  end

  defp exchange_once(config) do
    with {:ok, assertion} <- assertion(config.identity_token_provider),
         {:ok, response} <- post(config, assertion) do
      read(response, assertion)
    end
  end

  # -- identity token provider ------------------------------------------------

  defp assertion(provider) do
    case call(provider) do
      {:ok, token} when is_binary(token) and token != "" ->
        {:ok, token}

      {:ok, _empty} ->
        provider_failed("the provider returned an empty token", :empty_token)

      {:error, reason} ->
        provider_failed(describe(reason), reason)

      _other ->
        provider_failed(
          "the provider did not return {:ok, token} or {:error, reason}",
          :invalid_return
        )
    end
  rescue
    exception -> provider_failed(Exception.message(exception), exception)
  catch
    kind, _value -> provider_failed("the provider stopped with a #{kind}", kind)
  end

  defp call(provider) when is_function(provider, 0), do: provider.()
  defp call({module, function, args}), do: apply(module, function, args)

  defp provider_failed(description, reason),
    do: {:retry, WorkloadIdentityError.new("provider_failed", description, reason), nil}

  # A provider's error is described only when it is already text. Other terms
  # are kept in `:reason` and never interpolated.
  defp describe(%{__exception__: true} = exception), do: Exception.message(exception)
  defp describe(reason) when is_binary(reason), do: reason
  defp describe(reason) when is_atom(reason), do: Atom.to_string(reason)
  defp describe(_reason), do: ""

  # -- token endpoint ---------------------------------------------------------

  defp post(config, assertion) do
    request =
      [
        method: :post,
        url: config.token_url,
        form: form(config, assertion),
        headers: [{"accept", "application/json"}, {"user-agent", WorkOS.Client.user_agent()}]
      ]
      |> Req.new()
      |> Req.merge(config.req_options)
      |> Req.merge(@fixed_options)
      |> Req.Request.delete_option(:follow_redirects)
      |> Req.Request.append_request_steps(
        workos_no_authorization: &Req.Request.delete_header(&1, "authorization")
      )

    case Req.request(request) do
      {:ok, response} ->
        {:ok, response}

      {:error, exception} ->
        {:retry, WorkloadIdentityError.new("exchange_failed", "", transport_reason(exception)),
         nil}
    end
  end

  # There is no client secret: the assertion is the credential.
  defp form(config, assertion) do
    fields = [
      grant_type: @grant_type,
      assertion: assertion,
      client_id: config.client_id,
      resource: config.resource
    ]

    if config.scope, do: fields ++ [scope: config.scope], else: fields
  end

  # The status is checked before the body: a 429 or 5xx is retried even when
  # its body has an OAuth error.
  defp read(%Req.Response{status: status} = response, assertion)
       when status == 429 or status in 500..599 do
    {code, description} = oauth_error(decode(response), assertion) || {"exchange_failed", ""}
    {:retry, WorkloadIdentityError.new(code, description), retry_after(response)}
  end

  defp read(%Req.Response{status: status} = response, assertion) do
    body = decode(response)
    oauth_error = oauth_error(body, assertion)

    cond do
      oauth_error ->
        {code, description} = oauth_error
        {:error, WorkloadIdentityError.new(code, description)}

      status in 300..399 ->
        {:error,
         WorkloadIdentityError.new(
           "exchange_failed",
           "the token endpoint answered with a redirect (HTTP #{status}), which is not followed"
         )}

      status == 200 ->
        access_token(body)

      true ->
        {:error,
         WorkloadIdentityError.new(
           "invalid_response",
           "the token endpoint returned HTTP #{status}"
         )}
    end
  end

  defp access_token(%{"access_token" => token} = body) when is_binary(token) and token != "",
    do: {:ok, token, lifetime_ms(body["expires_in"])}

  defp access_token(_body),
    do:
      {:error, WorkloadIdentityError.new("invalid_response", "the response had no access_token")}

  defp lifetime_ms(seconds) when is_number(seconds) and seconds > 0,
    do: max(trunc(seconds * 1000), 1)

  defp lifetime_ms(_absent_or_invalid), do: @default_lifetime_seconds * 1000

  defp decode(%Req.Response{body: body}) when is_binary(body) do
    case JSON.decode(body) do
      {:ok, %{} = decoded} -> decoded
      _other -> nil
    end
  end

  defp decode(_response), do: nil

  # The endpoint's own text goes into the error, so an endpoint that echoes
  # the assertion back must not be able to put it there.
  defp oauth_error(%{"error" => code} = body, assertion) when is_binary(code) and code != "",
    do: {scrub(code, assertion), scrub(body["error_description"], assertion)}

  defp oauth_error(_body, _assertion), do: nil

  defp scrub(text, assertion) when is_binary(text),
    do: String.replace(text, assertion, @redacted)

  defp scrub(_absent, _assertion), do: ""

  # `Retry-After` is honored on the statuses where Req honors it for API
  # requests: 429 and 503. Req raises on a value that is neither seconds nor
  # an HTTP date; such a header is ignored and the normal backoff applies.
  defp retry_after(%Req.Response{status: status} = response) when status in [429, 503] do
    Req.Response.get_retry_after(response)
  rescue
    _malformed -> nil
  end

  defp retry_after(_response), do: nil

  # Req's own transport errors carry a reason atom and nothing from the
  # request. Any other exception is reduced to its module name.
  defp transport_reason(%Req.TransportError{} = exception), do: exception
  defp transport_reason(%{__struct__: module}), do: module

  defp unexpected(what) do
    WorkloadIdentityError.new(
      "exchange_failed",
      "the token exchange stopped unexpectedly (#{inspect(what)})"
    )
  end
end
