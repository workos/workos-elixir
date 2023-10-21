import Config

config :workos, WorkOS.Client,
  client_id: System.get_env("WORKOS_CLIENT_ID"),
  api_key: System.get_env("WORKOS_API_KEY")
