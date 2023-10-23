import Config

workos_api_key = System.get_env("WORKOS_API_KEY")
workos_client_id = System.get_env("WORKOS_CLIENT_ID")

if workos_api_key and workos_client_id do
  config :workos, WorkOS.Client, api_key: workos_api_key, client_id: workos_client_id
else
  config :tesla, adapter: Tesla.Mock
  config :workos, WorkOS.Client, api_key: "test_123", client_id: "test_123"
end
