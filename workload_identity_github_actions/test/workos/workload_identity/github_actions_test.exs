# @oagen-ignore-file

defmodule WorkOS.WorkloadIdentity.GitHubActionsTest do
  # The provider reads process-wide environment variables, so these tests
  # cannot run concurrently.
  use ExUnit.Case, async: false

  alias WorkOS.WorkloadIdentity.GitHubActions
  alias WorkOS.WorkloadIdentity.GitHubActions.Error
  alias WorkOS.WorkloadIdentity.TestServer

  @url_env "ACTIONS_ID_TOKEN_REQUEST_URL"
  @token_env "ACTIONS_ID_TOKEN_REQUEST_TOKEN"
  @audience "https://api.workos.com"

  setup do
    previous = Map.new([@url_env, @token_env], &{&1, System.get_env(&1)})

    on_exit(fn ->
      Enum.each(previous, fn
        {name, nil} -> System.delete_env(name)
        {name, value} -> System.put_env(name, value)
      end)
    end)

    System.delete_env(@url_env)
    System.delete_env(@token_env)
    :ok
  end

  defp json(value), do: {200, [{"content-type", "application/json"}], JSON.encode!(value)}

  defp configure(server, token \\ "gha-request-token") do
    System.put_env(@url_env, server.url <> "/token?api-version=2.0")
    System.put_env(@token_env, token)
  end

  test "WIF-GHA-01 GETs the request URL with the encoded audience appended and returns .value" do
    server = TestServer.start([json(%{"value" => "gha-jwt"})])
    configure(server)

    assert GitHubActions.github_actions(@audience).() == {:ok, "gha-jwt"}

    ref = server.ref
    assert_receive {:request, ^ref, request}
    assert request.method == "GET"
    assert request.target == "/token?api-version=2.0&audience=https%3A%2F%2Fapi.workos.com"
    assert request.headers["authorization"] == "Bearer gha-request-token"
    assert request.headers["accept"] == "application/json"
    refute_receive {:request, ^ref, _second}
  end

  test "WIF-GHA-01 reads the environment on every call, not when the provider is built" do
    provider = GitHubActions.github_actions(@audience)

    server = TestServer.start([json(%{"value" => "gha-jwt"})])
    configure(server)

    assert provider.() == {:ok, "gha-jwt"}
  end

  test "WIF-GHA-01 percent-encodes an audience that has reserved characters" do
    server = TestServer.start([json(%{"value" => "gha-jwt"})])
    configure(server)

    assert GitHubActions.github_actions("urn:workos:api/v1 test").() == {:ok, "gha-jwt"}

    ref = server.ref
    assert_receive {:request, ^ref, request}
    assert request.target == "/token?api-version=2.0&audience=urn%3Aworkos%3Aapi%2Fv1%20test"
  end

  test "WIF-GHA-02 a missing request URL fails with the permissions hint and makes no request" do
    server = TestServer.start([json(%{"value" => "gha-jwt"})])
    System.put_env(@token_env, "gha-request-token")

    assert {:error, %Error{message: message}} = GitHubActions.github_actions(@audience).()
    assert message =~ "permissions: id-token: write"

    ref = server.ref
    refute_receive {:request, ^ref, _request}
  end

  test "WIF-GHA-02 a missing request token fails with the permissions hint and makes no request" do
    server = TestServer.start([json(%{"value" => "gha-jwt"})])
    System.put_env(@url_env, server.url <> "/token?api-version=2.0")

    assert {:error, %Error{message: message}} = GitHubActions.github_actions(@audience).()
    assert message =~ "permissions: id-token: write"

    ref = server.ref
    refute_receive {:request, ^ref, _request}
  end

  test "WIF-GHA-02 an empty variable counts as missing" do
    System.put_env(@url_env, "")
    System.put_env(@token_env, "")

    assert {:error, %Error{message: message}} = GitHubActions.github_actions(@audience).()
    assert message =~ "permissions: id-token: write"
  end

  test "a non-200 status is an error that names the status and not the request token" do
    server = TestServer.start([{404, [], "not found"}])
    configure(server, "SECRET-REQUEST-TOKEN")

    assert {:error, %Error{message: message} = error} = GitHubActions.github_actions(@audience).()
    assert message =~ "404"
    refute message =~ "SECRET-REQUEST-TOKEN"
    refute inspect(error) =~ "SECRET-REQUEST-TOKEN"
  end

  test "a response with no value, an empty value or a body that is not JSON is an error" do
    for response <- [json(%{}), json(%{"value" => ""}), {200, [], ""}, {200, [], "not json"}] do
      server = TestServer.start([response])
      configure(server)

      assert {:error, %Error{message: message}} = GitHubActions.github_actions(@audience).()
      assert message =~ "value"
    end
  end

  test "a redirect is not followed" do
    elsewhere = TestServer.start([json(%{"value" => "gha-jwt"})])
    server = TestServer.start([{302, [{"location", elsewhere.url <> "/token"}], ""}])
    configure(server)

    assert {:error, %Error{message: message}} = GitHubActions.github_actions(@audience).()
    assert message =~ "302"

    ref = elsewhere.ref
    refute_receive {:request, ^ref, _request}
  end

  test "a connection failure is an error that does not carry the request token" do
    server = TestServer.start([json(%{"value" => "gha-jwt"})])
    # Port 1 on loopback refuses connections.
    System.put_env(@url_env, String.replace(server.url, ~r/:\d+$/, ":1") <> "/token")
    System.put_env(@token_env, "SECRET-REQUEST-TOKEN")

    assert {:error, %Error{message: message} = error} = GitHubActions.github_actions(@audience).()
    assert message =~ "could not be reached"
    refute inspect(error) =~ "SECRET-REQUEST-TOKEN"
  end

  test "the audience is required" do
    assert_raise FunctionClauseError, fn -> GitHubActions.github_actions("") end
  end
end
