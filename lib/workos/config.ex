defmodule WorkOS.Config do
  @moduledoc false

  def client, do: Application.get_env(:workos, :client, WorkOS.HackneyClient)

  def hackney_opts, do: Application.get_env(:workos, :hackney_opts, [])

  def json_library, do: Application.get_env(:workos, :json_library, Jason)
end
