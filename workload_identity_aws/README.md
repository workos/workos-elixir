# WorkOS workload identity for AWS

Identity token provider for [WorkOS](https://workos.com) workload identity federation on AWS. It asks STS for a web identity token (`GetWebIdentityToken`) for the workload's IAM role so the WorkOS SDK can exchange it for a short-lived access token. No API key is stored with the workload.

It works on Lambda, EC2, ECS and EKS. The AWS account must have outbound identity federation enabled, and the workload's IAM policy must allow `sts:GetWebIdentityToken`.

This package does not depend on `workos`. It depends on [`aws`](https://hex.pm/packages/aws), which builds and signs the STS request, and on [`aws_credentials`](https://hex.pm/packages/aws_credentials), which resolves and refreshes the workload's AWS credentials.

## Installation

Add it next to `workos` in `mix.exs`:

```elixir
def deps do
  [
    {:workos_workload_identity_aws, "~> 0.1"}
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
    identity_token_provider:
      WorkOS.WorkloadIdentity.AWS.aws_sts("https://api.workos.com", "us-east-1")
  )

client = WorkOS.Client.new(credentials: credentials)
```

`aws_sts/2` takes the audience and an optional region, and returns a zero-arity function. Without a region argument it uses `AWS_REGION`, then `AWS_DEFAULT_REGION`, then the region the credential chain reports; it raises `ArgumentError` when none is found. Each call makes one signed request to the regional STS endpoint, asks for an `RS256` token, and returns `{:ok, token}` or `{:error, %WorkOS.WorkloadIdentity.AWS.Error{}}`.

AWS credentials come from the `aws_credentials` application's default chain: environment variables, shared credential files, ECS task roles, EKS Pod Identity, IAM roles for service accounts, and EC2 instance profiles. See its documentation to change the chain.
