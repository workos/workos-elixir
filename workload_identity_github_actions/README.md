# WorkOS workload identity for GitHub Actions

Identity token provider for [WorkOS](https://workos.com) workload identity federation on GitHub Actions. It fetches the workflow's OIDC token so the WorkOS SDK can exchange it for a short-lived access token. No API key is stored in the repository.

This package does not depend on `workos`. It has no dependencies beyond OTP.

## Installation

Add it next to `workos` in `mix.exs`:

```elixir
def deps do
  [
    {:workos_workload_identity_github_actions, "~> 0.1"}
  ]
end
```

## Usage

The workflow or job must grant the token permission:

```yaml
permissions:
  id-token: write
```

```elixir
{:ok, credentials} =
  WorkOS.WorkloadIdentity.Credentials.start_link(
    client_id: "client_...",
    environment_id: "environment_...",
    token_url: "https://.../oauth2/token",
    identity_token_provider:
      WorkOS.WorkloadIdentity.GitHubActions.github_actions("https://api.workos.com")
  )

client = WorkOS.Client.new(credentials: credentials)
```

`github_actions/1` takes the audience and returns a zero-arity function. Each call reads `ACTIONS_ID_TOKEN_REQUEST_URL` and `ACTIONS_ID_TOKEN_REQUEST_TOKEN`, makes one GET with a 10-second timeout, follows no redirect, and returns `{:ok, token}` or `{:error, %WorkOS.WorkloadIdentity.GitHubActions.Error{}}`.
