# @oagen-ignore-file

defmodule WorkOS.WorkloadIdentity.Credentials do
  @moduledoc """
  Workload identity credentials: a process that exchanges the workload's
  identity token for a short-lived WorkOS access token, caches it, and
  refreshes it before it expires.

  Start one and pass it to the client. There is no global instance; every
  process has its own cache.

      {:ok, credentials} =
        WorkOS.WorkloadIdentity.Credentials.start_link(
          client_id: "client_...",
          environment_id: "environment_...",
          token_url: "https://.../oauth2/token",
          identity_token_provider: WorkOS.WorkloadIdentity.token_file("/run/workos/identity-token")
        )

      client = WorkOS.Client.new(credentials: credentials)

  In an application, put it in the supervision tree under a name of your
  choosing, so a restarted process is still reachable:

      children = [
        {WorkOS.WorkloadIdentity.Credentials,
         name: MyApp.WorkOSCredentials,
         token_url: "https://.../oauth2/token",
         identity_token_provider: WorkOS.WorkloadIdentity.token_env("MY_IDENTITY_TOKEN")}
      ]

      client = WorkOS.Client.new(credentials: MyApp.WorkOSCredentials)

  ## Options

    * `:identity_token_provider` — required. A zero-arity function or a
      `{module, function, args}` tuple that returns `{:ok, token}` or
      `{:error, reason}`. See `WorkOS.WorkloadIdentity`.
    * `:client_id` — the M2M application's client ID. Falls back to the
      `WORKOS_CLIENT_ID` environment variable.
    * `:token_url` — required. The exchange endpoint. There is no built-in
      default, and no environment variable is read for it.
    * `:environment_id` — optional, and set only here: no environment
      variable is read for it. When set, it is sent as the
      `x-url-environment-id` header on every API request. When it is left
      out, `nil` or an empty string, the header is not sent. The server binds
      a workload identity client to exactly one environment, so the header
      selects nothing. Setting it is a safety check: a value that names a
      different environment gets `403 environment_mismatch`.
    * `:resource` — the `resource` form field. Defaults to
      `https://api.workos.com`.
    * `:scope` — optional. The `scope` form field. It is left out of the
      exchange when it is not set, `nil` or an empty string. No environment
      variable is read for it.
    * `:name` — registers the process, as in `GenServer.start_link/3`.
    * `:req_options` — extra `Req` options merged into the exchange request
      (advanced; used by tests to inject `plug:`). The exchange never
      retries through Req, never follows a redirect and never sends an
      `Authorization` header, whatever is passed here.

  `WORKOS_CLIENT_ID` is the only environment variable the credentials read.
  An explicit `:client_id` always wins over it, and the variable never turns
  workload identity on by itself. Configuration is fixed once the process
  starts. A missing required option makes `start_link/1` return
  `{:error, %WorkOS.WorkloadIdentityError{code: "invalid_configuration"}}`.

  ## Behavior

    * The token is reused until less than `min(60 seconds, 20% of its
      lifetime)` remains. It is refreshed on demand, by the request that finds
      it inside that window; there is no background timer.
    * At most one exchange runs at a time. Callers that arrive while it runs
      wait for its result. A caller that stops waiting (its call times out)
      does not stop the exchange for the others.
    * The exchange has 30 seconds in total, including retries. A failed
      exchange is not cached; the next call starts a new one.
    * The token is held in memory only.
  """

  use GenServer

  @behaviour WorkOS.Credentials

  alias WorkOS.CredentialSnapshot
  alias WorkOS.WorkloadIdentity.Exchange
  alias WorkOS.WorkloadIdentityError

  @environment_header "x-url-environment-id"
  @default_resource "https://api.workos.com"
  @exchange_deadline_ms 30_000

  # A token is refreshed once less than min(60 s, lifetime / 5) remains.
  @refresh_threshold_ms 60_000
  @refresh_lifetime_divisor 5

  # The only environment variable the credentials read.
  @client_id_env "WORKOS_CLIENT_ID"

  # -- public API -------------------------------------------------------------

  @doc """
  Starts a credentials process linked to the caller. See the module
  documentation for options.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) when is_list(opts) do
    {name, opts} = Keyword.pop(opts, :name)

    with {:ok, config} <- config(opts) do
      GenServer.start_link(__MODULE__, config, if(name, do: [name: name], else: []))
    end
  end

  @doc """
  Returns the snapshot to send one HTTP attempt with: the access token as a
  bearer header, plus the environment header when an environment ID is set.

  Waits for a token exchange when no fresh token is cached, for at most
  `timeout` milliseconds. Giving up does not stop the exchange.
  """
  @impl WorkOS.Credentials
  @spec resolve(GenServer.server(), timeout()) ::
          {:ok, CredentialSnapshot.t()}
          | {:error, WorkloadIdentityError.t() | WorkOS.TransportError.t()}
  def resolve(server, timeout) do
    GenServer.call(server, :resolve, timeout)
  catch
    :exit, {:timeout, _call} ->
      {:error,
       %WorkOS.TransportError{
         message: "Timed out waiting for workload identity credentials.",
         reason: :timeout
       }}

    :exit, _reason ->
      {:error,
       %WorkOS.TransportError{
         message: "The workload identity credentials process is not running.",
         reason: :credentials_unavailable
       }}
  end

  @doc """
  Marks the token of the given generation as rejected, so the next
  `resolve/2` exchanges again. A generation that is no longer current is
  ignored: a late 401 for an old token does not discard a newer one.
  """
  @impl WorkOS.Credentials
  @spec invalidate(GenServer.server(), term()) :: :ok
  def invalidate(server, generation), do: GenServer.cast(server, {:invalidate, generation})

  # -- configuration ----------------------------------------------------------

  defp config(opts) do
    # `:clock`, `:sleep` and `:deadline_ms` are test seams.
    opts =
      Keyword.validate!(opts, [
        :client_id,
        :token_url,
        :environment_id,
        :resource,
        :scope,
        :identity_token_provider,
        req_options: [],
        clock: &monotonic_ms/0,
        sleep: &Process.sleep/1,
        deadline_ms: @exchange_deadline_ms
      ])

    with {:ok, client_id} <- required(opts, :client_id, @client_id_env),
         {:ok, token_url} <- required(opts, :token_url),
         {:ok, provider} <- provider(opts[:identity_token_provider]) do
      {:ok,
       %{
         client_id: client_id,
         token_url: token_url,
         # Optional, and only from the caller: no environment variable is read.
         environment_id: present(opts[:environment_id]),
         resource: present(opts[:resource]) || @default_resource,
         scope: present(opts[:scope]),
         identity_token_provider: provider,
         req_options: opts[:req_options],
         clock: opts[:clock],
         sleep: opts[:sleep],
         deadline_ms: opts[:deadline_ms]
       }}
    end
  end

  defp required(opts, key, env) do
    case present(opts[key]) || present(System.get_env(env)) do
      nil -> invalid_configuration("#{key} is required (or set #{env})")
      value -> {:ok, value}
    end
  end

  defp required(opts, key) do
    case present(opts[key]) do
      nil -> invalid_configuration("#{key} is required")
      value -> {:ok, value}
    end
  end

  defp provider(provider) when is_function(provider, 0), do: {:ok, provider}

  defp provider({module, function, args} = provider)
       when is_atom(module) and is_atom(function) and is_list(args),
       do: {:ok, provider}

  defp provider(nil), do: invalid_configuration("identity_token_provider is required")

  defp provider(_other) do
    invalid_configuration(
      "identity_token_provider must be a zero-arity function or a {module, function, args} tuple"
    )
  end

  defp invalid_configuration(description),
    do: {:error, WorkloadIdentityError.new("invalid_configuration", description)}

  defp present(value) when is_binary(value) and value != "", do: value
  defp present(_value), do: nil

  defp monotonic_ms, do: System.monotonic_time(:millisecond)

  # -- server -----------------------------------------------------------------
  #
  # State: the cached token with its lifetime, expiry and generation, and the
  # exchange in flight, if any. The generation starts at 0 with no token and
  # goes up by one each time a token is stored.
  #
  # The token is held as a zero-arity function, in the state and in the
  # exchange task's result. A function prints as `#Function<...>`, so the
  # token cannot show up in a crash report, a stack trace, `:sys.get_state/1`
  # or any other place the state or a message is inspected.

  @impl GenServer
  def init(config) do
    # The exchange task is linked so it stops with this process. Trapping
    # exits keeps a task that dies from taking the cache down with it.
    _ = Process.flag(:trap_exit, true)

    {:ok,
     %{config: config, token: nil, lifetime_ms: 0, expires_at: 0, generation: 0, inflight: nil}}
  end

  @impl GenServer
  def handle_call(:resolve, from, state) do
    if fresh?(state) do
      {:reply, {:ok, snapshot(state)}, state}
    else
      state = join_or_start_exchange(state)
      {:noreply, update_in(state.inflight.waiters, &[from | &1])}
    end
  end

  # An unknown request must not crash the process: the crash would take the
  # cached token with it.
  def handle_call(_request, _from, state), do: {:reply, {:error, :unknown_request}, state}

  @impl GenServer
  def handle_cast({:invalidate, generation}, %{generation: generation} = state),
    do: {:noreply, %{state | token: nil}}

  def handle_cast(_stale_generation_or_unknown, state), do: {:noreply, state}

  @impl GenServer
  def handle_info({ref, result}, %{inflight: %{task: %Task{ref: ref}}} = state) do
    _ = Process.demonitor(ref, [:flush])
    {:noreply, finish(state, result)}
  end

  def handle_info(
        {:DOWN, ref, :process, _pid, _reason},
        %{inflight: %{task: %Task{ref: ref}}} = state
      ) do
    {:noreply, finish(state, {:error, stopped("the token exchange stopped unexpectedly")})}
  end

  def handle_info({:exchange_deadline, ref}, %{inflight: %{task: %Task{ref: ref} = task}} = state) do
    result =
      case Task.shutdown(task, :brutal_kill) do
        {:ok, result} ->
          result

        _killed ->
          {:error, stopped("the token exchange did not finish within its deadline")}
      end

    {:noreply, finish(state, result)}
  end

  # Exit signals from finished tasks, and timers or monitors of an exchange
  # that is already over.
  def handle_info(_message, state), do: {:noreply, state}

  # -- cache ------------------------------------------------------------------

  defp fresh?(%{token: nil}), do: false

  defp fresh?(state),
    do: state.expires_at - now(state) >= refresh_threshold(state.lifetime_ms)

  defp refresh_threshold(lifetime_ms),
    do: min(@refresh_threshold_ms, div(lifetime_ms, @refresh_lifetime_divisor))

  defp now(%{config: %{clock: clock}}), do: clock.()

  defp snapshot(state) do
    %CredentialSnapshot{
      headers: [
        {"authorization", "Bearer " <> state.token.()}
        | environment_headers(state.config.environment_id)
      ],
      generation: state.generation,
      recoverable: true
    }
  end

  # The environment header is sent only when an environment ID is set.
  defp environment_headers(nil), do: []
  defp environment_headers(environment_id), do: [{@environment_header, environment_id}]

  # -- shared exchange ----------------------------------------------------------

  defp join_or_start_exchange(%{inflight: nil, config: config} = state) do
    task = Task.async(fn -> config |> Exchange.run() |> seal() end)
    timer = Process.send_after(self(), {:exchange_deadline, task.ref}, config.deadline_ms)
    %{state | inflight: %{task: task, timer: timer, waiters: []}}
  end

  defp join_or_start_exchange(state), do: state

  # The token is stored and the in-flight exchange cleared before any waiter
  # is replied to, so a caller that gets an error and calls again starts a
  # new exchange instead of joining the finished one.
  defp finish(%{inflight: %{timer: timer, waiters: waiters}} = state, result) do
    _ = Process.cancel_timer(timer)
    {reply, state} = store(%{state | inflight: nil}, result)
    Enum.each(waiters, &GenServer.reply(&1, reply))
    state
  end

  defp seal({:ok, token, lifetime_ms}), do: {:ok, fn -> token end, lifetime_ms}
  defp seal({:error, error}), do: {:error, error}

  defp store(state, {:ok, token, lifetime_ms}) when is_function(token, 0) do
    state = %{
      state
      | token: token,
        lifetime_ms: lifetime_ms,
        expires_at: now(state) + lifetime_ms,
        generation: state.generation + 1
    }

    {{:ok, snapshot(state)}, state}
  end

  defp store(state, {:error, %WorkloadIdentityError{} = error}), do: {{:error, error}, state}

  defp stopped(description), do: WorkloadIdentityError.new("exchange_failed", description)
end
