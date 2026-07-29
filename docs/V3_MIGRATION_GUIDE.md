# WorkOS Elixir SDK v3 Migration Guide

Version 3 of the WorkOS Elixir SDK is a ground-up rewrite, generated from the
WorkOS OpenAPI specification. It replaces the previous experimental SDK with a
production-grade client: instance-scoped configuration, a modern HTTP stack
built on [Req](https://hexdocs.pm/req), typed errors, lazy auto-pagination,
built-in retries, and coverage of the full WorkOS API surface — including
AuthKit sessions, RBAC, Vault, Feature Flags, Radar, Widgets, and more.

Because v3 is a rewrite rather than an incremental change, every call site
needs attention. This guide walks through each breaking change with
before/after examples, followed by a complete function mapping and a tour of
what's new.

## Upgrade at a glance

1. Update to Elixir 1.18 or later
2. Bump the dependency in `mix.exs`:

   ```elixir
   def deps do
     [{:workos, "~> 3.0"}]
   end
   ```

3. Delete the application config block (`config :workos, WorkOS.Client, ...`)
   and build a client instead:

   ```elixir
   client = WorkOS.client(api_key: System.fetch_env!("WORKOS_API_KEY"))
   ```

4. Pass the client as the first argument to every SDK call, and update the
   call sites listed in [Function mapping](#function-mapping).
5. Update error handling to match on `WorkOS.ApiError` / `WorkOS.TransportError`.
6. Run your test suite. If you stubbed the old SDK with `Tesla.Mock`, see
   [Testing](#testing).

## Requirements and dependencies

|                    | v2 (old)                            | v3 (new)                                    |
| ------------------ | ----------------------------------- | ------------------------------------------- |
| Elixir             | `~> 1.16`                           | `~> 1.18`                                   |
| HTTP client        | Tesla (over `:httpc` by default)    | Req                                         |
| JSON               | Jason                               | Elixir's built-in `JSON` module             |
| Other runtime deps | `hackney` (optional), `plug_crypto` | none — `req` is the only runtime dependency |

If your application depended on Tesla, Jason, hackney, or `plug_crypto` only
transitively through `:workos`, add them to your own `mix.exs`.

## The biggest conceptual changes

### 1. An instance-scoped client replaces application config

v2 read `Application.get_env(:workos, WorkOS.Client)` on every call and
required both `:api_key` and `:client_id` globally. v3 has **no global state**:
you build a `%WorkOS.Client{}` struct and pass it to every function. This makes
it trivial to talk to multiple WorkOS environments from one application, and
makes configuration errors surface at construction time instead of at the
first API call.

```elixir
# Before (v2) — config.exs
config :workos, WorkOS.Client,
  api_key: System.get_env("WORKOS_API_KEY"),
  client_id: System.get_env("WORKOS_CLIENT_ID")

# Before (v2) — call site (client optional, rebuilt from config each call)
{:ok, organization} = WorkOS.Organizations.get_organization("org_01EHZ...")
```

```elixir
# After (v3) — no config.exs entry; build a client once and reuse it
client =
  WorkOS.client(
    api_key: System.fetch_env!("WORKOS_API_KEY"),
    client_id: System.get_env("WORKOS_CLIENT_ID")
  )

{:ok, organization} = WorkOS.Organizations.get_organization(client, "org_01EHZ...")
```

`WorkOS.client/1` (an alias for `WorkOS.Client.new/1`) accepts:

| Option         | Description                                                                                                                           |
| -------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| `:api_key`     | Required unless the `WORKOS_API_KEY` env var is set. Missing key raises `WorkOS.ConfigurationError` at construction.                  |
| `:client_id`   | Optional; only needed for authentication flows and URL builders. Falls back to `WORKOS_CLIENT_ID`.                                    |
| `:base_url`    | Override the API base URL (default `https://api.workos.com`).                                                                         |
| `:timeout`     | Receive timeout in milliseconds (default `60_000`). v2 had no timeout configuration.                                                  |
| `:max_retries` | Maximum retry attempts (default `3`).                                                                                                 |
| `:req_options` | Extra `Req` options merged into every request, overriding SDK defaults — see [Bring your own HTTP stack](#bring-your-own-http-stack). |

Unlike v2, the env-var fallback works in library code — in v2 the
`System.get_env` calls lived in the SDK's own `config/dev.exs` and never
applied to consuming applications. Also unlike v2, `:client_id` is no longer
required just to make an Organizations call.

#### Bring your own HTTP stack

The v2 `:client` option is gone, along with the `WorkOS.Client` behavior that
let you route requests through your own Tesla stack. The replacement is
`:req_options`: the SDK builds each request with `Req.new/1` and merges your
options **last**, so they can override anything the SDK sets — the connection
pool, proxy and TLS settings, or the entire adapter:

```elixir
# Reuse your application's Finch pool
WorkOS.client(api_key: key, req_options: [finch: MyApp.Finch])

# Route through a proxy / customize TLS
WorkOS.client(
  api_key: key,
  req_options: [connect_options: [proxy: {:http, "proxy.internal", 8080, []}]]
)

# Replace the HTTP execution step entirely — the bridge for anything Req
# doesn't cover. The adapter receives the built %Req.Request{} and returns
# {request, %Req.Response{}} or {request, exception}.
WorkOS.client(api_key: key, req_options: [adapter: &MyApp.WorkOSAdapter.run/1])
```

Because your options merge last, they can also clobber the SDK's `:auth`,
`:retry`, and `:headers` settings — override those only deliberately.

`WorkOS.ApiKeyMissingError` and `WorkOS.ClientIdMissingError` no longer exist;
the single `WorkOS.ConfigurationError` raises when a client cannot be built.

### 2. Built-in retries and timeouts

v2 had no retry or timeout support. v3 automatically retries requests that
fail with 429, 500, 502, 503, or 504, or with a transport error — using
exponential backoff (capped at 30 seconds) with jitter. Retried POST requests
automatically carry an idempotency key, so replays are safe.

Every function also accepts per-request options as its final argument:

```elixir
WorkOS.Organizations.create_organization(
  client,
  %{name: "Acme"},
  idempotency_key: "org-create-42",
  timeout: 5_000,
  headers: [{"x-request-source", "billing-worker"}]
)
```

Available per-request options: `:headers`, `:idempotency_key`, `:timeout`,
`:max_retries`, `:base_url`, and `:query`.

### 3. Every result is typed

All API functions return `{:ok, result}` or `{:error, error}` where `error` is
always a struct — `WorkOS.ApiError` for non-2xx responses or
`WorkOS.TransportError` for network failures. The v2 mixed bag of
`{:error, %WorkOS.Error{}}`, `{:error, "some string"}`, and
`{:error, :client_error}` is gone, as is v2's unconditional `Logger.error` on
every failed request (v3 leaves logging to you).

### 4. Much wider API coverage

v2 exposed 11 product areas. v3 exposes the full API — see
[New in v3](#new-in-v3).

## Breaking changes

### The client argument is required — and always first

In v2 most functions defaulted their client argument (`client \\ WorkOS.client()`),
so you could omit it. In v3 the client is always explicit and always first,
followed by any path parameters, then a `params` map, then per-request `opts`:

```elixir
# Before (v2)
{:ok, list} = WorkOS.Organizations.list_organizations(%{limit: 10})
{:ok, org} = WorkOS.Organizations.update_organization("org_123", %{name: "Acme"})

# After (v3)
{:ok, page} = WorkOS.Organizations.list_organizations(client, %{limit: 10})
{:ok, org} = WorkOS.Organizations.update_organization(client, "org_123", %{name: "Acme"})
```

`params` accepts atom-keyed maps, string-keyed maps, or keyword lists — but
not structs.

### Missing required parameters no longer raise

v2 enforced required parameters with function guards, so a missing key crashed
with `FunctionClauseError` (or, in `WorkOS.Portal.generate_link/2`, an
`ArgumentError`). v3 sends the request and returns the API's validation error
as data:

```elixir
# Before (v2): raises FunctionClauseError before any request is made
WorkOS.Organizations.create_organization(%{})

# After (v3): the server validates
{:error, %WorkOS.ApiError{kind: :unprocessable_entity}} =
  WorkOS.Organizations.create_organization(client, %{})
```

### Module renames and moves

| v2 (old)                                                        | v3 (new)                                             |
| --------------------------------------------------------------- | ---------------------------------------------------- |
| `WorkOS.Portal`                                                 | `WorkOS.AdminPortal`                                 |
| `WorkOS.MFA`                                                    | `WorkOS.MultiFactorAuth`                             |
| `WorkOS.UserManagement` (organization memberships)              | `WorkOS.OrganizationMembershipService`               |
| `WorkOS.Webhooks.construct_event/3,4`                           | `WorkOS.Webhooks.Signature.construct_event/4`        |
| `WorkOS.List`                                                   | `WorkOS.Page`                                        |
| `WorkOS.Error` (struct)                                         | `WorkOS.ApiError` / `WorkOS.TransportError`          |
| `WorkOS.Empty`                                                  | removed — empty responses return `{:ok, nil}`        |
| Nested model modules (e.g. `WorkOS.Organizations.Organization`) | Top-level model modules (e.g. `WorkOS.Organization`) |

There are no deprecation shims; the old names are gone.

### Return values

**Lists** return a `WorkOS.Page` instead of a `WorkOS.List` — see
[Pagination](#pagination).

**Deletes** return `{:ok, nil}` instead of `{:ok, %WorkOS.Empty{}}`:

```elixir
# Before (v2)
{:ok, %WorkOS.Empty{}} = WorkOS.Organizations.delete_organization("org_123")

# After (v3)
{:ok, nil} = WorkOS.Organizations.delete_organization(client, "org_123")
```

**Bare `:ok` returns are gone.** v2's `send_magic_auth_code/2` and
`send_password_reset_email/2` returned `:ok` on success; their v3 equivalents
return `{:ok, struct}` like everything else.

**URL builders return plain strings.** v2's `get_authorization_url/1` returned
`{:ok, url}` or `{:error, "Incomplete arguments. ..."}` and read the client ID
from global config (raising if absent). In v3 it takes the client and returns
the URL directly:

```elixir
# Before (v2)
{:ok, url} =
  WorkOS.SSO.get_authorization_url(%{
    organization: "org_123",
    redirect_uri: "https://example.com/callback"
  })

# After (v3) — client_id comes from the client struct
url =
  WorkOS.SSO.get_authorization_url(client, %{
    organization: "org_123",
    redirect_uri: "https://example.com/callback"
  })
```

The same applies to `WorkOS.UserManagement.get_authorization_url/2`.

### Models

Every API object has a top-level model module with a `defstruct`, a `@type t`,
and wire conversion helpers — for example `WorkOS.Organization` instead of
v2's `WorkOS.Organizations.Organization`. Two behavioral notes:

- Timestamps remain ISO 8601 strings (as in v2); the SDK does not parse them
  into `DateTime`.
- Enum-like fields are now atoms (e.g. an invitation state of `:pending`)
  instead of strings. Unknown values received from the API pass through
  unchanged rather than crashing, so match with a catch-all clause if you
  exhaustively case on enum fields.

### Error handling

```elixir
# Before (v2) — three shapes to handle, plus automatic Logger.error noise
case WorkOS.Organizations.get_organization("org_123") do
  {:ok, org} -> org
  {:error, %WorkOS.Error{message: message}} -> handle_api_error(message)
  {:error, binary} when is_binary(binary) -> handle_api_error(binary)
  {:error, :client_error} -> handle_network_error()
end

# After (v3) — two structs, with status and classification
case WorkOS.Organizations.get_organization(client, "org_123") do
  {:ok, org} ->
    org

  {:error, %WorkOS.ApiError{kind: :not_found}} ->
    handle_missing_org()

  {:error, %WorkOS.ApiError{status: status, message: message, request_id: request_id}} ->
    handle_api_error(status, message, request_id)

  {:error, %WorkOS.TransportError{reason: reason}} ->
    handle_network_error(reason)
end
```

`WorkOS.ApiError` carries `:message`, `:status`, `:kind`, `:request_id`
(from the `x-request-id` header — include it in support requests), `:code`,
`:param`, and the raw decoded `:body`. The `:kind` atom classifies the HTTP
status:

| Status        | `:kind`                 |
| ------------- | ----------------------- |
| 400           | `:bad_request`          |
| 401           | `:authentication`       |
| 403           | `:authorization`        |
| 404           | `:not_found`            |
| 409           | `:conflict`             |
| 422           | `:unprocessable_entity` |
| 429           | `:rate_limit_exceeded`  |
| 5xx           | `:server`               |
| anything else | `:api`                  |

Both error modules are exceptions, so `raise`-based flows work too:
`{:error, e} -> raise e`.

### Pagination

v2 returned `%WorkOS.List{data: [...], list_metadata: %{"after" => ...}}` and
left paging entirely to you. v3 returns a `%WorkOS.Page{}` that knows how to
fetch its successor:

```elixir
# Before (v2) — manual cursor threading over a raw string-keyed map
defp all_organizations(cursor \\ nil, acc \\ []) do
  {:ok, list} = WorkOS.Organizations.list_organizations(%{limit: 100, after: cursor})

  case list.list_metadata["after"] do
    nil -> acc ++ list.data
    cursor -> all_organizations(cursor, acc ++ list.data)
  end
end

# After (v3) — lazy auto-pagination across every page
{:ok, page} = WorkOS.Organizations.list_organizations(client, %{limit: 100})

organizations =
  page
  |> WorkOS.Page.stream()
  |> Enum.to_list()
```

For manual paging, `WorkOS.Page.has_more?/1` and `WorkOS.Page.after_cursor/1`
replace reading `list_metadata` yourself; pass the cursor back as `after:`.

Note: `WorkOS.Page.stream/1` stops if a page fetch fails mid-stream. Use
explicit pagination when you need to distinguish errors from the end of the
collection.

### Webhooks

Signature verification moved from `WorkOS.Webhooks` to
`WorkOS.Webhooks.Signature`, and **the first two arguments swapped places**:

```elixir
# Before (v2): (payload, signature_header, secret, tolerance \\ 180)
{:ok, event} = WorkOS.Webhooks.construct_event(body, sig_header, secret)

# After (v3): (signature_header, payload, secret, opts \\ [])
{:ok, event} = WorkOS.Webhooks.Signature.construct_event(sig_header, body, secret)

# Tolerance is now an option (default remains 180 seconds):
{:ok, event} = WorkOS.Webhooks.Signature.construct_event(sig_header, body, secret, tolerance: 300)
```

Three more differences:

- The result is a `%WorkOS.EventSchema{}` whose `data` is a **string-keyed**
  map. v2 recursively converted payload keys with `String.to_atom/1`, which
  let untrusted payloads grow the atom table — v3 does not create atoms from
  webhook input. Change `event.data.user.email`-style access to
  `event.data["user"]["email"]`.
- Verification failures return atoms (`:not_signed`, `:invalid_header`,
  `:invalid_timestamp`, `:outside_tolerance`, `:no_valid_signature`,
  `:invalid_json`) instead of English strings.
- `WorkOS.Webhooks` itself now manages webhook endpoints
  (`list_webhook_endpoints/3`, `create_webhook_endpoint/3`, ...).

### Password reset functions were renamed

Take care with `reset_password`: **it exists in both versions but does
different things.** In v2 it completed a reset with a token; in v3 it
_initiates_ one.

| What you want                           | v2 (old)                                                            | v3 (new)                                                                          |
| --------------------------------------- | ------------------------------------------------------------------- | --------------------------------------------------------------------------------- |
| Send the reset email / create the reset | `send_password_reset_email(%{email: ..., password_reset_url: ...})` | `UserManagement.reset_password(client, %{email: ...})`                            |
| Complete the reset with a token         | `reset_password(%{token: ..., new_password: ...})`                  | `UserManagement.confirm_password_reset(client, %{token: ..., new_password: ...})` |

If you migrate a v2 `reset_password/2` call by name alone, you will send your
user a second reset email instead of setting their password.

### Testing

v2 stubbing was built around `Tesla.Mock`. In v3, inject a
[`Req.Test`](https://hexdocs.pm/req/Req.Test.html) plug through `:req_options`:

```elixir
client =
  WorkOS.client(
    api_key: "sk_test_123",
    req_options: [plug: {Req.Test, MyApp.WorkOSStub}]
  )

Req.Test.stub(MyApp.WorkOSStub, fn conn ->
  Req.Test.json(conn, %{"id" => "org_01EHZ...", "name" => "Acme"})
end)
```

Because clients are plain structs, you can also build one per test with
`async: true` — no shared application config to race on.

## Function mapping

Functions not listed keep their v2 name (with the client now required as the
first argument, and `params`/`opts` following any path parameters).

### `WorkOS.Portal` → `WorkOS.AdminPortal`

| v2                                                        | v3                                                                     |
| --------------------------------------------------------- | ---------------------------------------------------------------------- |
| `Portal.generate_link(%{intent: ..., organization: ...})` | `AdminPortal.generate_link(client, %{intent: ..., organization: ...})` |

The v2 client-side whitelist of intents (and its `ArgumentError`) is gone; the
server validates the intent.

### `WorkOS.MFA` → `WorkOS.MultiFactorAuth`

| v2                                         | v3                                                               |
| ------------------------------------------ | ---------------------------------------------------------------- |
| `MFA.enroll_factor(opts)`                  | `MultiFactorAuth.enroll_factor(client, params)`                  |
| `MFA.challenge_factor(opts)`               | `MultiFactorAuth.challenge_factor(client, factor_id, params)`    |
| `MFA.verify_challenge(challenge_id, opts)` | `MultiFactorAuth.verify_challenge(client, challenge_id, params)` |
| `MFA.get_factor(id)`                       | `MultiFactorAuth.get_factor(client, id)`                         |
| `MFA.delete_factor(id)`                    | `MultiFactorAuth.delete_factor(client, id)`                      |

### `WorkOS.UserManagement`

| v2                                                | v3                                                                             |
| ------------------------------------------------- | ------------------------------------------------------------------------------ |
| `get_authorization_url(params)` → `{:ok, url}`    | `get_authorization_url(client, params)` → `url`                                |
| `send_magic_auth_code(email)` → `:ok`             | `create_magic_auth(client, %{email: ...})` → `{:ok, magic_auth}`               |
| `send_password_reset_email(params)` → `:ok`       | `reset_password(client, params)` → `{:ok, password_reset}`                     |
| `reset_password(params)`                          | `confirm_password_reset(client, params)`                                       |
| `enroll_auth_factor(user_id, opts)`               | `MultiFactorAuth.create_user_auth_factor(client, user_id, params)`             |
| `list_auth_factors(user_id)`                      | `MultiFactorAuth.list_user_auth_factors(client, user_id)`                      |
| `get_organization_membership(id)`                 | `OrganizationMembershipService.get_organization_membership(client, id)`        |
| `list_organization_memberships(params)`           | `OrganizationMembershipService.list_organization_memberships(client, params)`  |
| `create_organization_membership(params)`          | `OrganizationMembershipService.create_organization_membership(client, params)` |
| `delete_organization_membership(id)`              | `OrganizationMembershipService.delete_organization_membership(client, id)`     |
| `authenticate_with_selected_organization(params)` | `authenticate_with_organization_selection(client, params)`                     |

`authenticate_with_*` functions keep their names, take the client first, and
now infer `client_id` and `client_secret` from the client struct — you no
longer pass them in `params`. User CRUD (`get_user`, `list_users`,
`create_user`, `update_user`, `delete_user`, `get_user_by_external_id`),
invitations (`get_invitation`, `list_invitations`, `send_invitation`,
`revoke_invitation`), and email verification (`send_verification_email`,
`verify_email`) keep their v2 names.

### `WorkOS.SSO`

| v2                                                        | v3                                                                                                               |
| --------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| `get_authorization_url(params)` → `{:ok, url}`            | `get_authorization_url(client, params)` → `url`                                                                  |
| `get_profile_and_token(code)`                             | `get_profile_and_token(client, %{code: code})` — `client_id`/`client_secret` inferred                            |
| `get_profile(access_token)`                               | `get_profile(client)` — rarely needed; the profile is already included in the `get_profile_and_token/3` response |
| `list_connections`, `get_connection`, `delete_connection` | unchanged names                                                                                                  |

### `WorkOS.Webhooks`

| v2                                                                 | v3                                                                                |
| ------------------------------------------------------------------ | --------------------------------------------------------------------------------- |
| `Webhooks.construct_event(payload, sig_header, secret, tolerance)` | `Webhooks.Signature.construct_event(sig_header, payload, secret, tolerance: ...)` |

### Unchanged names (client argument now required)

`WorkOS.Organizations`, `WorkOS.DirectorySync`, `WorkOS.Events`,
`WorkOS.AuditLogs`, `WorkOS.Passwordless`, and `WorkOS.OrganizationDomains`
keep their v2 function names. `WorkOS.OrganizationDomains` additionally gains
`delete_organization_domain/3`.

## New in v3

Beyond the v2 surface, v3 adds:

- **AuthKit sessions** — `WorkOS.Session` for sealed (AES-256-GCM encrypted)
  session cookies: `authenticate/2`, `refresh/2`, `get_logout_url/2`,
  `seal_session_from_auth_response/2`. `WorkOS.UserManagement` gains
  `authenticate_with_refresh_token/3`, `get_logout_url/2`, `revoke_session/3`,
  `list_sessions/4`, and `get_jwks/2`; `WorkOS.JWKS` fetches signing keys.
- **PKCE and public clients** — `WorkOS.PublicClient` (no API key required),
  `WorkOS.PKCE.generate_pair/0`, `WorkOS.SSO.PKCE`, and
  `WorkOS.AuthKit.get_pkce_authorization_url/2` for browser/mobile flows.
- **Device authorization** — `WorkOS.AuthKit.start_device_authorization/3`,
  `poll_device_code/3`, and `WorkOS.UserManagement.authenticate_with_device_code/3`.
- **Authorization (RBAC/FGA)** — `WorkOS.Authorization`: roles, permissions,
  resources, role assignments, and `check/4`.
- **Vault** — `WorkOS.Vault` key/value and key management, plus
  `WorkOS.Vault.Crypto` for local encrypt/decrypt.
- **More product areas** — `WorkOS.ApiKeys`, `WorkOS.FeatureFlags`,
  `WorkOS.Radar`, `WorkOS.Widgets`, `WorkOS.Groups`, `WorkOS.Connect`,
  `WorkOS.Pipes`, `WorkOS.Agents`, and `WorkOS.Actions` (AuthKit Actions
  verification and response signing).
- **Organization membership lifecycle** —
  `update_organization_membership/4`, `deactivate_organization_membership/3`,
  and `reactivate_organization_membership/3`.

## Getting help

If you hit a migration issue this guide doesn't cover, please
[open an issue](https://github.com/workos/workos-elixir/issues).
