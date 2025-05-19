# WorkOS Elixir Library

> **Note:** this an experimental SDK and breaking changes may occur. We don't recommend using this in production since we can't guarantee its stability.

The WorkOS library for Elixir provides convenient access to the WorkOS API from applications written in Elixir.

## Documentation

See the [API Reference](https://workos.com/docs/reference/client-libraries) for Elixir usage examples.

## Installation

Add this package to the list of dependencies in your `mix.exs` file:

```ex
def deps do
  [{:workos, "~> 1.1"}]
end
```

## Configuration

### Configure WorkOS API key & client ID on your app config

```ex
config :workos, WorkOS.Client,
      api_key: "sk_example_123456789",
      client_id: "client_123456789"
```

The only required config option is `:api_key` and `:client_id`.

By default, this library uses [Tesla](https://github.com/elixir-tesla/tesla) but it can be replaced via the `:client` option, according to the `WorkOS.Client` module behavior.

###

## SDK Versioning

For our SDKs WorkOS follows a Semantic Versioning process where all releases will have a version X.Y.Z (like 1.0.0) pattern wherein Z would be a bug fix (I.e. 1.0.1), Y would be a minor release (1.1.0) and X would be a major release (2.0.0). We permit any breaking changes to only be released in major versions and strongly recommend reading changelogs before making any major version upgrades.

## More Information

- [User Management Guide](https://workos.com/docs/user-management)
- [Single Sign-On Guide](https://workos.com/docs/sso/guide)
- [Directory Sync Guide](https://workos.com/docs/directory-sync/guide)
- [Admin Portal Guide](https://workos.com/docs/admin-portal/guide)
- [Magic Link Guide](https://workos.com/docs/magic-link/guide)
- [Domain Verification Guide](https://workos.com/docs/domain-verification/guide)
