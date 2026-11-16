# @oagen-ignore-file

defmodule WorkOS.TestServer do
  @moduledoc false

  # A minimal HTTP/1.1 server on a loopback port, for the tests that must go
  # through Req's own default adapter instead of a plug. It answers each
  # connection with the next canned response (the last one repeats) and sends
  # every request it reads to the test process, as
  # `{:request, ref, %{method: _, target: _, headers: _, body: _}}`.
  #
  # It runs under the test's supervisor, so it stops when the test ends.

  @type response :: {pos_integer(), [{String.t(), String.t()}], String.t()}

  @spec start([response(), ...]) :: %{url: String.t(), ref: reference()}
  def start([_ | _] = responses) do
    owner = self()
    ref = make_ref()

    _pid =
      ExUnit.Callbacks.start_supervised!(
        {Task, fn -> listen(responses, owner, ref) end},
        id: {__MODULE__, ref}
      )

    receive do
      {:listening, ^ref, port} -> %{url: "http://127.0.0.1:#{port}", ref: ref}
    after
      5_000 -> raise "test server did not start"
    end
  end

  defp listen(responses, owner, ref) do
    {:ok, listener} =
      :gen_tcp.listen(0, [
        :binary,
        packet: :http_bin,
        active: false,
        reuseaddr: true,
        ip: {127, 0, 0, 1}
      ])

    {:ok, port} = :inet.port(listener)
    send(owner, {:listening, ref, port})
    accept(listener, responses, owner, ref)
  end

  defp accept(listener, responses, owner, ref) do
    {:ok, socket} = :gen_tcp.accept(listener)
    send(owner, {:request, ref, read_request(socket)})

    {response, rest} = next(responses)
    :ok = :gen_tcp.send(socket, encode(response))
    :ok = :gen_tcp.close(socket)

    accept(listener, rest, owner, ref)
  end

  defp next([response]), do: {response, [response]}
  defp next([response | rest]), do: {response, rest}

  defp read_request(socket) do
    {:ok, {:http_request, method, {:abs_path, target}, _version}} =
      :gen_tcp.recv(socket, 0, 5_000)

    headers = read_headers(socket, %{})
    length = headers |> Map.get("content-length", "0") |> String.to_integer()

    %{
      method: to_string(method),
      target: target,
      headers: headers,
      body: read_body(socket, length)
    }
  end

  defp read_headers(socket, headers) do
    case :gen_tcp.recv(socket, 0, 5_000) do
      {:ok, {:http_header, _, name, _, value}} ->
        read_headers(socket, Map.put(headers, name |> to_string() |> String.downcase(), value))

      {:ok, :http_eoh} ->
        headers
    end
  end

  defp read_body(_socket, 0), do: ""

  defp read_body(socket, length) do
    :ok = :inet.setopts(socket, packet: :raw)
    {:ok, body} = :gen_tcp.recv(socket, length, 5_000)
    body
  end

  defp encode({status, headers, body}) do
    head =
      [{"content-length", Integer.to_string(byte_size(body))}, {"connection", "close"} | headers]
      |> Enum.map(fn {name, value} -> [name, ": ", value, "\r\n"] end)

    ["HTTP/1.1 ", Integer.to_string(status), " Mock\r\n", head, "\r\n", body]
  end
end
