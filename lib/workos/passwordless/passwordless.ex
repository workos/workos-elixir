defmodule WorkOS.Passwordless do
  import WorkOS.API

  @moduledoc """
  The Passwordless module provides convenience methods for working with
  passwordless sessions including the WorkOS Magic Link. You'll need a valid
  API key.

  @see https://workos.com/docs/sso/configuring-magic-link
  """

  @doc """
  Create a Passwordless Session.

  ### Parameters
  - params (map)
    - email (string) The email of the user to authenticate.
    - state (string) Optional parameter that the redirect URI
     received from WorkOS will contain. The state parameter can be used to
     encode arbitrary information to help restore application state between
     redirects.
    - type (string) The type of Passwordless Session to
     create. Currently, the only supported value is 'MagicLink'.
    - redirect_uri (string) The URI where users are directed
     after completing the authentication step. Must match a
     configured redirect URI on your WorkOS dashboard.

  ### Example
  WorkOS.Passwordless.create_session(%{
    email: "example@workos.com",
    redirect_uri: "https://workos.com/passwordless"
  })
  """
  def create_session(params, opts \\ [])

  def create_session(params, opts)
      when is_map_key(params, :email) or is_map_key(params, :connection) do
    query =
      process_params(params, [:email, :connection, :redirect_uri, :state, :type, :expires_in], %{
        type: "MagicLink"
      })

    post("/passwordless/sessions", query, opts)
  end

  def create_session(_params, _opts),
    do: raise(ArgumentError, message: "need email in params or connection id")

  @doc """
  Send a Passwordless Session via email.

  ### Parameters
  - session_id (string) The unique identifier of the
   Passwordless Session to send an email for.

  ### Example
  WorkOS.Passwordless.send_session("passwordless_session_12345")
  """
  def send_session(session_id, opts \\ []) do
    post("/passwordless/sessions/#{session_id}/send", %{}, opts)
  end
end
