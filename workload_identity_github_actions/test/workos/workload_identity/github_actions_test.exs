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

  # "The GitHub Actions OIDC token endpoint at host:port", for the server.
  defp endpoint(server) do
    %URI{host: host, port: port} = URI.parse(server.url)
    "The GitHub Actions OIDC token endpoint at #{host}:#{port}"
  end

  # A loopback port that accepts each connection, reads what was sent and
  # closes without answering. It is linked to the test process.
  defp closing_server do
    {:ok, listener} =
      :gen_tcp.listen(0, [:binary, active: false, reuseaddr: true, ip: {127, 0, 0, 1}])

    {:ok, port} = :inet.port(listener)
    spawn_link(fn -> close_each(listener) end)
    %{url: "http://127.0.0.1:#{port}"}
  end

  defp close_each(listener) do
    with {:ok, socket} <- :gen_tcp.accept(listener) do
      _request = :gen_tcp.recv(socket, 0, 5_000)
      :ok = :gen_tcp.close(socket)
      close_each(listener)
    end
  end

  # -- TLS ----------------------------------------------------------------------
  #
  # Certificates are made for each test. No key or certificate is stored in
  # the repository, and no host other than this one is contacted.

  defp key, do: :public_key.generate_key({:namedCurve, :secp256r1})

  # A server certificate with its key, and the root it was issued under.
  # Options: `:host`, the DNS name in the certificate (default `localhost`),
  # and `:validity`, a `{from, to}` pair of dates (default: valid now).
  defp chain(opts \\ []) do
    host = opts |> Keyword.get(:host, "localhost") |> String.to_charlist()
    subject_alt_name = {:Extension, {2, 5, 29, 17}, false, [dNSName: host]}

    data =
      :public_key.pkix_test_data(%{
        server_chain: %{
          root: [key: key(), digest: :sha256],
          intermediates: [],
          peer:
            [key: key(), digest: :sha256, extensions: [subject_alt_name]] ++
              Keyword.take(opts, [:validity])
        },
        client_chain: %{root: [key: key()], intermediates: [], peer: [key: key()]}
      })

    %{
      cert: data.server_config[:cert],
      key: data.server_config[:key],
      roots: data.client_config[:cacerts]
    }
  end

  defp self_signed do
    key = key()
    %{cert: cert} = :public_key.pkix_test_root_cert(~c"self-signed", key: key, digest: :sha256)
    %{cert: cert, key: {:ECPrivateKey, :public_key.der_encode(:ECPrivateKey, key)}}
  end

  # Makes `roots` the only trusted roots until the test ends. The provider
  # verifies against the operating system's trust store, which `:public_key`
  # keeps for the whole VM once it is loaded, so it is cleared afterwards.
  defp trust(roots) do
    path =
      Path.join(System.tmp_dir!(), "workos-gha-roots-#{System.unique_integer([:positive])}.pem")

    File.write!(
      path,
      :public_key.pem_encode(Enum.map(roots, &{:Certificate, &1, :not_encrypted}))
    )

    on_exit(fn -> :public_key.cacerts_clear() end)

    try do
      :ok = :public_key.cacerts_load(String.to_charlist(path))
    after
      File.rm(path)
    end
  end

  # An HTTPS server on a loopback port with the given certificate. After a
  # completed handshake it reads the request, sends it to the test as
  # `{:tls_request, ref, request}` and answers with a token. A handshake the
  # client gives up on is skipped. It is linked to the test process.
  defp tls_server(%{cert: cert, key: key}) do
    test = self()
    ref = make_ref()

    {:ok, listener} =
      :ssl.listen(0, [
        :binary,
        cert: cert,
        key: key,
        active: false,
        reuseaddr: true,
        ip: {127, 0, 0, 1},
        log_level: :none
      ])

    {:ok, {_address, port}} = :ssl.sockname(listener)
    spawn_link(fn -> tls_accept(listener, test, ref) end)
    %{url: "https://localhost:#{port}", ref: ref}
  end

  defp tls_accept(listener, test, ref) do
    with {:ok, socket} <- :ssl.transport_accept(listener) do
      with {:ok, tls} <- :ssl.handshake(socket, 5_000),
           {:ok, request} <- :ssl.recv(tls, 0, 5_000) do
        send(test, {:tls_request, ref, request})
        body = JSON.encode!(%{"value" => "gha-jwt"})

        :ok =
          :ssl.send(tls, [
            "HTTP/1.1 200 OK\r\ncontent-length: #{byte_size(body)}\r\n",
            "connection: close\r\n\r\n",
            body
          ])

        :ssl.close(tls)
      end

      tls_accept(listener, test, ref)
    end
  end

  # Calls the provider against an HTTPS server that must be refused, and
  # returns the error. The request token never leaves the client.
  defp refused_by_tls(server) do
    configure(server, "SECRET-REQUEST-TOKEN")

    assert {:error, %Error{} = error} = GitHubActions.github_actions(@audience).()
    refute inspect(error) =~ "SECRET-REQUEST-TOKEN"

    ref = server.ref
    refute_receive {:tls_request, ^ref, _request}
    error
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

    assert message ==
             "The GitHub Actions OIDC token endpoint at 127.0.0.1:1 could not be reached: " <>
               "the connection was refused (econnrefused)."

    refute inspect(error) =~ "SECRET-REQUEST-TOKEN"
  end

  test "a server that closes the connection without answering is named as that" do
    server = closing_server()
    configure(server)

    assert {:error, %Error{message: message}} = GitHubActions.github_actions(@audience).()

    assert message ==
             endpoint(server) <>
               " could not be reached: the server closed the connection (socket_closed_remotely)."
  end

  test "a request URL with no host gets no host in the message" do
    System.put_env(@url_env, "not-a-url")
    System.put_env(@token_env, "gha-request-token")

    assert {:error, %Error{message: message}} = GitHubActions.github_actions(@audience).()

    assert message ==
             "The GitHub Actions OIDC token endpoint could not be reached: the request failed."
  end

  test "only the host and port of the request URL are named" do
    System.put_env(@url_env, "http://user:SECRET-USERINFO@127.0.0.1:1/SECRET-PATH?k=SECRET-QUERY")
    System.put_env(@token_env, "gha-request-token")

    assert {:error, %Error{message: message}} = GitHubActions.github_actions(@audience).()

    assert message ==
             "The GitHub Actions OIDC token endpoint at 127.0.0.1:1 could not be reached: " <>
               "the connection was refused (econnrefused)."
  end

  describe "an https endpoint" do
    # The TLS client logs each alert it sends.
    @describetag :capture_log

    test "with a certificate from a trusted authority, for its host name, gets the token" do
      chain = chain()
      trust(chain.roots)
      server = tls_server(chain)
      configure(server)

      assert GitHubActions.github_actions(@audience).() == {:ok, "gha-jwt"}

      ref = server.ref
      assert_receive {:tls_request, ^ref, request}
      assert request =~ "authorization: Bearer gha-request-token\r\n"
    end

    test "with a certificate from an authority that is not trusted is refused, and says so" do
      trust(chain().roots)
      server = tls_server(chain())

      assert refused_by_tls(server).message ==
               endpoint(server) <>
                 " could not be reached: the server's certificate is not from a trusted " <>
                 "certificate authority (unknown_ca)."
    end

    test "with a certificate for another host name is refused, and says so" do
      chain = chain(host: "elsewhere.test")
      trust(chain.roots)
      server = tls_server(chain)

      assert refused_by_tls(server).message ==
               endpoint(server) <>
                 " could not be reached: the server's certificate is for another host name " <>
                 "(hostname_check_failed)."
    end

    test "with a certificate that has expired, or is not valid yet, is refused, and says so" do
      # OTP sends the same alert for both.
      for validity <- [{{2000, 1, 1}, {2000, 1, 2}}, {{3000, 1, 1}, {3000, 1, 2}}] do
        chain = chain(validity: validity)
        trust(chain.roots)
        server = tls_server(chain)

        assert refused_by_tls(server).message ==
                 endpoint(server) <>
                   " could not be reached: the server's certificate has expired or is not " <>
                   "valid yet (certificate_expired)."
      end
    end

    test "with a self-signed certificate is refused, and says so" do
      trust(chain().roots)
      server = tls_server(self_signed())

      # OTP 25 sends this alert with no word for the cause.
      why =
        if System.otp_release() == "25",
          do: "the TLS handshake failed (bad_certificate)",
          else: "the server's certificate is self-signed (selfsigned_peer)"

      assert refused_by_tls(server).message ==
               endpoint(server) <> " could not be reached: " <> why <> "."
    end
  end

  test "every kind of failure gets fixed words, and nothing of the raw reason is copied" do
    connect = fn reason ->
      {:failed_connect, [{:to_address, {~c"host.test", 443}}, {:inet, [:inet], reason}]}
    end

    alert = fn name, text -> connect.({:tls_alert, {name, String.to_charlist(text)}}) end

    for {reason, words} <- [
          {connect.(:nxdomain), "the host name could not be resolved (nxdomain)"},
          {{:failed_connect, [{:inet6, [:inet6], :nxdomain}]},
           "the host name could not be resolved (nxdomain)"},
          {connect.(:econnrefused), "the connection was refused (econnrefused)"},
          {:timeout, "the request timed out (timeout)"},
          {connect.(:timeout), "the request timed out (timeout)"},
          {connect.(:etimedout), "the request timed out (etimedout)"},
          {:socket_closed_remotely, "the server closed the connection (socket_closed_remotely)"},
          {connect.(:closed), "the server closed the connection (closed)"},
          {connect.(:ehostunreach), "the connection failed (ehostunreach)"},
          {alert.(:unknown_ca, "TLS client: generated CLIENT ALERT: Fatal - Unknown CA\n"),
           "the server's certificate is not from a trusted certificate authority (unknown_ca)"},
          {alert.(:certificate_expired, "TLS client: Fatal - Certificate Expired\n"),
           "the server's certificate has expired or is not valid yet (certificate_expired)"},
          # A host name mismatch comes under either alert, by OTP release.
          {alert.(
             :handshake_failure,
             "Fatal - Handshake Failure\n {bad_cert,hostname_check_failed}"
           ), "the server's certificate is for another host name (hostname_check_failed)"},
          {alert.(
             :bad_certificate,
             "Fatal - Bad Certificate\n {bad_cert,{hostname_check_failed,{requested,\"SECRET\"}}}"
           ), "the server's certificate is for another host name (hostname_check_failed)"},
          {alert.(:bad_certificate, "Fatal - Bad Certificate\n selfsigned_peer"),
           "the server's certificate is self-signed (selfsigned_peer)"},
          {alert.(:protocol_version, "SECRET"), "the TLS handshake failed (protocol_version)"},
          {connect.({:tls_alert, ~c"an alert in another form, SECRET"}),
           "the TLS handshake failed"},
          {connect.({:options, {:cacertfile, ~c"SECRET"}}), "the connection failed"},
          {{:failed_connect, [{:to_address, {~c"host.test", 443}}]}, "the connection failed"},
          # What :httpc returns for a header value it cannot encode.
          {{:invalid_header, {~c"authorization", ~c"Bearer SECRET"}}, "the request failed"},
          {:invalid_uri, "the request failed"}
        ] do
      assert GitHubActions.__describe__(reason) == words
    end
  end

  test "a request token that is not visible ASCII is refused before any request is made" do
    server = TestServer.start([json(%{"value" => "gha-jwt"})])

    for token <- [
          "SECRET-REQUEST-TOKEN\n",
          "SECRET-REQUEST-TOKEN\r\n",
          "SECRET-REQUEST-TOKEN\r\nx-injected: yes",
          "SECRET-REQUEST-TOKEN\nx-injected: yes",
          "SECRET-REQUEST\tTOKEN",
          "SECRET-REQUEST TOKEN",
          " SECRET-REQUEST-TOKEN",
          "SECRET-REQUEST-TOKEN\x7F",
          "SECRET-REQUEST-TÖKEN"
        ] do
      configure(server, token)

      assert {:error, %Error{message: message} = error} =
               GitHubActions.github_actions(@audience).()

      assert message ==
               "ACTIONS_ID_TOKEN_REQUEST_TOKEN contains a character that is not allowed in an " <>
                 "HTTP header, such as a line break. GitHub Actions sets this variable; pass " <>
                 "it to the program unchanged."

      refute inspect(error) =~ "SECRET"
    end

    ref = server.ref
    refute_receive {:request, ^ref, _request}
  end

  test "a request token of visible ASCII is sent as it is" do
    token = for byte <- 0x21..0x7E, into: "", do: <<byte>>
    server = TestServer.start([json(%{"value" => "gha-jwt"})])
    configure(server, token)

    assert GitHubActions.github_actions(@audience).() == {:ok, "gha-jwt"}

    ref = server.ref
    assert_receive {:request, ^ref, request}
    assert request.headers["authorization"] == "Bearer " <> token
  end

  test "the audience is required" do
    assert_raise FunctionClauseError, fn -> GitHubActions.github_actions("") end
  end
end
