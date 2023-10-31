# WorkOS Elixir Library

> **Note:** this an experimental SDK and breaking changes may occur. We don't recommend using this in production since we can't guarantee its stability.

The WorkOS library for Elixir provides convenient access to the WorkOS API from applications written in Elixir.

## Documentation

See the [API Reference](https://workos.com/docs/reference/client-libraries) for Elixir usage examples.

## Installation

Add this package to the list of dependencies in your `mix.exs` file:

```ex
def deps do
  [{:workos, "~> 0.3.0"}]
end
```
The hex package can be found here: https://hex.pm/packages/workos

## Configuration

The WorkOS API relies on two configuration parameters, the `client_id` and the `api_key`. There are two ways to configure these values with this package.

### Recommended Method
In your `config/config.exs` file you can set the `:client_id` and `:api_key` scoped to `:workos` to be used globally by default across the SDK:

```ex
config :workos,
  client_id: "project_12345"
  api_key: "sk_12345",
```

Ideally, you should use environment variables to store protected keys like your `:api_key` like so:

```ex
config :workos,
  client_id: System.get_env("WORKOS_CLIENT_ID"),
  api_key: System.get_env("WORKOS_API_KEY")
```

### Opts Method
Alternatively, you can override or avoid using these globally configured variables by passing a `:api_key` or `:client_id` directly to SDK methods via the optional `opts` parameter available on all methods:

```ex
WorkOS.SSO.get_authorization_url(%{
  connection: "<Connection ID>",
  redirect_uri: "https://workos.com"
}, [
  client_id: "project_12345",
  api_key: "sk_12345"
])
```
This is great if you need to switch client IDs on the fly.

## SDK Versioning

For our SDKs WorkOS follows a Semantic Versioning process where all releases will have a version X.Y.Z (like 1.0.0) pattern wherein Z would be a bug fix (I.e. 1.0.1), Y would be a minor release (1.1.0) and X would be a major release (2.0.0). We permit any breaking changes to only be released in major versions and strongly recommend reading changelogs before making any major version upgrades.

## More Information

* [Single Sign-On Guide](https://workos.com/docs/sso/guide)
* [Directory Sync Guide](https://workos.com/docs/directory-sync/guide)
* [Admin Portal Guide](https://workos.com/docs/admin-portal/guide)
* [Magic Link Guide](https://workos.com/docs/magic-link/guide)
