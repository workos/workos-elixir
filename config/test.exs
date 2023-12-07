import Config

workos_api_key = System.get_env("WORKOS_API_KEY")
workos_client_id = System.get_env("WORKOS_CLIENT_ID")

case {workos_api_key, workos_client_id} do
  {nil, nil} ->
    config :tesla, adapter: Tesla.Mock

    config :workos, WorkOS.Client,
      api_key: "sk_example_123456789",
      client_id: "client_123456789"

  {api_key, client_id} ->
    config :workos, WorkOS.Client, api_key: api_key, client_id: client_id
end
