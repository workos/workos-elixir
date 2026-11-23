# @oagen-ignore-file

defmodule WorkOS.CredentialSnapshot do
  @moduledoc """
  The credential one HTTP attempt is sent with.

  A snapshot is immutable. `WorkOS.Client` resolves one before every HTTP
  attempt, sets its headers on the request, and keeps it for that attempt, so
  a 401 can invalidate exactly the credential that was rejected.

    * `:headers` — the authorization headers for this attempt
    * `:generation` — opaque; identifies the credential the headers came from
    * `:recoverable` — whether a 401 on this snapshot is worth one re-resolve

  The headers hold a bearer token, so they are left out when a snapshot is
  inspected.
  """

  @derive {Inspect, only: [:generation, :recoverable]}
  @enforce_keys [:headers, :generation, :recoverable]
  defstruct [:headers, :generation, :recoverable]

  @type t :: %__MODULE__{
          headers: [{String.t(), String.t()}],
          generation: term(),
          recoverable: boolean()
        }
end
