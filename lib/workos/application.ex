defmodule WorkOS.Application do
  @moduledoc false

  use Application

  alias WorkOS.Config

  @impl true
  def start(_type, _opts) do
    http_client = Config.client()

    maybe_http_client_spec =
      if Code.ensure_loaded?(http_client) and function_exported?(http_client, :child_spec, 0) do
        [http_client.child_spec()]
      else
        []
      end

    if http_client == WorkOS.HackneyClient do
      unless Code.ensure_loaded?(:hackney) do
        raise """
        cannot start the :workos application because the HTTP client is set to \
        WorkOS.HackneyClient (which is the default), but the Hackney library is not loaded. \
        Add :hackney to your dependencies to fix this.
        """
      end

      case Application.ensure_all_started(:hackney) do
        {:ok, _apps} -> :ok
        {:error, reason} -> raise "failed to start the :hackney application: #{inspect(reason)}"
      end
    end

    validate_json_config!()
  end

  defp validate_json_config!() do
    case Config.json_library() do
      nil ->
        raise ArgumentError.exception("nil is not a valid :json_library configuration")

      library ->
        try do
          with {:ok, %{}} <- library.decode("{}"),
               {:ok, "{}"} <- library.encode(%{}) do
            :ok
          else
            _ ->
              raise ArgumentError.exception(
                      "configured :json_library #{inspect(library)} does not implement decode/1 and encode/1"
                    )
          end
        rescue
          UndefinedFunctionError ->
            reraise ArgumentError.exception("""
                    configured :json_library #{inspect(library)} is not available or does not implement decode/1 and encode/1.
                    Do you need to add #{inspect(library)} to your mix.exs?
                    """),
                    __STACKTRACE__
        end
    end
  end
end
