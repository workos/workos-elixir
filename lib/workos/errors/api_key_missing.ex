defmodule WorkOS.ApiKeyMissingError do
  @moduledoc """
  Exception for when a request is made without an API key.
  """

  defexception message: """
                 The api_key setting is required to make requests to WorkOS.
                 Please configure :api_key in config.exs, set the WORKOS_API_KEY
                 environment variable, or pass into a new client instance.
               """
end
