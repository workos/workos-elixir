# @oagen-ignore-file

defmodule WorkOS.WorkloadIdentityTest do
  # Conformance cases WIF-01 to WIF-24 for workload identity federation, plus
  # the edge cases around them. Several cases set process-wide environment
  # variables, so the module is not async. No test touches the network: the
  # token endpoint and the API are function plugs.
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias WorkOS.WorkloadIdentity
  alias WorkOS.WorkloadIdentity.Credentials
  alias WorkOS.WorkloadIdentityError

  @moduletag :wif

  @client_id "client_wif_test"
  @environment_id "environment_wif_test"
  @token_url "https://auth.wif.test/oauth2/token"

  @env_vars ~w(WORKOS_API_KEY WORKOS_CLIENT_ID WORKOS_WIF_TOKEN_URL WORKOS_WIF_SCOPE
               WORKOS_ENVIRONMENT_ID MY_JWT)

  setup do
    previous = Map.new(@env_vars, &{&1, System.get_env(&1)})

    on_exit(fn ->
      Enum.each(previous, fn
        {name, nil} -> System.delete_env(name)
        {name, value} -> System.put_env(name, value)
      end)
    end)

    Enum.each(@env_vars, &System.delete_env/1)
    :ok
  end

  # -- mocks ------------------------------------------------------------------
  #
  # A mock is a script of steps and a record of the requests it received.
  # Each request takes the next step; once the script runs out, the default
  # step repeats. "Exchange count" is `length(requests(token_endpoint))`.

  defp mock(default, script) do
    {:ok, agent} =
      Agent.start_link(fn -> %{script: script, default: default, requests: [], issued: 0} end)

    agent
  end

  defp token_endpoint(script \\ []), do: mock(:issue, script)
  defp api(script \\ []), do: mock(:ok, script)

  defp requests(mock), do: Agent.get(mock, & &1.requests)

  defp next_step(mock, request) do
    Agent.get_and_update(mock, fn state ->
      {step, script} =
        case state.script do
          [step | rest] -> {step, rest}
          [] -> {state.default, []}
        end

      {step, %{state | script: script, requests: state.requests ++ [request]}}
    end)
  end

  defp next_access_token(mock) do
    Agent.get_and_update(mock, fn state ->
      {"access-#{state.issued + 1}", %{state | issued: state.issued + 1}}
    end)
  end

  defp header(conn, name), do: conn |> Plug.Conn.get_req_header(name) |> List.first()

  # Token endpoint steps:
  #   :issue | {:issue, expires_in: seconds | :absent, access_token: token}
  #   {:oauth_error, code, description}
  #   {:status, status, headers, body}
  #   {:transport_error, reason}
  #   {:hold, step}   tells the test it is holding, then waits for :release
  defp token_plug(mock) do
    test = self()

    fn conn ->
      step =
        next_step(mock, %{
          method: conn.method,
          host: conn.host,
          path: conn.request_path,
          form: conn.body_params,
          content_type: header(conn, "content-type"),
          authorization: header(conn, "authorization")
        })

      answer_token(conn, step, mock, test)
    end
  end

  defp answer_token(conn, {:hold, step}, mock, test) do
    send(test, {:holding, self()})

    receive do
      :release -> answer_token(conn, step, mock, test)
    after
      10_000 -> raise "the held token response was never released"
    end
  end

  defp answer_token(conn, :issue, mock, test), do: answer_token(conn, {:issue, []}, mock, test)

  defp answer_token(conn, {:issue, opts}, mock, _test) do
    body = %{
      "access_token" => opts[:access_token] || next_access_token(mock),
      "token_type" => "Bearer"
    }

    body =
      case Keyword.get(opts, :expires_in, 300) do
        :absent -> body
        expires_in -> Map.put(body, "expires_in", expires_in)
      end

    Req.Test.json(conn, body)
  end

  defp answer_token(conn, {:oauth_error, code, description}, _mock, _test) do
    conn
    |> Plug.Conn.put_status(400)
    |> Req.Test.json(%{"error" => code, "error_description" => description})
  end

  defp answer_token(conn, {:status, status, headers, body}, _mock, _test),
    do: conn |> put_resp_headers(headers) |> Plug.Conn.send_resp(status, body)

  defp answer_token(conn, {:transport_error, reason}, _mock, _test),
    do: Req.Test.transport_error(conn, reason)

  # API steps: :ok | {:status, status} | {:status, status, headers}
  defp api_plug(mock) do
    fn conn ->
      step =
        next_step(mock, %{
          method: conn.method,
          host: conn.host,
          path: conn.request_path,
          authorization: header(conn, "authorization"),
          environment_id: header(conn, "x-url-environment-id"),
          idempotency_key: header(conn, "idempotency-key"),
          body: Req.Test.raw_body(conn)
        })

      answer_api(conn, step)
    end
  end

  defp answer_api(conn, :ok), do: Req.Test.json(conn, %{"ok" => true})
  defp answer_api(conn, {:status, status}), do: answer_api(conn, {:status, status, []})

  defp answer_api(conn, {:status, status, headers}) do
    conn
    |> put_resp_headers(headers)
    |> Plug.Conn.put_status(status)
    |> Req.Test.json(%{"message" => "HTTP #{status}"})
  end

  defp put_resp_headers(conn, headers) do
    Enum.reduce(headers, conn, fn {name, value}, conn ->
      Plug.Conn.put_resp_header(conn, name, value)
    end)
  end

  # -- builders ---------------------------------------------------------------

  defp credentials_options(token_endpoint, opts) do
    Keyword.merge(
      [
        client_id: @client_id,
        environment_id: @environment_id,
        token_url: @token_url,
        identity_token_provider: fn -> {:ok, "assertion-1"} end,
        req_options: [plug: token_plug(token_endpoint)],
        # A zero-delay sleeper, so retried exchanges do not slow the suite.
        sleep: fn _ms -> :ok end
      ],
      opts
    )
  end

  defp start_credentials(token_endpoint, opts \\ []) do
    {:ok, credentials} = Credentials.start_link(credentials_options(token_endpoint, opts))
    credentials
  end

  defp client(credentials, api, opts \\ []) do
    WorkOS.Client.new([credentials: credentials, req_options: [plug: api_plug(api)]] ++ opts)
  end

  defp get(client, opts \\ []), do: WorkOS.Client.request(client, :get, "/wif-check", %{}, opts)

  # An injected clock, in milliseconds.
  defp clock do
    ref = :atomics.new(1, signed: true)
    {fn -> :atomics.get(ref, 1) end, fn seconds -> :atomics.put(ref, 1, seconds * 1000) end}
  end

  # A provider that tells the test each time it is invoked. "Provider count"
  # is `provider_count()`.
  defp counted_provider(assertion \\ "assertion-1") do
    test = self()

    fn ->
      send(test, :provider_invoked)
      {:ok, assertion}
    end
  end

  defp provider_count do
    receive do
      :provider_invoked -> 1 + provider_count()
    after
      0 -> 0
    end
  end

  defp wait_for_waiters(credentials, count, tries \\ 2_000)

  defp wait_for_waiters(_credentials, count, 0),
    do: flunk("#{count} callers never ended up waiting on the exchange")

  defp wait_for_waiters(credentials, count, tries) do
    case :sys.get_state(credentials) do
      %{inflight: %{waiters: waiters}} when length(waiters) == count ->
        :ok

      _state ->
        Process.sleep(2)
        wait_for_waiters(credentials, count, tries - 1)
    end
  end

  # -- exchange request and API request ----------------------------------------

  test "WIF-01 the first request triggers one exchange POST with the right shape" do
    token_endpoint = token_endpoint()
    assert {:ok, _} = token_endpoint |> start_credentials() |> client(api()) |> get()

    assert [exchange] = requests(token_endpoint)
    assert exchange.method == "POST"
    assert exchange.host == "auth.wif.test"
    assert exchange.path == "/oauth2/token"
    assert exchange.content_type == "application/x-www-form-urlencoded"
    assert exchange.authorization == nil

    # Exactly these fields: no scope and no client_secret.
    assert exchange.form == %{
             "grant_type" => "urn:ietf:params:oauth:grant-type:jwt-bearer",
             "assertion" => "assertion-1",
             "client_id" => "client_wif_test",
             "resource" => "https://api.workos.com"
           }

    scoped = token_endpoint()

    assert {:ok, _} =
             scoped |> start_credentials(scope: "orgs:write") |> client(api()) |> get()

    assert [exchange] = requests(scoped)
    assert exchange.form["scope"] == "orgs:write"
    refute Map.has_key?(exchange.form, "client_secret")
    assert exchange.authorization == nil
  end

  test "WIF-01 a nil or empty scope leaves the scope field out of the form" do
    for scope <- [nil, ""] do
      token_endpoint = token_endpoint()

      assert {:ok, _} =
               token_endpoint |> start_credentials(scope: scope) |> client(api()) |> get()

      assert [exchange] = requests(token_endpoint)
      refute Map.has_key?(exchange.form, "scope")
    end
  end

  test "WIF-02 (a) the API request carries the access token and the environment header" do
    api = api()
    assert {:ok, _} = token_endpoint() |> start_credentials() |> client(api) |> get()

    assert [request] = requests(api)
    assert request.authorization == "Bearer access-1"
    assert request.environment_id == "environment_wif_test"
  end

  test "WIF-02 (b) with no environment ID the API request carries no environment header" do
    # The SDK does not read this variable. The setup puts it back afterwards.
    System.put_env("WORKOS_ENVIRONMENT_ID", "environment_env")

    api = api()
    options = token_endpoint() |> credentials_options([]) |> Keyword.delete(:environment_id)

    assert {:ok, credentials} = Credentials.start_link(options)
    assert {:ok, _} = credentials |> client(api) |> get()

    assert [request] = requests(api)
    assert request.authorization == "Bearer access-1"
    # nil means the header was absent, not present and empty.
    assert request.environment_id == nil
  end

  test "WIF-02 a nil or empty environment ID counts as not set" do
    for environment_id <- [nil, ""] do
      api = api()

      assert {:ok, _} =
               token_endpoint()
               |> start_credentials(environment_id: environment_id)
               |> client(api)
               |> get()

      assert [request] = requests(api)
      assert request.authorization == "Bearer access-1"
      assert request.environment_id == nil
    end
  end

  # -- cache and refresh --------------------------------------------------------

  test "WIF-03 a second request within the token lifetime reuses the cached token" do
    token_endpoint = token_endpoint()
    api = api()
    client = token_endpoint |> start_credentials() |> client(api)

    assert {:ok, _} = get(client)
    assert {:ok, _} = get(client)

    assert length(requests(token_endpoint)) == 1
    assert Enum.map(requests(api), & &1.authorization) == ["Bearer access-1", "Bearer access-1"]
  end

  test "WIF-04 with expires_in 300 the token is refreshed when less than 60 seconds remain" do
    {now, set_seconds} = clock()
    token_endpoint = token_endpoint()
    api = api()
    client = token_endpoint |> start_credentials(clock: now) |> client(api)

    assert {:ok, _} = get(client)

    set_seconds.(239)
    assert {:ok, _} = get(client)
    assert length(requests(token_endpoint)) == 1

    set_seconds.(241)
    assert {:ok, _} = get(client)
    assert length(requests(token_endpoint)) == 2

    assert Enum.map(requests(api), & &1.authorization) ==
             ["Bearer access-1", "Bearer access-1", "Bearer access-2"]
  end

  test "WIF-05 with expires_in 100 the refresh threshold is 20 seconds, not 60" do
    {now, set_seconds} = clock()
    token_endpoint = token_endpoint([{:issue, expires_in: 100}])
    client = token_endpoint |> start_credentials(clock: now) |> client(api())

    assert {:ok, _} = get(client)

    set_seconds.(79)
    assert {:ok, _} = get(client)
    assert length(requests(token_endpoint)) == 1

    set_seconds.(81)
    assert {:ok, _} = get(client)
    assert length(requests(token_endpoint)) == 2
  end

  test "WIF-06 a response with no expires_in is treated as 300 seconds" do
    {now, set_seconds} = clock()
    token_endpoint = token_endpoint([{:issue, expires_in: :absent}])
    client = token_endpoint |> start_credentials(clock: now) |> client(api())

    assert {:ok, _} = get(client)

    set_seconds.(239)
    assert {:ok, _} = get(client)
    assert length(requests(token_endpoint)) == 1

    set_seconds.(241)
    assert {:ok, _} = get(client)
    assert length(requests(token_endpoint)) == 2
  end

  test "WIF-06 an expires_in that is not a positive number is treated as 300 seconds" do
    for expires_in <- [0, -5, "300", nil] do
      {now, set_seconds} = clock()
      token_endpoint = token_endpoint([{:issue, expires_in: expires_in}])
      client = token_endpoint |> start_credentials(clock: now) |> client(api())

      assert {:ok, _} = get(client)

      set_seconds.(239)
      assert {:ok, _} = get(client)
      assert length(requests(token_endpoint)) == 1

      set_seconds.(241)
      assert {:ok, _} = get(client)
      assert length(requests(token_endpoint)) == 2
    end
  end

  test "WIF-07 two credentials instances never share a cached token" do
    token_endpoint = token_endpoint()
    first_api = api()
    second_api = api()

    # Identical configuration, one token endpoint, two processes.
    first = token_endpoint |> start_credentials() |> client(first_api)
    second = token_endpoint |> start_credentials() |> client(second_api)

    assert {:ok, _} = get(first)
    assert {:ok, _} = get(second)

    assert length(requests(token_endpoint)) == 2
    assert [%{authorization: "Bearer access-1"}] = requests(first_api)
    assert [%{authorization: "Bearer access-2"}] = requests(second_api)
  end

  # -- shared exchange ----------------------------------------------------------

  test "WIF-08 twenty concurrent first requests on one instance produce exactly one exchange" do
    token_endpoint = token_endpoint([{:hold, :issue}])
    api = api()
    credentials = start_credentials(token_endpoint, identity_token_provider: counted_provider())
    client = client(credentials, api)

    tasks = for _ <- 1..20, do: Task.async(fn -> get(client) end)

    # The token endpoint holds its response until all twenty are waiting.
    assert_receive {:holding, exchange}, 5_000
    wait_for_waiters(credentials, 20)
    send(exchange, :release)

    results = Task.await_many(tasks, 5_000)
    assert Enum.all?(results, &match?({:ok, _}, &1))

    assert length(requests(token_endpoint)) == 1
    assert provider_count() == 1

    api_requests = requests(api)
    assert length(api_requests) == 20
    assert Enum.all?(api_requests, &(&1.authorization == "Bearer access-1"))
  end

  test "WIF-23 a caller that times out does not cancel the shared exchange for the others" do
    token_endpoint = token_endpoint([{:hold, :issue}])
    api = api()
    credentials = start_credentials(token_endpoint)
    client = client(credentials, api)

    # A gives up after 50 ms. B waits.
    caller_a = Task.async(fn -> get(client, timeout: 50) end)
    caller_b = Task.async(fn -> get(client) end)

    assert_receive {:holding, exchange}, 5_000
    wait_for_waiters(credentials, 2)

    assert {:error, %WorkOS.TransportError{reason: :timeout}} = Task.await(caller_a, 5_000)

    send(exchange, :release)

    assert {:ok, _} = Task.await(caller_b, 5_000)
    assert length(requests(token_endpoint)) == 1
    assert [%{authorization: "Bearer access-1"}] = requests(api)
  end

  test "an exchange task that dies fails every waiter and is not left in flight" do
    token_endpoint = token_endpoint([{:hold, :issue}])
    credentials = start_credentials(token_endpoint)

    waiter = Task.async(fn -> Credentials.resolve(credentials, 5_000) end)

    # The held response is being served by the exchange task itself.
    assert_receive {:holding, exchange}, 5_000
    wait_for_waiters(credentials, 1)
    Process.exit(exchange, :kill)

    assert {:error, %WorkloadIdentityError{code: "exchange_failed"}} = Task.await(waiter, 5_000)
    assert Process.alive?(credentials)

    # The next call starts a new exchange, which succeeds.
    assert {:ok, snapshot} = Credentials.resolve(credentials, 5_000)
    assert {"authorization", "Bearer access-1"} in snapshot.headers
    assert length(requests(token_endpoint)) == 2
  end

  test "an exchange that outlives its deadline fails every waiter and is not left in flight" do
    token_endpoint = token_endpoint([{:hold, :issue}])
    credentials = start_credentials(token_endpoint, deadline_ms: 50)

    assert {:error, %WorkloadIdentityError{code: "exchange_failed"}} =
             Credentials.resolve(credentials, 5_000)

    # The next call starts a new exchange, which succeeds.
    assert {:ok, snapshot} = Credentials.resolve(credentials, 5_000)
    assert {"authorization", "Bearer access-1"} in snapshot.headers
    assert length(requests(token_endpoint)) == 2
  end

  # -- 401 recovery -------------------------------------------------------------

  test "WIF-09 a 401 invalidates that token generation, exchanges again and retries once" do
    token_endpoint = token_endpoint()
    api = api([{:status, 401}])

    assert {:ok, _} = token_endpoint |> start_credentials() |> client(api) |> get()

    assert length(requests(token_endpoint)) == 2
    assert Enum.map(requests(api), & &1.authorization) == ["Bearer access-1", "Bearer access-2"]
  end

  test "WIF-10 a second 401 after recovery is returned to the caller" do
    token_endpoint = token_endpoint()
    api = mock({:status, 401}, [])

    assert {:error, %WorkOS.ApiError{status: 401, kind: :authentication}} =
             token_endpoint |> start_credentials() |> client(api) |> get()

    assert length(requests(token_endpoint)) == 2
    assert length(requests(api)) == 2
  end

  test "WIF-11 a late 401 for an old generation does not discard a newer token" do
    token_endpoint = token_endpoint()
    api = api()
    credentials = start_credentials(token_endpoint)

    assert {:ok, %{generation: 1} = first} = Credentials.resolve(credentials, 5_000)
    assert {"authorization", "Bearer access-1"} in first.headers

    assert :ok = Credentials.invalidate(credentials, 1)
    assert {:ok, %{generation: 2} = second} = Credentials.resolve(credentials, 5_000)
    assert {"authorization", "Bearer access-2"} in second.headers

    # A late 401 for generation 1 arrives after generation 2 is cached.
    assert :ok = Credentials.invalidate(credentials, 1)

    assert {:ok, _} = credentials |> client(api) |> get()

    assert :sys.get_state(credentials).generation == 2
    assert length(requests(token_endpoint)) == 2
    assert [%{authorization: "Bearer access-2"}] = requests(api)
  end

  test "WIF-12 transport retries inside one request do not reset the single 401 recovery" do
    token_endpoint = token_endpoint()
    # 401, then 503, then 401. A fourth attempt would get a 200.
    api = api([{:status, 401}, {:status, 503, [{"retry-after", "0"}]}, {:status, 401}])
    client = token_endpoint |> start_credentials() |> client(api)

    capture_log(fn ->
      assert {:error, %WorkOS.ApiError{status: 401}} = get(client)
    end)

    assert length(requests(token_endpoint)) == 2
    assert length(requests(api)) == 3
  end

  test "WIF-13 the 401 retry sends the same request body and the same idempotency key" do
    api = api([{:status, 401}])
    client = token_endpoint() |> start_credentials() |> client(api)

    # No explicit key: the SDK generates one for a POST.
    assert {:ok, _} =
             WorkOS.Client.request(client, :post, "/wif-check", %{name: "Acme", tags: ["a", "b"]})

    assert [first, second] = requests(api)
    assert first.body == second.body
    assert first.body != ""
    assert is_binary(first.idempotency_key) and first.idempotency_key != ""
    assert first.idempotency_key == second.idempotency_key
    assert [first.authorization, second.authorization] == ["Bearer access-1", "Bearer access-2"]
  end

  test "credentials are resolved again before a transport retry, so a retry never sends an expired token" do
    {now, set_seconds} = clock()
    token_endpoint = token_endpoint()
    api = api([{:status, 503, [{"retry-after", "0"}]}])
    credentials = start_credentials(token_endpoint, clock: now)

    # The token passes its refresh threshold while the first attempt is in
    # flight. The API answers that attempt with a 503.
    plug = fn conn ->
      if requests(api) == [], do: set_seconds.(241)
      api_plug(api).(conn)
    end

    client = WorkOS.Client.new(credentials: credentials, req_options: [plug: plug])

    capture_log(fn ->
      assert {:ok, _} = get(client)
    end)

    assert Enum.map(requests(api), & &1.authorization) == ["Bearer access-1", "Bearer access-2"]
    assert length(requests(token_endpoint)) == 2
  end

  test "WIF-24 static API-key clients are unchanged" do
    token_endpoint = token_endpoint()
    api = api([:ok, {:status, 401}])
    client = WorkOS.Client.new(api_key: "sk_test_static", req_options: [plug: api_plug(api)])

    assert {:ok, _} = get(client)
    assert [request] = requests(api)
    assert request.authorization == "Bearer sk_test_static"
    assert request.environment_id == nil

    # A 401 is returned after exactly one attempt.
    assert {:error, %WorkOS.ApiError{status: 401}} = get(client)
    assert length(requests(api)) == 2

    assert requests(token_endpoint) == []
  end

  # -- exchange retries and errors ------------------------------------------------

  test "WIF-14 the exchange is retried on 503 and 429, calling the provider again each time" do
    token_endpoint =
      token_endpoint([
        {:status, 503, [], ""},
        {:status, 429, [{"retry-after", "0"}], ""}
      ])

    credentials = start_credentials(token_endpoint, identity_token_provider: counted_provider())

    assert {:ok, _} = credentials |> client(api()) |> get()
    assert length(requests(token_endpoint)) == 3
    assert provider_count() == 3
  end

  test "WIF-14 the exchange is retried when the connection fails" do
    token_endpoint = token_endpoint([{:transport_error, :econnrefused}])
    credentials = start_credentials(token_endpoint, identity_token_provider: counted_provider())

    assert {:ok, _} = credentials |> client(api()) |> get()
    assert provider_count() == 2
  end

  test "WIF-14 the exchange is retried when the provider raises" do
    test = self()
    calls = :counters.new(1, [])

    provider = fn ->
      send(test, :provider_invoked)
      :counters.add(calls, 1, 1)

      if :counters.get(calls, 1) == 1 do
        raise "the provider is not ready"
      else
        {:ok, "assertion-2"}
      end
    end

    token_endpoint = token_endpoint()
    credentials = start_credentials(token_endpoint, identity_token_provider: provider)

    assert {:ok, _} = credentials |> client(api()) |> get()
    assert provider_count() == 2
    assert [%{form: %{"assertion" => "assertion-2"}}] = requests(token_endpoint)
  end

  test "WIF-14 the exchange waits at least as long as Retry-After says" do
    test = self()
    token_endpoint = token_endpoint([{:status, 429, [{"retry-after", "1"}], ""}])

    credentials =
      start_credentials(token_endpoint, sleep: fn ms -> send(test, {:slept, ms}) end)

    assert {:ok, _} = credentials |> client(api()) |> get()

    assert_received {:slept, ms}
    assert ms >= 1_000
    assert length(requests(token_endpoint)) == 2
  end

  test "WIF-14 a 5xx is retried even when its body has an OAuth error, then surfaces that code" do
    body = JSON.encode!(%{"error" => "temporarily_unavailable", "error_description" => "busy"})
    token_endpoint = mock({:status, 503, [{"retry-after", "0"}], body}, [])
    client = token_endpoint |> start_credentials() |> client(api())

    assert {:error, %WorkloadIdentityError{code: "temporarily_unavailable", description: "busy"}} =
             get(client)

    assert length(requests(token_endpoint)) == WorkOS.Client.default_max_retries() + 1
  end

  test "WIF-15 an OAuth error is not retried and surfaces as a typed error carrying the code" do
    for code <- ~w(invalid_grant invalid_target invalid_client unauthorized_client invalid_scope
                   invalid_request) do
      description = "The server says #{code}."
      token_endpoint = token_endpoint([{:oauth_error, code, description}])
      api = api()

      assert {:error, %WorkloadIdentityError{} = error} =
               token_endpoint |> start_credentials() |> client(api) |> get()

      assert error.code == code
      assert error.description == description
      assert is_binary(error.hint) and error.hint != ""
      assert Exception.message(error) == "#{code}: #{error.hint} #{description}"

      assert length(requests(token_endpoint)) == 1
      assert requests(api) == []
    end
  end

  test "WIF-15 an unknown OAuth code still gets a hint, and a long description is cut to 500" do
    token_endpoint =
      token_endpoint([{:oauth_error, "something_new", String.duplicate("x", 600)}])

    assert {:error, %WorkloadIdentityError{code: "something_new"} = error} =
             token_endpoint |> start_credentials() |> client(api()) |> get()

    assert error.hint == "The token endpoint rejected the exchange."
    assert String.length(error.description) == 500
  end

  test "WIF-16 after a failed exchange, the next request attempts a fresh exchange" do
    token_endpoint = token_endpoint([{:oauth_error, "invalid_grant", "No trust rule matched."}])
    api = api()
    client = token_endpoint |> start_credentials() |> client(api)

    assert {:error, %WorkloadIdentityError{code: "invalid_grant"}} = get(client)
    assert {:ok, _} = get(client)

    assert length(requests(token_endpoint)) == 2
    assert [%{authorization: "Bearer access-1"}] = requests(api)
  end

  test "WIF-17 neither the assertion nor the access token appears in any error or log line" do
    assertion = "SECRET-ASSERTION-VALUE"
    access_token = "SECRET-ACCESS-VALUE"
    provider = fn -> {:ok, assertion} end
    issue = {:issue, access_token: access_token}

    scenarios = [
      # An invalid_grant exchange.
      fn ->
        token_endpoint([{:oauth_error, "invalid_grant", "No trust rule matched."}])
        |> start_credentials(identity_token_provider: provider)
        |> client(api())
        |> get()
      end,
      # A 500 from the token endpoint until retries run out.
      fn ->
        mock({:status, 500, [], "internal error"}, [])
        |> start_credentials(identity_token_provider: provider)
        |> client(api())
        |> get()
      end,
      # A provider that raises.
      fn ->
        mock(issue, [])
        |> start_credentials(identity_token_provider: fn -> raise "the provider exploded" end)
        |> client(api())
        |> get()
      end,
      # A second 401 from the API.
      fn ->
        mock(issue, [])
        |> start_credentials(identity_token_provider: provider)
        |> client(mock({:status, 401}, []))
        |> get()
      end
    ]

    {errors, log} =
      with_log([level: :debug], fn ->
        Enum.map(scenarios, fn scenario ->
          assert {:error, error} = scenario.()
          error
        end)
      end)

    assert [
             %WorkloadIdentityError{code: "invalid_grant"},
             %WorkloadIdentityError{code: "exchange_failed"},
             %WorkloadIdentityError{code: "provider_failed"},
             %WorkOS.ApiError{status: 401}
           ] = errors

    for text <- [log | Enum.flat_map(errors, &[Exception.message(&1), inspect(&1)])],
        secret <- [assertion, access_token] do
      refute text =~ secret
    end
  end

  test "WIF-17 the access token is left out of snapshots and of the process status" do
    credentials =
      mock({:issue, access_token: "SECRET-ACCESS-VALUE"}, []) |> start_credentials()

    assert {:ok, snapshot} = Credentials.resolve(credentials, 5_000)
    assert {"authorization", "Bearer SECRET-ACCESS-VALUE"} in snapshot.headers

    refute inspect(snapshot) =~ "SECRET-ACCESS-VALUE"
    refute inspect(:sys.get_status(credentials), limit: :infinity) =~ "SECRET-ACCESS-VALUE"
    refute inspect(:sys.get_state(credentials), limit: :infinity) =~ "SECRET-ACCESS-VALUE"
  end

  test "WIF-17 an unknown call, cast or message neither stops the process nor exposes the token" do
    credentials =
      mock({:issue, access_token: "SECRET-ACCESS-VALUE"}, []) |> start_credentials()

    assert {:ok, _snapshot} = Credentials.resolve(credentials, 5_000)

    log =
      capture_log([level: :debug], fn ->
        assert GenServer.call(credentials, :not_a_request) == {:error, :unknown_request}
        assert :ok = GenServer.cast(credentials, :not_a_request)
        send(credentials, :not_a_request)

        # Still serving, from the same cached token.
        assert {:ok, %{generation: 1}} = Credentials.resolve(credentials, 5_000)
      end)

    assert Process.alive?(credentials)
    refute log =~ "SECRET-ACCESS-VALUE"
  end

  test "WIF-17 an assertion echoed back by the token endpoint is removed from the error" do
    token_endpoint =
      token_endpoint([
        {:oauth_error, "invalid_grant", "Rejected assertion SECRET-ASSERTION-VALUE."}
      ])

    assert {:error, %WorkloadIdentityError{code: "invalid_grant"} = error} =
             token_endpoint
             |> start_credentials(
               identity_token_provider: fn -> {:ok, "SECRET-ASSERTION-VALUE"} end
             )
             |> client(api())
             |> get()

    assert error.description == "Rejected assertion [REDACTED]."
    refute Exception.message(error) =~ "SECRET-ASSERTION-VALUE"
    refute inspect(error) =~ "SECRET-ASSERTION-VALUE"
  end

  test "WIF-18 the exchange request does not follow redirects" do
    elsewhere = token_endpoint()

    token_endpoint =
      token_endpoint([
        {:status, 307, [{"location", "https://elsewhere.wif.test/oauth2/token"}], ""}
      ])

    # One plug serves both hosts, so a followed redirect would be recorded.
    plug = fn conn ->
      if conn.host == "elsewhere.wif.test",
        do: token_plug(elsewhere).(conn),
        else: token_plug(token_endpoint).(conn)
    end

    assert {:error, %WorkloadIdentityError{code: "exchange_failed"}} =
             token_endpoint
             |> start_credentials(req_options: [plug: plug])
             |> client(api())
             |> get()

    assert [%{method: "POST", host: "auth.wif.test"}] = requests(token_endpoint)
    assert requests(elsewhere) == []
  end

  test "WIF-18 no Req option makes the exchange follow a redirect or send an Authorization header" do
    elsewhere = token_endpoint()

    token_endpoint =
      token_endpoint([
        {:status, 307, [{"location", "https://elsewhere.wif.test/oauth2/token"}], ""}
      ])

    plug = fn conn ->
      if conn.host == "elsewhere.wif.test",
        do: token_plug(elsewhere).(conn),
        else: token_plug(token_endpoint).(conn)
    end

    req_options = [
      plug: plug,
      redirect: true,
      follow_redirects: true,
      auth: {:bearer, "sk_must_not_be_sent"},
      headers: [{"authorization", "Bearer sk_must_not_be_sent"}],
      # Req signs the request, and adds the header, only when it is sent.
      aws_sigv4: [access_key_id: "AKIDEXAMPLE", secret_access_key: "secret", service: :sts]
    ]

    assert {:error, %WorkloadIdentityError{code: "exchange_failed"}} =
             token_endpoint
             |> start_credentials(req_options: req_options)
             |> client(api())
             |> get()

    assert [%{method: "POST", authorization: nil}] = requests(token_endpoint)
    assert requests(elsewhere) == []
  end

  test "WIF-14 a Retry-After the SDK cannot read falls back to the normal backoff" do
    test = self()
    token_endpoint = token_endpoint([{:status, 429, [{"retry-after", "soon"}], ""}])

    credentials =
      start_credentials(token_endpoint, sleep: fn ms -> send(test, {:slept, ms}) end)

    assert {:ok, _} = credentials |> client(api()) |> get()

    assert_received {:slept, ms}
    assert ms > 0
    assert length(requests(token_endpoint)) == 2
  end

  test "a 200 that is not JSON, or has no access token, is an invalid_response error" do
    for response <- [
          {:status, 200, [], "not json"},
          {:status, 200, [], JSON.encode!(%{"token_type" => "Bearer"})},
          {:status, 200, [], JSON.encode!(%{"access_token" => ""})},
          {:status, 404, [], "not found"}
        ] do
      token_endpoint = token_endpoint([response])

      assert {:error, %WorkloadIdentityError{code: "invalid_response"}} =
               token_endpoint |> start_credentials() |> client(api()) |> get()

      assert length(requests(token_endpoint)) == 1
    end
  end

  # -- authentication precedence ---------------------------------------------------

  test "WIF-19 passing both an API key and credentials is a configuration error" do
    token_endpoint = token_endpoint()
    api = api()
    credentials = start_credentials(token_endpoint)

    assert_raise WorkOS.ConfigurationError, ~r/not both/, fn ->
      WorkOS.Client.new(
        api_key: "sk_test_explicit",
        credentials: credentials,
        req_options: [plug: api_plug(api)]
      )
    end

    # No HTTP request was sent.
    assert requests(token_endpoint) == []
    assert requests(api) == []
  end

  test "WIF-20 explicit credentials win over WORKOS_API_KEY, and a failing configuration never falls back to it" do
    System.put_env("WORKOS_API_KEY", "sk_test_env")
    api = api()

    # (a) Valid credentials.
    client = token_endpoint() |> start_credentials() |> client(api)
    assert client.api_key == nil
    assert {:ok, _} = get(client)

    # (b) No token URL.
    options = token_endpoint() |> credentials_options([]) |> Keyword.delete(:token_url)

    assert {:error, %WorkloadIdentityError{code: "invalid_configuration"} = error} =
             Credentials.start_link(options)

    assert error.description == "token_url is required"

    # (c) Valid credentials whose exchange fails.
    failing = token_endpoint([{:oauth_error, "invalid_client", "Unknown client."}])

    assert {:error, %WorkloadIdentityError{code: "invalid_client"}} =
             failing |> start_credentials() |> client(api) |> get()

    # The API saw one request, from (a), and never the environment key.
    assert [%{authorization: "Bearer access-1"}] = requests(api)
  end

  test "WIF-20 every required option is checked when the credentials are constructed" do
    # Only client_id has an environment variable to name.
    for {key, description} <- [
          client_id: "client_id is required (or set WORKOS_CLIENT_ID)",
          token_url: "token_url is required"
        ] do
      options = token_endpoint() |> credentials_options([]) |> Keyword.delete(key)

      assert {:error, %WorkloadIdentityError{code: "invalid_configuration"} = error} =
               Credentials.start_link(options)

      assert error.description == description
      assert Exception.message(error) =~ "missing a required setting"
    end

    # A nil or empty token URL is a missing one.
    for token_url <- [nil, ""] do
      options = credentials_options(token_endpoint(), token_url: token_url)

      assert {:error, %WorkloadIdentityError{code: "invalid_configuration"} = error} =
               Credentials.start_link(options)

      assert error.description == "token_url is required"
    end

    options =
      token_endpoint() |> credentials_options([]) |> Keyword.delete(:identity_token_provider)

    assert {:error, %WorkloadIdentityError{code: "invalid_configuration"}} =
             Credentials.start_link(options)

    assert {:error, %WorkloadIdentityError{code: "invalid_configuration"}} =
             Credentials.start_link(Keyword.put(options, :identity_token_provider, "a string"))
  end

  test "the credentials option must name a process" do
    assert_raise WorkOS.ConfigurationError, ~r/credentials/, fn ->
      WorkOS.Client.new(credentials: "not a process")
    end
  end

  test "a credentials process that is not running is an error, not a crash" do
    credentials = start_credentials(token_endpoint())
    client = client(credentials, api())
    :ok = GenServer.stop(credentials)

    assert {:error, %WorkOS.TransportError{reason: :credentials_unavailable}} = get(client)
  end

  test "credentials can be registered under a name and found by it" do
    name = :"wif_credentials_#{System.unique_integer([:positive])}"
    api = api()

    assert {:ok, _pid} =
             token_endpoint() |> credentials_options(name: name) |> Credentials.start_link()

    assert {:ok, _} = name |> client(api) |> get()
    assert [%{authorization: "Bearer access-1"}] = requests(api)
  end

  # -- custom providers -------------------------------------------------------------

  @tag :tmp_dir
  test "WIF-21 token_file re-reads the file on every exchange", %{tmp_dir: tmp_dir} do
    {now, set_seconds} = clock()
    path = Path.join(tmp_dir, "identity-token")
    File.write!(path, "assertion-1\n")

    token_endpoint = token_endpoint()

    client =
      token_endpoint
      |> start_credentials(identity_token_provider: WorkloadIdentity.token_file(path), clock: now)
      |> client(api())

    assert {:ok, _} = get(client)

    # Rotate the file, then move the clock past the refresh threshold.
    File.write!(path, "  assertion-2\n\n")
    set_seconds.(241)
    assert {:ok, _} = get(client)

    assert Enum.map(requests(token_endpoint), & &1.form["assertion"]) ==
             ["assertion-1", "assertion-2"]
  end

  @tag :tmp_dir
  test "WIF-21 a missing or empty token file is a provider error", %{tmp_dir: tmp_dir} do
    empty = Path.join(tmp_dir, "empty")
    File.write!(empty, " \n")

    for path <- [empty, Path.join(tmp_dir, "missing")] do
      token_endpoint = token_endpoint()

      assert {:error, %WorkloadIdentityError{code: "provider_failed"} = error} =
               token_endpoint
               |> start_credentials(identity_token_provider: WorkloadIdentity.token_file(path))
               |> client(api())
               |> get()

      assert error.description =~ path
      assert requests(token_endpoint) == []
    end
  end

  test "WIF-22 token_env and callback providers supply the assertion" do
    # (a) token_env
    System.put_env("MY_JWT", "assertion-env")
    from_env = token_endpoint()

    assert {:ok, _} =
             from_env
             |> start_credentials(identity_token_provider: WorkloadIdentity.token_env("MY_JWT"))
             |> client(api())
             |> get()

    assert [%{form: %{"assertion" => "assertion-env"}}] = requests(from_env)

    # (b) a callback, as a function and as a {module, function, args} tuple
    for provider <- [fn -> {:ok, "assertion-cb"} end, {__MODULE__, :callback_provider, ["cb"]}] do
      from_callback = token_endpoint()

      assert {:ok, _} =
               from_callback
               |> start_credentials(identity_token_provider: provider)
               |> client(api())
               |> get()

      assert [%{form: %{"assertion" => "assertion-cb"}}] = requests(from_callback)
    end
  end

  @doc false
  def callback_provider(suffix), do: {:ok, "assertion-" <> suffix}

  test "WIF-22 an unset or empty token_env variable is a provider error" do
    for value <- [nil, ""] do
      if value, do: System.put_env("MY_JWT", value), else: System.delete_env("MY_JWT")
      token_endpoint = token_endpoint()

      assert {:error, %WorkloadIdentityError{code: "provider_failed"} = error} =
               token_endpoint
               |> start_credentials(identity_token_provider: WorkloadIdentity.token_env("MY_JWT"))
               |> client(api())
               |> get()

      assert error.description =~ "MY_JWT"
      assert requests(token_endpoint) == []
    end
  end

  test "WIF-22 only client_id defaults from the environment, and an explicit value wins" do
    System.put_env("WORKOS_CLIENT_ID", "client_env")
    System.put_env("WORKOS_WIF_TOKEN_URL", "https://ignored.example.test/oauth2/token")
    System.put_env("WORKOS_WIF_SCOPE", "scope_env")

    provider = fn -> {:ok, "assertion-1"} end

    # (c) A provider and the token URL, and nothing else. The SDK reads
    # neither WORKOS_WIF_TOKEN_URL nor WORKOS_WIF_SCOPE.
    token_endpoint = token_endpoint()
    api = api()

    assert {:ok, credentials} =
             Credentials.start_link(
               identity_token_provider: provider,
               token_url: @token_url,
               req_options: [plug: token_plug(token_endpoint)]
             )

    assert {:ok, _} = credentials |> client(api) |> get()

    assert [exchange] = requests(token_endpoint)
    assert exchange.host == "auth.wif.test"
    assert exchange.path == "/oauth2/token"
    assert exchange.form["client_id"] == "client_env"
    refute Map.has_key?(exchange.form, "scope")

    # (d) The same environment, with an explicit client ID.
    token_endpoint = token_endpoint()
    api = api()

    assert {:ok, credentials} =
             Credentials.start_link(
               identity_token_provider: provider,
               client_id: "client_explicit",
               token_url: @token_url,
               req_options: [plug: token_plug(token_endpoint)]
             )

    assert {:ok, _} = credentials |> client(api) |> get()

    assert [exchange] = requests(token_endpoint)
    assert exchange.form["client_id"] == "client_explicit"

    # (e) The same environment, with no token URL.
    assert {:error, %WorkloadIdentityError{code: "invalid_configuration"} = error} =
             Credentials.start_link(
               identity_token_provider: provider,
               req_options: [plug: token_plug(token_endpoint())]
             )

    assert error.description == "token_url is required"
  end

  # -- redirects ----------------------------------------------------------------------

  test "a redirect to another origin does not get the token or the environment header" do
    api = api([{:status, 302, [{"location", "https://elsewhere.wif.test/landing"}]}])

    capture_log(fn ->
      assert {:ok, _} = token_endpoint() |> start_credentials() |> client(api) |> get()
    end)

    assert [first, redirected] = requests(api)
    assert first.host == "api.workos.com"
    assert first.authorization == "Bearer access-1"

    assert redirected.host == "elsewhere.wif.test"
    assert redirected.authorization == nil
    assert redirected.environment_id == nil
  end
end
