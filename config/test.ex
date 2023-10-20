import Config

if workos_api_key = System.get_env("WORKOS_API_KEY") do
  config :workos, WorkOs.Client, api_key: workos_api_key
else
  config :tesla, adapter: Tesla.Mock
  config :workos, WorkOs.Client, api_key: "re_123456789"
end
