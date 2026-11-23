import Config

# This file configures the package's own test runs only. Configuration is not
# inherited by applications that depend on the package.
if config_env() == :test do
  # The tests stub the STS call. Keep the credential chain from reading
  # ~/.aws or probing the container and instance metadata services.
  config :aws_credentials, credential_providers: []

  config :logger, level: :warning
end
