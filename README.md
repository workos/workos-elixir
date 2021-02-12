Note: this SDK is currently in beta and breaking changes may occur. Please create an issue if you come across a bug.

# workos-elixir

WorkOS official Elixir package for interacting with WorkOS APIs

## Documentation

Complete documentation for the latest version of WorkOS Ruby Gem can be found [here](https://workos-inc.github.io/workos-ruby/).

## Installation
Add this package to the list of dependencies in your `mix.exs` file:
```
def deps do
  [{:workos, "~> 0.1.1"}]
end
```
The hex package can be found here: https://hex.pm/packages/workos

## Configuration
The WorkOS API relies on two configuration parameters, the `client_id` and the `api_key`. There are two ways to configure these values with this package.

### Recommended Method
In your `config/config.exs` file you can set the `:client_id` and `:api_key` scoped to `:workos` to be used globally by default across the SDK:
```
config :workos, 
  client_id: "project_12345"
  api_key: "sk_12345",
```

Ideally, you should use environment variables to store protected keys like your `:api_key` like so:
```
config :workos, 
  client_id: System.get_env("WORKOS_CLIENT_ID"),
  api_key: System.get_env("WORKOS_API_KEY")
```

### Opts Method
Alternatively, you can override or avoid using these globally configured variables by passing a `:api_key` or `:client_id` directly to SDK methods via the optional `opts` parameter available on all methods:
```
WorkOS.SSO.get_authorization_url(%{
  domain: "workos.com",
  redirect_uri: "https://workos.com"
}, [
  client_id: "project_12345",
  api_key: "sk_12345"
])
```
This is great if you need to switch client IDs on the fly.

## Supported Functionality
### Passwordless
The Magic Link Module provides methods for authenticating a Passwordless user via WorkOS.

See our [API
Reference](https://workos.com/docs/sso/configuring-magic-link)
for more information on Passwordless.

### SSO
The SSO Module provides convenient methods for authenticating a Single Sign On (SSO) user via WorkOS. WorkOS SSO follows the OAuth 2.0 specification.

See our [API
Reference](https://docs.workos.com/sso/overview)
for more information on SSO.

### Portal
See our [API
Reference](https://workos.com/docs/admin-portal/guide)
for more information on Portal.

### Directory Sync
See our [API
Reference](https://docs.workos.com/directory-sync/overview)
for more information on Directory Sync.
