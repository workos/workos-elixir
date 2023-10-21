import Config

if workos_api_key =
     System.get_env("WORKOS_API_KEY") and workos_client_id = System.get_env("WORKOS_CLIENT_ID") do
  config :workos, WorkOS.Client, api_key: workos_api_key, client_id: workos_client_id
else
  config :tesla, adapter: Tesla.Mock
  config :workos, WorkOS.Client, api_key: "test_123", client_id: "test_123"
end
