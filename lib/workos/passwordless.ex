defmodule WorkOS.Passwordless do
  @moduledoc """
  Manage Magic Link API in WorkOS.

  @see https://workos.com/docs/reference/magic-link
  """

  alias WorkOS.Passwordless.Session
  alias WorkOS.Passwordless.Session.Send

  @doc """
  Creates a Passwordless Session for a Magic Link Connection

  Parameter options:
    * `:email` - The email of the user to authenticate. (required)
    * `:type` - The type of Passwordless Session to create. (required)
    * `:redirect_uri` - Optional parameter that a developer can choose to include in their authorization URL.
    * `:expires_in` - The number of seconds the Passwordless Session should live before expiring.
    * `:state` - Optional parameter that a developer can choose to include in their authorization URL.

  """
  @spec create_session(map()) :: WorkOS.Client.response(Session.t())
  @spec create_session(WorkOS.Client.t(), map()) ::
          WorkOS.Client.response(Session.t())
  def create_session(client \\ WorkOS.client(), opts)
      when is_map_key(opts, :email) and is_map_key(opts, :type) do
    WorkOS.Client.post(
      client,
      Session,
      "/passwordless/sessions",
      %{
        email: opts[:email],
        type: opts[:type],
        redirect_uri: opts[:redirect_uri],
        expires_in: opts[:expires_in],
        state: opts[:state]
      }
    )
  end

  @doc """
  Emails a user the Magic Link confirmation URL, given a Passwordless session ID.
  """
  @spec send_session(WorkOS.Client.t(), String.t()) ::
          WorkOS.Client.response(Send)
  def send_session(client, session_id) do
    WorkOS.Client.post(
      client,
      Send,
      "/passwordless/sessions/:id",
      %{},
      opts: [
        path_params: [id: session_id]
      ]
    )
  end
end
