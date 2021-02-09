ExUnit.start()

Application.put_env(:tesla, :adapter, Tesla.Mock)
Application.put_env(:workos, :api_key, "sk_TEST")
Application.put_env(:workos, :client_id, "project_TEST")
