# WorkOS workload identity for Google Cloud

Identity token provider for [WorkOS](https://workos.com) workload identity federation on Google Cloud. It fetches an identity token for the attached service account from the metadata server so the WorkOS SDK can exchange it for a short-lived access token. No API key is stored with the workload.

It works wherever the metadata server is reachable: Compute Engine, GKE, Cloud Run, Cloud Functions and App Engine.

This package does not depend on `workos`. It has no dependencies beyond OTP.

## Installation

Add it next to `workos` in `mix.exs`:

```elixir
def deps do
  [
    {:workos_workload_identity_gcp, "~> 0.1"}
  ]
end
```

## Usage

```elixir
{:ok, credentials} =
  WorkOS.WorkloadIdentity.Credentials.start_link(
    client_id: "client_...",
    environment_id: "environment_...",
    token_url: "https://.../oauth2/token",
    identity_token_provider: WorkOS.WorkloadIdentity.GCP.gcp_metadata("https://api.workos.com")
  )

client = WorkOS.Client.new(credentials: credentials)
```

`gcp_metadata/1` takes the audience and returns a zero-arity function. Each call makes one GET to the metadata server with a 10-second timeout, follows no redirect, and returns `{:ok, token}` or `{:error, %WorkOS.WorkloadIdentity.GCP.Error{}}`.
