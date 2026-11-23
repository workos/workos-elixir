# @oagen-ignore-file

defmodule WorkOS.ClientSecretTest do
  # `WorkOS.Client.put_client_secret/3`: what a request that sends the API key
  # as the client secret gets from each kind of client. No test touches the
  # network: the token endpoint and the API are function plugs that tell the
  # test when they are reached.
  use ExUnit.Case, async: true

  alias WorkOS.SSO.PKCE
  alias WorkOS.WorkloadIdentity.Credentials

  @workload_identity_message "authenticate_with_password needs an API key: this request " <>
                               "sends it as the client secret. A client that authenticates " <>
                               "with workload identity has no API key, so use a client " <>
                               "built with one for this call."

  defp key_client, do: WorkOS.Client.new(api_key: "sk_test_key", client_id: "client_123")

  # The client a `WorkOS.PublicClient` wraps, with the API replaced by a plug
  # that hands each request to the test.
  defp public_client(responses \\ %{}) do
    %WorkOS.Client{
      WorkOS.PublicClient.new("client_123").client
      | req_options: [plug: api_plug(responses)]
    }
  end

  # A client that authenticates with workload identity credentials, and the
  # credentials process behind it. The provider, the token endpoint and the
  # API each tell the test when they are reached.
  defp workload_identity_client do
    test = self()

    {:ok, credentials} =
      Credentials.start_link(
        client_id: "client_wif_test",
        token_url: "https://auth.wif.test/oauth2/token",
        identity_token_provider: fn ->
          send(test, :provider_invoked)
          {:ok, "assertion-1"}
        end,
        req_options: [
          plug: fn conn ->
            send(test, :exchange_requested)
            Req.Test.json(conn, %{"access_token" => "access-1", "expires_in" => 300})
          end
        ]
      )

    client =
      WorkOS.Client.new(
        credentials: credentials,
        client_id: "client_wif_test",
        req_options: [plug: api_plug()]
      )

    {client, credentials}
  end

  # Answers with the body registered for the request path, or `{}`.
  defp api_plug(responses \\ %{}) do
    test = self()

    fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      send(test, {:api_requested, conn.request_path, body})
      Req.Test.json(conn, Map.get(responses, conn.request_path, %{}))
    end
  end

  defp put_client_secret(params, client, function \\ "authenticate_with_password"),
    do: WorkOS.Client.put_client_secret(params, client, function)

  describe "put_client_secret/3" do
    test "a client with an API key sends the key as the client secret" do
      assert put_client_secret(%{"code" => "code_123"}, key_client()) ==
               %{"code" => "code_123", "client_secret" => "sk_test_key"}
    end

    test "a client_secret the caller passed is kept, whatever the client" do
      params = %{"code" => "code_123", "client_secret" => "sk_passed"}
      {workload_identity_client, _credentials} = workload_identity_client()

      assert put_client_secret(params, key_client()) == params
      assert put_client_secret(params, public_client()) == params
      assert put_client_secret(params, workload_identity_client) == params
    end

    test "a public client gets what it got before" do
      params = %{"code" => "code_123"}
      public_client = public_client()

      # A public client's key is the empty string, and that is what the
      # request has always carried.
      assert put_client_secret(params, public_client) ==
               WorkOS.Client.put_inferred(params, "client_secret", public_client.api_key)

      assert put_client_secret(params, public_client) ==
               %{"code" => "code_123", "client_secret" => ""}
    end

    test "a client with no key and no credentials leaves the field out" do
      client = %WorkOS.Client{public_client() | api_key: nil}

      assert put_client_secret(%{"code" => "code_123"}, client) == %{"code" => "code_123"}
    end

    test "a workload identity client is refused before any request or token exchange" do
      {client, credentials} = workload_identity_client()

      assert_raise WorkOS.ConfigurationError, @workload_identity_message, fn ->
        put_client_secret(%{"email" => "user@example.com", "password" => "pw"}, client)
      end

      # Nothing was asked of the credentials: no provider call, no exchange,
      # no cached token. Nothing was sent to the API either.
      assert %{token: nil, generation: 0, inflight: nil} = :sys.get_state(credentials)
      refute_received :provider_invoked
      refute_received :exchange_requested
      refute_received {:api_requested, _path, _body}

      # The same client does exchange and send for an ordinary request, so
      # the silence above is the refusal and not a client that cannot work.
      assert {:ok, _body} = WorkOS.Client.request(client, :get, "/organizations")
      assert_received :provider_invoked
      assert_received :exchange_requested
      assert_received {:api_requested, "/organizations", _body}
    end

    test "a workload identity client with an empty key is refused too" do
      {client, _credentials} = workload_identity_client()

      assert_raise WorkOS.ConfigurationError, @workload_identity_message, fn ->
        put_client_secret(%{}, %WorkOS.Client{client | api_key: ""})
      end
    end

    test "the error names the calling function" do
      {client, _credentials} = workload_identity_client()

      error =
        assert_raise WorkOS.ConfigurationError, fn ->
          put_client_secret(%{}, client, "get_profile_and_token")
        end

      assert error.message ==
               String.replace(
                 @workload_identity_message,
                 "authenticate_with_password",
                 "get_profile_and_token"
               )
    end
  end

  describe "a public client's PKCE code exchange" do
    test "is still sent, for AuthKit and for SSO" do
      client =
        public_client(%{
          "/user_management/authenticate" =>
            WorkOS.TestFixtures.fixture("user_management/authenticate_with_code"),
          "/sso/token" => WorkOS.TestFixtures.fixture("sso/get_profile_and_token")
        })

      params = %{code: "code_123", code_verifier: "verifier_123"}

      assert {:ok, %WorkOS.AuthenticateResponse{}} =
               WorkOS.AuthKit.pkce_code_exchange(client, params)

      assert {:ok, %WorkOS.SSOTokenResponse{}} = PKCE.code_exchange(client, params)

      for path <- ["/user_management/authenticate", "/sso/token"] do
        assert_received {:api_requested, ^path, body}

        assert JSON.decode!(body) == %{
                 "grant_type" => "authorization_code",
                 "code" => "code_123",
                 "code_verifier" => "verifier_123",
                 "client_id" => "client_123",
                 "client_secret" => ""
               }
      end
    end
  end
end
