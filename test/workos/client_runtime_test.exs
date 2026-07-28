# @oagen-ignore-file

defmodule WorkOS.ClientRuntimeTest do
  use ExUnit.Case, async: true

  defp build_client(opts \\ []) do
    [api_key: "sk_test_key", req_options: [plug: {Req.Test, WorkOS.Client}]]
    |> Keyword.merge(opts)
    |> WorkOS.Client.new()
  end

  test "client configuration is instance-scoped" do
    client_a = build_client(api_key: "sk_a")
    client_b = build_client(api_key: "sk_b")

    Req.Test.stub(WorkOS.Client, fn conn ->
      assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer sk_a"]
      Req.Test.json(conn, %{})
    end)

    assert {:ok, _} = WorkOS.Client.request(client_a, :get, "/instance-scope")

    Req.Test.stub(WorkOS.Client, fn conn ->
      assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer sk_b"]
      Req.Test.json(conn, %{})
    end)

    assert {:ok, _} = WorkOS.Client.request(client_b, :get, "/instance-scope")
  end

  test "per-request headers and query options are sent on the wire" do
    Req.Test.stub(WorkOS.Client, fn conn ->
      assert Plug.Conn.get_req_header(conn, "x-request-option") == ["honored"]
      assert Plug.Conn.fetch_query_params(conn).query_params["limit"] == "2"
      Req.Test.json(conn, %{})
    end)

    assert {:ok, _} =
             WorkOS.Client.request(build_client(), :get, "/option-check", %{limit: 2},
               headers: [{"x-request-option", "honored"}]
             )
  end

  test "per-request idempotency key is sent on the wire" do
    Req.Test.stub(WorkOS.Client, fn conn ->
      assert Plug.Conn.get_req_header(conn, "idempotency-key") == ["idem_123"]
      Req.Test.json(conn, %{})
    end)

    assert {:ok, _} =
             WorkOS.Client.request(build_client(), :post, "/option-check", %{},
               idempotency_key: "idem_123"
             )
  end

  test "user agent reports the SDK package version" do
    Req.Test.stub(WorkOS.Client, fn conn ->
      assert [ua] = Plug.Conn.get_req_header(conn, "user-agent")
      assert ua == "workos-elixir/" <> WorkOS.version()
      Req.Test.json(conn, %{})
    end)

    assert {:ok, _} = WorkOS.Client.request(build_client(), :get, "/ua-check")
  end

  test "transport failures surface as WorkOS.TransportError" do
    Req.Test.stub(WorkOS.Client, fn conn ->
      Req.Test.transport_error(conn, :econnrefused)
    end)

    client = build_client(max_retries: 0)
    assert {:error, %WorkOS.TransportError{}} = WorkOS.Client.request(client, :get, "/down")
  end

  test "per-request timeout overrides the client's" do
    Req.Test.stub(WorkOS.Client, fn conn -> Req.Test.json(conn, %{}) end)

    assert {:ok, _} =
             WorkOS.Client.request(build_client(timeout: 60_000), :get, "/timeout", %{},
               timeout: 1_500
             )
  end

  test "per-request base_url overrides the client's" do
    Req.Test.stub(WorkOS.Client, fn conn ->
      assert conn.host == "override.example.com"
      Req.Test.json(conn, %{})
    end)

    assert {:ok, _} =
             WorkOS.Client.request(build_client(), :get, "/base-url", %{},
               base_url: "https://override.example.com/"
             )
  end

  test "per-request max_retries overrides the client's" do
    # Client allows 3 retries; the per-request ceiling of 0 must win, so the
    # single stubbed 500 is surfaced instead of being retried.
    Req.Test.expect(WorkOS.Client, 1, fn conn ->
      conn |> Plug.Conn.put_status(500) |> Req.Test.json(%{"message" => "boom"})
    end)

    assert {:error, %WorkOS.ApiError{status: 500}} =
             WorkOS.Client.request(build_client(max_retries: 3), :get, "/retry-override", %{},
               max_retries: 0
             )
  end

  describe "retry policy" do
    test "retries a 429 and honors Retry-After, then succeeds" do
      Req.Test.expect(WorkOS.Client, 1, fn conn ->
        conn
        |> Plug.Conn.put_resp_header("retry-after", "0")
        |> Plug.Conn.put_status(429)
        |> Req.Test.json(%{"message" => "Slow down"})
      end)

      Req.Test.expect(WorkOS.Client, 1, fn conn -> Req.Test.json(conn, %{"ok" => true}) end)

      assert {:ok, %{"ok" => true}} =
               WorkOS.Client.request(build_client(max_retries: 1), :get, "/retry-429")
    end

    test "retries a retryable 5xx, then succeeds" do
      Req.Test.expect(WorkOS.Client, 1, fn conn ->
        conn
        |> Plug.Conn.put_resp_header("retry-after", "0")
        |> Plug.Conn.put_status(503)
        |> Req.Test.json(%{"message" => "unavailable"})
      end)

      Req.Test.expect(WorkOS.Client, 1, fn conn -> Req.Test.json(conn, %{"ok" => true}) end)

      assert {:ok, %{"ok" => true}} =
               WorkOS.Client.request(build_client(max_retries: 1), :get, "/retry-503")
    end

    test "does not retry a non-retryable status" do
      Req.Test.expect(WorkOS.Client, 1, fn conn ->
        conn |> Plug.Conn.put_status(404) |> Req.Test.json(%{"message" => "nope"})
      end)

      assert {:error, %WorkOS.ApiError{status: 404}} =
               WorkOS.Client.request(build_client(max_retries: 3), :get, "/no-retry")
    end
  end

  describe "idempotency keys" do
    test "a retryable POST is given a generated key when the caller supplies none" do
      Req.Test.stub(WorkOS.Client, fn conn ->
        assert [key] = Plug.Conn.get_req_header(conn, "idempotency-key")
        assert key =~ ~r/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/
        Req.Test.json(conn, %{})
      end)

      assert {:ok, _} = WorkOS.Client.request(build_client(max_retries: 3), :post, "/idem-auto")
    end

    test "POST with retries disabled gets no generated key" do
      Req.Test.stub(WorkOS.Client, fn conn ->
        assert Plug.Conn.get_req_header(conn, "idempotency-key") == []
        Req.Test.json(conn, %{})
      end)

      assert {:ok, _} = WorkOS.Client.request(build_client(max_retries: 0), :post, "/idem-off")
    end

    test "spec-driven :idempotency opt-in works even with retries disabled" do
      Req.Test.stub(WorkOS.Client, fn conn ->
        assert [_key] = Plug.Conn.get_req_header(conn, "idempotency-key")
        Req.Test.json(conn, %{})
      end)

      assert {:ok, _} =
               WorkOS.Client.request(build_client(max_retries: 0), :post, "/idem-optin", %{},
                 idempotency: true
               )
    end

    test "GET is never given an idempotency key" do
      Req.Test.stub(WorkOS.Client, fn conn ->
        assert Plug.Conn.get_req_header(conn, "idempotency-key") == []
        Req.Test.json(conn, %{})
      end)

      assert {:ok, _} = WorkOS.Client.request(build_client(max_retries: 3), :get, "/idem-get")
    end
  end

  describe "error mapping" do
    for {status, kind} <- [
          {400, :bad_request},
          {401, :authentication},
          {403, :authorization},
          {404, :not_found},
          {409, :conflict},
          {422, :unprocessable_entity},
          {429, :rate_limit_exceeded},
          {500, :server},
          {503, :server}
        ] do
      test "HTTP #{status} maps to WorkOS.ApiError with kind #{inspect(kind)}" do
        Req.Test.expect(WorkOS.Client, 1, fn conn ->
          conn
          |> Plug.Conn.put_resp_header("x-request-id", "req_abc")
          |> Plug.Conn.put_status(unquote(status))
          |> Req.Test.json(%{"message" => "failed", "code" => "some_code"})
        end)

        assert {:error, error} =
                 WorkOS.Client.request(build_client(max_retries: 0), :get, "/err")

        assert %WorkOS.ApiError{
                 status: unquote(status),
                 kind: unquote(kind),
                 message: "failed",
                 code: "some_code",
                 request_id: "req_abc"
               } = error
      end
    end

    test "falls back to an HTTP status message when the body carries none" do
      Req.Test.expect(WorkOS.Client, 1, fn conn ->
        conn |> Plug.Conn.put_status(418) |> Req.Test.json(%{})
      end)

      assert {:error, %WorkOS.ApiError{message: "HTTP 418", kind: :api}} =
               WorkOS.Client.request(build_client(max_retries: 0), :get, "/teapot")
    end

    test "reads OAuth-style error_description bodies" do
      Req.Test.expect(WorkOS.Client, 1, fn conn ->
        conn
        |> Plug.Conn.put_status(400)
        |> Req.Test.json(%{"error" => "invalid_grant", "error_description" => "bad code"})
      end)

      assert {:error, %WorkOS.ApiError{message: "bad code"}} =
               WorkOS.Client.request(build_client(max_retries: 0), :post, "/oauth-err")
    end

    test "preserves the offending parameter name from a top-level field" do
      Req.Test.expect(WorkOS.Client, 1, fn conn ->
        conn
        |> Plug.Conn.put_status(422)
        |> Req.Test.json(%{"message" => "invalid", "field" => "email"})
      end)

      assert {:error, %WorkOS.ApiError{param: "email"}} =
               WorkOS.Client.request(build_client(max_retries: 0), :post, "/param-top")
    end

    test "preserves the offending parameter name from an errors list" do
      Req.Test.expect(WorkOS.Client, 1, fn conn ->
        conn
        |> Plug.Conn.put_status(422)
        |> Req.Test.json(%{
          "message" => "invalid",
          "errors" => [%{"field" => "domain", "code" => "invalid_domain"}]
        })
      end)

      assert {:error, %WorkOS.ApiError{param: "domain"}} =
               WorkOS.Client.request(build_client(max_retries: 0), :post, "/param-errors")
    end

    test "param is nil when the API names no field" do
      Req.Test.expect(WorkOS.Client, 1, fn conn ->
        conn |> Plug.Conn.put_status(400) |> Req.Test.json(%{"message" => "nope"})
      end)

      assert {:error, %WorkOS.ApiError{param: nil}} =
               WorkOS.Client.request(build_client(max_retries: 0), :post, "/param-none")
    end

    test "retains the raw parsed body for inspection" do
      Req.Test.expect(WorkOS.Client, 1, fn conn ->
        conn |> Plug.Conn.put_status(400) |> Req.Test.json(%{"message" => "x", "extra" => "keep"})
      end)

      assert {:error, %WorkOS.ApiError{body: %{"extra" => "keep"}}} =
               WorkOS.Client.request(build_client(max_retries: 0), :get, "/raw-body")
    end
  end

  describe "query encoding" do
    test "arrays are comma-joined and maps are JSON-encoded in built URLs" do
      url =
        WorkOS.Client.build_url(build_client(), "/encode", %{
          scopes: ["a", "b"],
          filter: %{"k" => "v"},
          skipped: nil
        })

      assert url =~ "scopes=a%2Cb"
      assert url =~ "filter=" <> URI.encode_www_form(~s({"k":"v"}))
      refute url =~ "skipped"
    end

    test "special characters in query params are percent-encoded on the wire" do
      Req.Test.stub(WorkOS.Client, fn conn ->
        params = Plug.Conn.fetch_query_params(conn).query_params
        assert params["email"] == "a+b@example.com"
        assert params["q"] == "hello world&more"
        Req.Test.json(conn, %{})
      end)

      assert {:ok, _} =
               WorkOS.Client.request(build_client(), :get, "/encode-wire", %{
                 email: "a+b@example.com",
                 q: "hello world&more"
               })
    end

    test "optional params that are absent are not sent" do
      Req.Test.stub(WorkOS.Client, fn conn ->
        params = Plug.Conn.fetch_query_params(conn).query_params
        assert params["limit"] == "5"
        refute Map.has_key?(params, "before")
        Req.Test.json(conn, %{})
      end)

      assert {:ok, _} = WorkOS.Client.request(build_client(), :get, "/encode-omit", %{limit: 5})
    end
  end

  test "an empty page yields no items and reports no more pages" do
    Req.Test.stub(WorkOS.Client, fn conn ->
      Req.Test.json(conn, %{"data" => [], "list_metadata" => %{"after" => nil}})
    end)

    assert {:ok, %WorkOS.Page{data: []} = page} = WorkOS.AuditLogs.list_actions(build_client())
    refute WorkOS.Page.has_more?(page)
    assert page |> WorkOS.Page.stream() |> Enum.to_list() == []
  end

  test "auto-pagination streams items across multiple pages" do
    base = WorkOS.TestFixtures.fixture("audit_logs/list_actions")
    page1 = Map.put(base, "list_metadata", %{"before" => nil, "after" => "cursor_page_2"})
    page2 = Map.put(base, "list_metadata", %{"before" => nil, "after" => nil})

    Req.Test.stub(WorkOS.Client, fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)

      if conn.query_params["after"] == "cursor_page_2" do
        Req.Test.json(conn, page2)
      else
        Req.Test.json(conn, page1)
      end
    end)

    assert {:ok, %WorkOS.Page{} = page} = WorkOS.AuditLogs.list_actions(build_client())
    assert page |> WorkOS.Page.stream() |> Enum.count() == 2
  end
end
