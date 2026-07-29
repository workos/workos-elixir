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

Client configuration is per-instance — there is no global state. Options: `:api_key`, `:base_url`, `:timeout`, `:max_retries`, `:req_options`. Per-request options (`:headers`, `:timeout`, `:idempotency_key`, `:query`) can be passed as the final argument to any API function.

### Pagination

List endpoints return a `WorkOS.Page`. Use `WorkOS.Page.stream/1` to lazily iterate across every page:

```elixir
{:ok, page} = WorkOS.Organizations.list_organizations(client)

page
|> WorkOS.Page.stream()
|> Enum.each(&IO.inspect/1)
```

## SDK Versioning

For our SDKs WorkOS follows a Semantic Versioning process where all releases will have a version X.Y.Z (like 1.0.0) pattern wherein Z would be a bug fix (I.e. 1.0.1), Y would be a minor release (1.1.0) and X would be a major release (2.0.0). We permit any breaking changes to only be released in major versions and strongly recommend reading changelogs before making any major version upgrades.

## More Information

- [User Management Guide](https://workos.com/docs/user-management)
- [Single Sign-On Guide](https://workos.com/docs/sso/guide)
- [Directory Sync Guide](https://workos.com/docs/directory-sync/guide)
- [Admin Portal Guide](https://workos.com/docs/admin-portal/guide)
- [Magic Link Guide](https://workos.com/docs/magic-link/guide)
- [Domain Verification Guide](https://workos.com/docs/domain-verification/guide)
