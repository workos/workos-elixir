defmodule WorkOS.ClientIdMissingError do
  @moduledoc """
  Exception for when a request is made without a client ID.
  """

  defexception message: """
                 The client_id setting is required to make requests to WorkOS.
                 Please configure :client_id in config.exs, set the WORKOS_CLIENT_ID
                 environment variable, or pass into a new client instance.
               """
end
