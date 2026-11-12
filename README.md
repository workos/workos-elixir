# WorkOS Elixir Library

The WorkOS library for Elixir provides convenient access to the WorkOS API from applications written in Elixir.

## Documentation

See the [API Reference](https://workos.com/docs/reference/client-libraries) for Elixir usage examples.

## Installation

Add this package to the list of dependencies in your `mix.exs` file:

```elixir
def deps do
  [{:workos, "~> 1.0"}]
end
```

Requires Elixir 1.18 or later.

## Usage

Build a client with your API key, then pass it to any API function:

```elixir
client = WorkOS.client(api_key: "sk_example_123456789")
# or set the WORKOS_API_KEY environment variable and call WorkOS.client()

{:ok, organization} = WorkOS.Organizations.get_organization(client, "org_01EHZNVPK3SFK441A1RGBFSHRT")
```

All API functions take the client as their first argument and return `{:ok, result}` or `{:error, error}` tuples. Errors are typed: `WorkOS.ApiError` for non-2xx API responses (with a `:kind` atom such as `:not_found`) and `WorkOS.TransportError` for network failures.

Client configuration is per-instance — there is no global state. Options: `:api_key`, `:credentials`, `:base_url`, `:timeout`, `:max_retries`, `:req_options`. Per-request options (`:headers`, `:timeout`, `:idempotency_key`, `:query`) can be passed as the final argument to any API function.

### Pagination

List endpoints return a `WorkOS.Page`. Use `WorkOS.Page.stream/1` to lazily iterate across every page:

```elixir
{:ok, page} = WorkOS.Organizations.list_organizations(client)

page
|> WorkOS.Page.stream()
|> Enum.each(&IO.inspect/1)
```

### Workload identity

A workload that already has an identity from its platform (a GitHub Actions job, a Google Cloud service account, an AWS role) can authenticate without a stored API key. The SDK exchanges the platform's identity token for a short-lived WorkOS access token, caches it, and refreshes it before it expires.

Start a credentials process and pass it to the client:

```elixir
{:ok, credentials} =
  WorkOS.WorkloadIdentity.Credentials.start_link(
    client_id: "client_...",
    environment_id: "environment_...",
    token_url: "https://.../oauth2/token",
    identity_token_provider: provider
  )

client = WorkOS.Client.new(credentials: credentials)
```

`:client_id`, `:token_url`, `:environment_id` and `:scope` fall back to the `WORKOS_CLIENT_ID`, `WORKOS_WIF_TOKEN_URL`, `WORKOS_ENVIRONMENT_ID` and `WORKOS_WIF_SCOPE` environment variables. Passing both `api_key:` and `credentials:` raises `WorkOS.ConfigurationError`. With `credentials:`, `WORKOS_API_KEY` is ignored.

In an application, supervise the process under a name of your choosing and build clients from the name:

```elixir
children = [
  {WorkOS.WorkloadIdentity.Credentials, name: MyApp.WorkOSCredentials, identity_token_provider: provider}
]

client = WorkOS.Client.new(credentials: MyApp.WorkOSCredentials)
```

The `provider` returns the workload's identity token. Each platform's provider is its own package, with no dependency on `workos`. Add the one you need:

```elixir
def deps do
  [
    {:workos_workload_identity_github_actions, "~> 0.1"},
    # or {:workos_workload_identity_gcp, "~> 0.1"}
    # or {:workos_workload_identity_aws, "~> 0.1"}
  ]
end
```

```elixir
# GitHub Actions. The workflow or job needs `permissions: id-token: write`.
provider = WorkOS.WorkloadIdentity.GitHubActions.github_actions("https://api.workos.com")

# Google Cloud: Compute Engine, GKE, Cloud Run, Cloud Functions, App Engine.
provider = WorkOS.WorkloadIdentity.GCP.gcp_metadata("https://api.workos.com")

# AWS: Lambda, EC2, ECS, EKS. The region is optional when AWS_REGION is set.
provider = WorkOS.WorkloadIdentity.AWS.aws_sts("https://api.workos.com", "us-east-1")
```

The argument is the audience the identity token is requested for.

No package is needed when the token is already in a file or an environment variable, or when you fetch it yourself. A provider is any zero-arity function (or `{module, function, args}` tuple) that returns `{:ok, token}` or `{:error, reason}`:

```elixir
provider = WorkOS.WorkloadIdentity.token_file("/var/run/secrets/tokens/workos")
provider = WorkOS.WorkloadIdentity.token_env("MY_IDENTITY_TOKEN")
provider = fn -> MyApp.Identity.fetch_token() end
```

When the exchange fails, API functions return `{:error, %WorkOS.WorkloadIdentityError{}}`. Its `:code` is the OAuth error code from the token endpoint (for example `"invalid_grant"`), and its `:hint` says what to check.

## SDK Versioning

For our SDKs WorkOS follows a Semantic Versioning process where all releases will have a version X.Y.Z (like 1.0.0) pattern wherein Z would be a bug fix (I.e. 1.0.1), Y would be a minor release (1.1.0) and X would be a major release (2.0.0). We permit any breaking changes to only be released in major versions and strongly recommend reading changelogs before making any major version upgrades.

## More Information

- [User Management Guide](https://workos.com/docs/user-management)
- [Single Sign-On Guide](https://workos.com/docs/sso/guide)
- [Directory Sync Guide](https://workos.com/docs/directory-sync/guide)
- [Admin Portal Guide](https://workos.com/docs/admin-portal/guide)
- [Magic Link Guide](https://workos.com/docs/magic-link/guide)
- [Domain Verification Guide](https://workos.com/docs/domain-verification/guide)
