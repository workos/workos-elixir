# @oagen-ignore-file

defmodule WorkOS.ClientAdapterTest do
  # `WorkOS.Client` resolves the credentials before every HTTP attempt, and
  # how it gets to run before each attempt depends on the Req version (see the
  # comment on `put_credentials/3` in the client). So these tests send
  # requests through the adapters Req itself ships, in whatever shape the
  # installed Req gives them, and never through a stub adapter: the default
  # adapter against a loopback server, and the plug adapter.
  #
  # Not async: one test captures standard error.
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO
  import ExUnit.CaptureLog

  alias WorkOS.TestServer

  defmodule CountingCredentials do
    @moduledoc false

    # Credentials whose every resolve returns a new token ("token-1",
    # "token-2", ...). The token an attempt carries therefore says how many
    # times the credentials had been resolved when that attempt was sent.

    @behaviour WorkOS.Credentials

    def start do
      ExUnit.Callbacks.start_supervised!({Agent, fn -> %{resolved: 0, invalidated: []} end})
    end

    @impl WorkOS.Credentials
    def resolve(agent, _timeout) do
      count = Agent.get_and_update(agent, &{&1.resolved + 1, %{&1 | resolved: &1.resolved + 1}})

      {:ok,
       %WorkOS.CredentialSnapshot{
         headers: [
           {"authorization", "Bearer token-#{count}"},
           {"x-url-environment-id", "environment_test"}
         ],
         generation: count,
         recoverable: true
       }}
    end

    @impl WorkOS.Credentials
    def invalidate(agent, generation),
      do: Agent.update(agent, &%{&1 | invalidated: &1.invalidated ++ [generation]})
  end

  @ok {200, [{"content-type", "application/json"}], ~s({"ok":true})}

  # -- servers ------------------------------------------------------------------
  #
  # Both kinds answer each request with the next canned response and send the
  # test `{:request, ref, %{method: _, target: _, headers: _}}`. The loopback
  # server adds the request `:body`.

  # Req's default adapter: no `:adapter` and no `:plug` option is set.
  defp start(:default, responses) do
    responses |> TestServer.start() |> Map.put(:req_options, [])
  end

  # Req's plug adapter.
  defp start(:plug, responses) do
    test = self()
    ref = make_ref()
    script = start_supervised!({Agent, fn -> responses end}, id: ref)

    plug = fn conn ->
      send(
        test,
        {:request, ref,
         %{
           method: conn.method,
           target: request_target(conn),
           headers: Map.new(conn.req_headers)
         }}
      )

      {status, headers, body} =
        Agent.get_and_update(script, fn
          [response] -> {response, [response]}
          [response | rest] -> {response, rest}
        end)

      headers
      |> Enum.reduce(conn, fn {name, value}, conn ->
        Plug.Conn.put_resp_header(conn, name, value)
      end)
      |> Plug.Conn.send_resp(status, body)
    end

    %{url: "https://api.workos.test", ref: ref, req_options: [plug: plug]}
  end

  defp request_target(%Plug.Conn{query_string: ""} = conn), do: conn.request_path
  defp request_target(%Plug.Conn{} = conn), do: conn.request_path <> "?" <> conn.query_string

  # The requests a server has received so far, oldest first.
  defp received(%{ref: ref} = server) do
    receive do
      {:request, ^ref, request} -> [request | received(server)]
    after
      0 -> []
    end
  end

  # A client that authenticates with `CountingCredentials`. Retries do not
  # wait.
  defp counting_client(credentials, server) do
    client =
      WorkOS.Client.new(
        api_key: "sk_test_replaced_below",
        base_url: server.url,
        req_options: [retry_delay: fn _retries -> 0 end] ++ server.req_options
      )

    %{client | api_key: nil, credentials: {CountingCredentials, credentials}}
  end

  # -- tests --------------------------------------------------------------------

  test "an API-key request goes through Req's default adapter" do
    server = start(:default, [@ok])
    client = WorkOS.Client.new(api_key: "sk_test_default_adapter", base_url: server.url)

    # Nothing chooses an adapter: this is the client an application builds.
    assert client.req_options == []

    assert {:ok, %{"ok" => true}} =
             WorkOS.Client.request(client, :post, "/adapter-check", %{name: "Acme"})

    assert [request] = received(server)
    assert request.method == "POST"
    assert request.target == "/adapter-check"
    assert request.headers["authorization"] == "Bearer sk_test_default_adapter"
    assert request.headers["content-type"] == "application/json"
    assert JSON.decode!(request.body) == %{"name" => "Acme"}
  end

  for adapter <- [:default, :plug] do
    test "credentials are resolved once before every attempt through Req's #{adapter} adapter: " <>
           "first try, retry, 401 recovery and redirect" do
      server =
        start(unquote(adapter), [
          {503, [], ""},
          {401, [], ""},
          {302, [{"location", "/landed"}], ""},
          @ok
        ])

      credentials = CountingCredentials.start()
      client = counting_client(credentials, server)

      capture_log(fn ->
        assert {:ok, %{"ok" => true}} = WorkOS.Client.request(client, :get, "/attempts")
      end)

      requests = received(server)
      assert Enum.map(requests, & &1.target) == ~w(/attempts /attempts /attempts /landed)

      assert Enum.map(requests, & &1.headers["authorization"]) ==
               ["Bearer token-1", "Bearer token-2", "Bearer token-3", "Bearer token-4"]

      assert Enum.all?(requests, &(&1.headers["x-url-environment-id"] == "environment_test"))

      # One resolve per attempt, and the 401 invalidated the credential that
      # attempt was sent with.
      assert Agent.get(credentials, & &1) == %{resolved: 4, invalidated: [2]}
    end

    test "the client makes Req print no warning through Req's #{adapter} adapter" do
      server = start(unquote(adapter), [@ok])

      client =
        WorkOS.Client.new(
          api_key: "sk_test_quiet",
          base_url: server.url,
          req_options: server.req_options
        )

      # Req warns on standard error about deprecated usage, such as an adapter
      # given as a function on Req 0.7.
      warnings =
        capture_io(:stderr, fn ->
          assert {:ok, %{"ok" => true}} = WorkOS.Client.request(client, :get, "/quiet")
        end)

      assert warnings == ""
    end
  end

  test "a redirect to another origin through Req's default adapter gets no credential header " <>
         "and does not resolve the credentials" do
    elsewhere = start(:default, [@ok])
    server = start(:default, [{302, [{"location", elsewhere.url <> "/landed"}], ""}])

    credentials = CountingCredentials.start()
    client = counting_client(credentials, server)

    capture_log(fn ->
      assert {:ok, %{"ok" => true}} = WorkOS.Client.request(client, :get, "/redirect")
    end)

    assert [first] = received(server)
    assert first.headers["authorization"] == "Bearer token-1"
    assert first.headers["x-url-environment-id"] == "environment_test"

    assert [redirected] = received(elsewhere)
    assert redirected.target == "/landed"
    refute Map.has_key?(redirected.headers, "authorization")
    refute Map.has_key?(redirected.headers, "x-url-environment-id")

    assert Agent.get(credentials, & &1.resolved) == 1
  end
end
