# @oagen-ignore-file — hand-maintained; these endpoints are not in the OpenAPI spec.

defmodule WorkOS.Passwordless do
  @moduledoc """
  Magic Link passwordless sessions.

  These endpoints are not part of the OpenAPI spec, so this module is
  hand-maintained rather than generated.

      {:ok, session} =
        WorkOS.Passwordless.create_session(client, %{
          email: "user@example.com",
          type: "MagicLink"
        })

      {:ok, _} = WorkOS.Passwordless.send_session(client, session.id)
  """

  defmodule Session do
    @moduledoc """
    A passwordless (Magic Link) session.
    """

    defstruct [:id, :email, :expires_at, :link, :object]

    @type t :: %__MODULE__{
            id: String.t(),
            email: String.t(),
            expires_at: String.t(),
            link: String.t(),
            object: String.t()
          }

    @doc false
    @spec from_map(map()) :: t()
    def from_map(map) when is_map(map) do
      %__MODULE__{
        id: map["id"],
        email: map["email"],
        expires_at: map["expires_at"],
        link: map["link"],
        object: map["object"]
      }
    end
  end

  @doc """
  Creates a passwordless session (`POST /passwordless/sessions`).

  ## Parameters

    * `params` — request body map. Required: `:email`, `:type` (`"MagicLink"`).
      Optional: `:redirect_uri`, `:state`, `:expires_in`.
    * `opts` — per-request options (see `WorkOS.Client.request/5`)
  """
  @spec create_session(WorkOS.Client.t(), map(), keyword()) ::
          {:ok, Session.t()} | {:error, WorkOS.Error.error()}
  def create_session(client, params \\ %{}, opts \\ []) do
    params = WorkOS.Client.merge_defaults(params, %{"type" => "MagicLink"})

    with {:ok, body} <-
           WorkOS.Client.request(client, :post, "/passwordless/sessions", params, opts) do
      {:ok, WorkOS.Cast.nested(body, &Session.from_map/1)}
    end
  end

  @doc """
  Emails the Magic Link for a session (`POST /passwordless/sessions/:id/send`).
  """
  @spec send_session(WorkOS.Client.t(), String.t(), keyword()) ::
          {:ok, term()} | {:error, WorkOS.Error.error()}
  def send_session(client, session_id, opts \\ []) do
    WorkOS.Client.request(
      client,
      :post,
      "/passwordless/sessions/#{URI.encode(session_id, &URI.char_unreserved?/1)}/send",
      %{},
      opts
    )
  end
end
