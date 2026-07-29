# @oagen-ignore-file

defmodule WorkOS do
  @moduledoc """
  WorkOS SDK for Elixir.

  ## Usage

      client = WorkOS.client(api_key: "sk_...")

  All API functions take the client as their first argument and return
  `{:ok, result}` or `{:error, error}` tuples.
  """

  @version Mix.Project.config()[:version]

  @doc "The SDK version."
  @spec version() :: String.t()
  def version, do: @version

  @doc "Builds a new API client. See `WorkOS.Client.new/1` for options."
  @spec client(keyword()) :: WorkOS.Client.t()
  def client(opts \\ []), do: WorkOS.Client.new(opts)
end
