# @oagen-ignore-file

defmodule WorkOS.WorkloadIdentity.GCPTest do
  use ExUnit.Case, async: true

  alias WorkOS.WorkloadIdentity.GCP
  alias WorkOS.WorkloadIdentity.GCP.Error
  alias WorkOS.WorkloadIdentity.TestServer

  @audience "https://api.workos.com"
  @identity_path "/computeMetadata/v1/instance/service-accounts/default/identity"

  # `GCP.__provider__/2` is `gcp_metadata/1` with the metadata base URL
  # pointed at the mock.
  defp provider(server, audience \\ @audience), do: GCP.__provider__(audience, server.url)

  test "WIF-GCP-01 GETs the identity URL with the encoded audience, format=full and the metadata header" do
    server = TestServer.start([{200, [], "gcp-jwt\n"}])

    assert provider(server).() == {:ok, "gcp-jwt"}

    ref = server.ref
    assert_receive {:request, ^ref, request}
    assert request.method == "GET"

    assert request.target ==
             @identity_path <> "?audience=https%3A%2F%2Fapi.workos.com&format=full"

    assert request.headers["metadata-flavor"] == "Google"
    refute_receive {:request, ^ref, _second}
  end

  test "WIF-GCP-01 percent-encodes an audience that has reserved characters" do
    server = TestServer.start([{200, [], "gcp-jwt"}])

    assert provider(server, "urn:workos:api/v1 test").() == {:ok, "gcp-jwt"}

    ref = server.ref
    assert_receive {:request, ^ref, request}

    assert request.target ==
             @identity_path <> "?audience=urn%3Aworkos%3Aapi%2Fv1%20test&format=full"
  end

  test "WIF-GCP-02 a non-200 status is an error that names the status" do
    server = TestServer.start([{404, [], "not found"}])

    assert {:error, %Error{message: message}} = provider(server).()
    assert message =~ "404"
  end

  test "WIF-GCP-02 an empty body is an error" do
    for body <- ["", " \n"] do
      server = TestServer.start([{200, [], body}])

      assert {:error, %Error{message: message}} = provider(server).()
      assert message =~ "empty"
    end
  end

  test "WIF-GCP-02 a redirect is an error and is not followed" do
    elsewhere = TestServer.start([{200, [], "gcp-jwt"}])
    server = TestServer.start([{302, [{"location", elsewhere.url <> @identity_path}], ""}])

    assert {:error, %Error{message: message}} = provider(server).()
    assert message =~ "302"

    ref = elsewhere.ref
    refute_receive {:request, ^ref, _request}
  end

  test "a connection failure is an error" do
    # Port 1 on loopback refuses connections.
    assert {:error, %Error{message: message}} =
             GCP.__provider__(@audience, "http://127.0.0.1:1").()

    assert message =~ "could not be reached"
  end

  test "the request never goes through a proxy the application gave :httpc" do
    # The default :httpc profile is shared with the application. Give it a
    # proxy: a listener that reports any connection and closes it.
    {:ok, proxy} = :gen_tcp.listen(0, [:binary, active: false, ip: {127, 0, 0, 1}])
    {:ok, proxy_port} = :inet.port(proxy)
    test = self()

    spawn_link(fn ->
      with {:ok, socket} <- :gen_tcp.accept(proxy) do
        send(test, :proxy_contacted)
        :gen_tcp.close(socket)
      end
    end)

    :ok = :httpc.set_options(proxy: {{~c"127.0.0.1", proxy_port}, []})

    # `:httpc` cannot take a proxy off a profile again, so restart the profile.
    on_exit(fn ->
      :ok = :inets.stop(:httpc, :default)
      {:ok, _pid} = :inets.start(:httpc, profile: :default)
    end)

    server = TestServer.start([{200, [], "gcp-jwt"}])

    assert provider(server).() == {:ok, "gcp-jwt"}

    ref = server.ref
    assert_receive {:request, ^ref, _request}
    refute_receive :proxy_contacted
  end

  test "the audience is required" do
    assert_raise FunctionClauseError, fn -> GCP.gcp_metadata("") end
  end

  test "gcp_metadata/1 returns a zero-arity provider" do
    assert is_function(GCP.gcp_metadata(@audience), 0)
  end
end
