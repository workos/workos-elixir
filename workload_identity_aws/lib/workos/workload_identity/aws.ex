# @oagen-ignore-file

defmodule WorkOS.WorkloadIdentity.AWS do
  @moduledoc """
  Identity token provider for AWS.

  `aws_sts/2` returns a provider: a zero-arity function that calls STS
  `GetWebIdentityToken` for the given audience, signed with `RS256`, on the
  regional STS endpoint, and returns `{:ok, token}` or
  `{:error, %WorkOS.WorkloadIdentity.AWS.Error{}}`.

  The caller's AWS credentials come from the `aws_credentials` application,
  which resolves them from the environment (Lambda), shared credential files,
  ECS task roles, EKS (Pod Identity and IAM roles for service accounts) and
  EC2 instance profiles, and refreshes them before they expire. The request is
  built and signed by the `aws` package.

  The account must have outbound identity federation enabled, and the caller's
  IAM policy must allow `sts:GetWebIdentityToken`.

      provider = WorkOS.WorkloadIdentity.AWS.aws_sts("https://api.workos.com", "us-east-1")

      {:ok, credentials} =
        WorkOS.WorkloadIdentity.Credentials.start_link(
          client_id: "client_...",
          environment_id: "environment_...",
          token_url: "https://.../oauth2/token",
          identity_token_provider: provider
        )

  The provider holds no cache and does not retry; the WorkOS SDK retries it as
  part of the token exchange. The token is never logged and never placed in
  an error.
  """

  alias WorkOS.WorkloadIdentity.AWS.HTTPClient

  defmodule Error do
    @moduledoc """
    Returned when STS did not issue a web identity token.
    """

    defexception [:message]

    @type t :: %__MODULE__{message: String.t()}
  end

  @signing_algorithm "RS256"
  @region_envs ["AWS_REGION", "AWS_DEFAULT_REGION"]

  @type provider :: (-> {:ok, String.t()} | {:error, Error.t()})

  # The one call the provider makes, in the shape of
  # `AWS.STS.get_web_identity_token/2`. Tests replace it.
  @typep sts :: (region :: String.t(), input :: map() -> {:ok, map(), term()} | {:error, term()})

  @doc """
  Returns an identity token provider for the given audience.

  The audience is required. The conventional value is `https://api.workos.com`.

  The region is optional when one can be resolved: from `AWS_REGION`, then
  `AWS_DEFAULT_REGION`, then the region the credential chain reports (for
  example from the EC2 instance metadata service). When no region is found,
  this function raises `ArgumentError`. STS is always called on the regional
  endpoint for that region, never on the global endpoint.
  """
  @spec aws_sts(String.t(), String.t() | nil) :: provider()
  def aws_sts(audience, region \\ nil) do
    __provider__(audience, region, &get_web_identity_token/2)
  end

  # The STS call is a test seam. It is not a public option.
  @doc false
  @spec __provider__(String.t(), String.t() | nil, sts()) :: provider()
  def __provider__(audience, region, sts)
      when is_binary(audience) and audience != "" and is_function(sts, 2) do
    region = non_empty(region) || resolve_region()

    if is_nil(region) do
      raise ArgumentError,
            "aws_sts/2 could not find an AWS region. Pass one as the second argument, " <>
              "or set AWS_REGION or AWS_DEFAULT_REGION."
    end

    # `Audience` is a list in the STS API. The AWS query protocol writes list
    # members as `Audience.member.N`, so the key is spelled out here.
    # `DurationSeconds` is left unset so STS applies its default.
    input = %{"Audience.member.1" => audience, "SigningAlgorithm" => @signing_algorithm}

    fn -> request(sts, region, input) end
  end

  defp request(sts, region, input) do
    case sts.(region, input) do
      {:ok, body, _response} -> token(body)
      {:error, reason} -> error(describe(reason))
    end
  rescue
    exception -> error("the STS client raised #{inspect(exception.__struct__)}")
  end

  defp token(%{
         "GetWebIdentityTokenResponse" => %{
           "GetWebIdentityTokenResult" => %{"WebIdentityToken" => token}
         }
       })
       when is_binary(token) and token != "",
       do: {:ok, token}

  defp token(_body), do: error("the response had no WebIdentityToken")

  defp get_web_identity_token(region, input) do
    case credentials() do
      %{access_key_id: _, secret_access_key: _} = credentials ->
        credentials |> __client__(region) |> AWS.STS.get_web_identity_token(input)

      _none ->
        {:error, :no_credentials}
    end
  end

  # An `aws` client for the regional STS endpoint, from one set of credentials
  # out of the chain. Building it is a struct literal: it holds no connection,
  # so it is rebuilt per call to pick up rotated credentials.
  @doc false
  @spec __client__(map(), String.t()) :: AWS.Client.t()
  def __client__(%{access_key_id: access_key_id, secret_access_key: secret} = credentials, region) do
    access_key_id
    |> AWS.Client.create(secret, session_token(credentials), region)
    |> AWS.Client.put_http_client({HTTPClient, []})
  end

  # The cached credentials, or nil. `aws_credentials` refreshes them itself.
  defp credentials do
    case :aws_credentials.get_credentials() do
      %{} = credentials -> credentials
      _undefined -> nil
    end
  catch
    :exit, _reason -> nil
  end

  defp session_token(%{token: token}) when is_binary(token), do: token
  defp session_token(_credentials), do: nil

  defp resolve_region do
    Enum.find_value(@region_envs, &non_empty(System.get_env(&1))) ||
      case credentials() do
        %{region: region} when is_binary(region) -> non_empty(region)
        _none -> nil
      end
  end

  defp non_empty(value) when value in [nil, ""], do: nil
  defp non_empty(value), do: value

  # Only the AWS error code, the HTTP status or the failure kind is reported.
  # Response bodies and raw reasons are never interpolated.
  defp describe({:unexpected_response, %{status_code: status} = response}) do
    case error_code(response) do
      nil -> "STS returned HTTP #{status}"
      code -> "STS returned #{code} (HTTP #{status})"
    end
  end

  defp describe(:no_credentials), do: "no AWS credentials were found"
  defp describe(:timeout), do: "timeout"
  defp describe({:failed_connect, _info}), do: "connection failed"
  defp describe(_reason), do: "the request failed"

  defp error_code(%{body: body}) when is_binary(body) do
    case Regex.run(~r{<Code>([A-Za-z0-9._:-]+)</Code>}, body) do
      [_match, code] -> code
      nil -> nil
    end
  end

  defp error_code(_response), do: nil

  defp error(detail) do
    {:error,
     %Error{
       message:
         "sts:GetWebIdentityToken failed: #{detail}. Check that the caller's IAM policy " <>
           "allows sts:GetWebIdentityToken and that outbound identity federation is " <>
           "enabled for the account."
     }}
  end
end
