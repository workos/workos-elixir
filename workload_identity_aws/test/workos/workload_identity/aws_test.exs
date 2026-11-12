# @oagen-ignore-file

defmodule WorkOS.WorkloadIdentity.AWSTest do
  # The region tests change process-wide environment variables, so these
  # tests cannot run concurrently.
  use ExUnit.Case, async: false

  alias WorkOS.WorkloadIdentity.AWS, as: Provider
  alias WorkOS.WorkloadIdentity.AWS.Error
  alias WorkOS.WorkloadIdentity.AWS.HTTPClient
  alias WorkOS.WorkloadIdentity.AWS.StubHTTPClient
  alias WorkOS.WorkloadIdentity.TestServer

  @audience "https://api.workos.com"
  @region_envs ["AWS_REGION", "AWS_DEFAULT_REGION"]

  @success_xml """
  <GetWebIdentityTokenResponse xmlns="https://sts.amazonaws.com/doc/2011-06-15/">
    <GetWebIdentityTokenResult>
      <WebIdentityToken>aws-jwt</WebIdentityToken>
      <Expiration>2026-11-12T00:05:00Z</Expiration>
    </GetWebIdentityTokenResult>
    <ResponseMetadata>
      <RequestId>00000000-0000-0000-0000-000000000000</RequestId>
    </ResponseMetadata>
  </GetWebIdentityTokenResponse>
  """

  @access_denied_xml """
  <ErrorResponse xmlns="https://sts.amazonaws.com/doc/2011-06-15/">
    <Error>
      <Type>Sender</Type>
      <Code>AccessDenied</Code>
      <Message>User is not authorized to perform: sts:GetWebIdentityToken</Message>
    </Error>
    <RequestId>00000000-0000-0000-0000-000000000000</RequestId>
  </ErrorResponse>
  """

  setup do
    previous = Map.new(@region_envs, &{&1, System.get_env(&1)})

    on_exit(fn ->
      Enum.each(previous, fn
        {name, nil} -> System.delete_env(name)
        {name, value} -> System.put_env(name, value)
      end)
    end)

    Enum.each(@region_envs, &System.delete_env/1)
    :ok
  end

  # The one-call STS seam: records its arguments and returns `result`, in the
  # shape of `AWS.STS.get_web_identity_token/2`.
  defp sts_stub(result) do
    test = self()

    fn region, input ->
      send(test, {:sts, region, input})
      result
    end
  end

  defp issued(token) do
    body = %{
      "GetWebIdentityTokenResponse" => %{
        "GetWebIdentityTokenResult" => %{"WebIdentityToken" => token}
      }
    }

    {:ok, body, %{status_code: 200}}
  end

  defp access_denied do
    {:error, {:unexpected_response, %{status_code: 403, body: @access_denied_xml}}}
  end

  # The real `aws` client the provider builds, with only the HTTP layer
  # replaced.
  defp real_sts(response) do
    client =
      %{access_key_id: "AKIDEXAMPLE", secret_access_key: "secret", token: "session-token"}
      |> Provider.__client__("us-east-1")
      |> AWS.Client.put_http_client({StubHTTPClient, [test: self(), response: response]})

    fn "us-east-1", input -> AWS.STS.get_web_identity_token(client, input) end
  end

  test "WIF-AWS-01 calls STS GetWebIdentityToken with the audience and RS256 in the given region" do
    provider = Provider.__provider__(@audience, "us-east-1", sts_stub(issued("aws-jwt")))

    assert provider.() == {:ok, "aws-jwt"}

    assert_receive {:sts, "us-east-1", input}
    assert input == %{"Audience.member.1" => @audience, "SigningAlgorithm" => "RS256"}
    refute_receive {:sts, _region, _input}
  end

  test "WIF-AWS-01 the request goes to the regional STS endpoint, signed, with no duration" do
    sts = real_sts({:ok, %{status_code: 200, headers: [], body: @success_xml}})

    assert Provider.__provider__(@audience, "us-east-1", sts).() == {:ok, "aws-jwt"}

    assert_receive {:http, request}
    assert request.method == :post
    assert URI.parse(request.url).host == "sts.us-east-1.amazonaws.com"
    assert URI.parse(request.url).scheme == "https"

    assert URI.decode_query(request.body) == %{
             "Action" => "GetWebIdentityToken",
             "Version" => "2011-06-15",
             "Audience.member.1" => @audience,
             "SigningAlgorithm" => "RS256"
           }

    headers = Map.new(request.headers, fn {name, value} -> {String.downcase(name), value} end)
    assert headers["host"] == "sts.us-east-1.amazonaws.com"
    assert headers["authorization"] =~ "AWS4-HMAC-SHA256 Credential=AKIDEXAMPLE/"
    assert headers["authorization"] =~ "/us-east-1/sts/aws4_request"
    assert headers["x-amz-security-token"] == "session-token"
  end

  test "WIF-AWS-01 with no region available, building the provider is an error" do
    assert_raise ArgumentError, ~r/AWS region/, fn -> Provider.aws_sts(@audience) end

    assert_raise ArgumentError, ~r/AWS region/, fn ->
      Provider.__provider__(@audience, "", sts_stub(issued("aws-jwt")))
    end

    refute_receive {:sts, _region, _input}
  end

  test "WIF-AWS-01 the region falls back to AWS_REGION, then AWS_DEFAULT_REGION" do
    System.put_env("AWS_DEFAULT_REGION", "eu-west-1")

    assert Provider.__provider__(@audience, nil, sts_stub(issued("aws-jwt"))).() ==
             {:ok, "aws-jwt"}

    assert_receive {:sts, "eu-west-1", _input}

    System.put_env("AWS_REGION", "ap-southeast-2")

    assert Provider.__provider__(@audience, nil, sts_stub(issued("aws-jwt"))).() ==
             {:ok, "aws-jwt"}

    assert_receive {:sts, "ap-southeast-2", _input}

    # An explicit region wins over both.
    assert Provider.__provider__(@audience, "us-west-2", sts_stub(issued("aws-jwt"))).() ==
             {:ok, "aws-jwt"}

    assert_receive {:sts, "us-west-2", _input}
  end

  test "WIF-AWS-02 an STS error is a provider error that names the call and the AWS error code" do
    provider = Provider.__provider__(@audience, "us-east-1", sts_stub(access_denied()))

    assert {:error, %Error{message: message}} = provider.()
    assert message =~ "sts:GetWebIdentityToken"
    assert message =~ "AccessDenied"
    assert message =~ "403"
  end

  test "WIF-AWS-02 an access-denied response from STS is decoded into the same error" do
    sts = real_sts({:ok, %{status_code: 403, headers: [], body: @access_denied_xml}})

    assert {:error, %Error{message: message}} =
             Provider.__provider__(@audience, "us-east-1", sts).()

    assert message =~ "sts:GetWebIdentityToken"
    assert message =~ "AccessDenied"
  end

  test "WIF-AWS-02 an STS client that raises is a provider error that names the call" do
    sts = fn _region, _input -> raise "AccessDenied: SECRET-TOKEN-VALUE" end

    assert {:error, %Error{message: message} = error} =
             Provider.__provider__(@audience, "us-east-1", sts).()

    assert message =~ "sts:GetWebIdentityToken"
    refute message =~ "SECRET-TOKEN-VALUE"
    refute inspect(error) =~ "SECRET-TOKEN-VALUE"
  end

  test "WIF-AWS-02 the error never carries a response body" do
    body =
      "<ErrorResponse><Error><Code>Throttling</Code><Message>SECRET-TOKEN-VALUE</Message></Error></ErrorResponse>"

    sts = sts_stub({:error, {:unexpected_response, %{status_code: 400, body: body}}})

    assert {:error, %Error{message: message} = error} =
             Provider.__provider__(@audience, "us-east-1", sts).()

    assert message =~ "Throttling"
    refute inspect(error) =~ "SECRET-TOKEN-VALUE"
  end

  test "a response with no token is an error" do
    for result <- [issued(""), {:ok, %{}, %{status_code: 200}}, {:ok, nil, %{status_code: 200}}] do
      provider = Provider.__provider__(@audience, "us-east-1", sts_stub(result))

      assert {:error, %Error{message: message}} = provider.()
      assert message =~ "sts:GetWebIdentityToken"
    end
  end

  test "with no AWS credentials the provider fails without a request" do
    # The test configuration gives the credential chain no providers.
    assert {:error, %Error{message: message}} = Provider.aws_sts(@audience, "us-east-1").()
    assert message =~ "sts:GetWebIdentityToken"
    assert message =~ "no AWS credentials"
  end

  test "the audience is required" do
    assert_raise FunctionClauseError, fn -> Provider.aws_sts("", "us-east-1") end
  end

  describe "the :httpc adapter" do
    test "sends the method, headers, content type and body it is given, and returns the response" do
      server = TestServer.start([{200, [{"x-amzn-requestid", "abc"}], "<ok/>"}])

      headers = [
        {"Host", "sts.us-east-1.amazonaws.com"},
        {"Content-Type", "application/x-www-form-urlencoded"},
        {"Authorization", "AWS4-HMAC-SHA256 Credential=AKIDEXAMPLE/..."},
        {"X-Amz-Date", "20261112T000000Z"}
      ]

      assert {:ok, %{status_code: 200, body: "<ok/>", headers: response_headers}} =
               HTTPClient.request(:post, server.url <> "/", ["Action=", "X"], headers, [])

      assert {"x-amzn-requestid", "abc"} in response_headers

      ref = server.ref
      assert_receive {:request, ^ref, request}
      assert request.method == "POST"
      assert request.target == "/"
      assert request.body == "Action=X"
      assert request.headers["host"] == "sts.us-east-1.amazonaws.com"
      assert request.headers["content-type"] == "application/x-www-form-urlencoded"
      assert request.headers["authorization"] == "AWS4-HMAC-SHA256 Credential=AKIDEXAMPLE/..."
      assert request.headers["x-amz-date"] == "20261112T000000Z"
    end

    test "does not follow a redirect" do
      elsewhere = TestServer.start([{200, [], "<ok/>"}])
      server = TestServer.start([{307, [{"location", elsewhere.url <> "/"}], ""}])

      assert {:ok, %{status_code: 307}} =
               HTTPClient.request(
                 :post,
                 server.url <> "/",
                 "a=b",
                 [{"Content-Type", "text/plain"}],
                 []
               )

      ref = elsewhere.ref
      refute_receive {:request, ^ref, _request}
    end

    test "returns a connection failure as an error" do
      # Port 1 on loopback refuses connections.
      assert {:error, _reason} =
               HTTPClient.request(:post, "http://127.0.0.1:1/", "a=b", [], [])
    end
  end
end
