defmodule MakePay.Transport.Httpc do
  @moduledoc """
  Default MakePay transport built on Erlang `:httpc`.

  Applications that already standardize on another HTTP client can inject a
  transport module that implements `MakePay.Transport`.
  """

  @behaviour MakePay.Transport

  @impl MakePay.Transport
  def request(method, url, headers, body, opts) do
    request = httpc_request(method, url, headers, body)

    :httpc.request(method, request, http_options(opts), body_format: :binary)
    |> normalize_response()
  end

  defp httpc_request(:get, url, headers, _body) do
    {String.to_charlist(url), charlist_headers(headers)}
  end

  defp httpc_request(_method, url, headers, body) do
    {String.to_charlist(url), charlist_headers(headers), 'application/json', body || ""}
  end

  defp charlist_headers(headers) do
    Enum.map(headers, fn {key, value} ->
      {String.to_charlist(key), String.to_charlist(value)}
    end)
  end

  defp http_options(opts) do
    [
      timeout: Keyword.get(opts, :timeout, 15_000),
      connect_timeout: Keyword.get(opts, :connect_timeout, 10_000)
    ]
  end

  defp normalize_response({:ok, {{_version, status, _reason}, headers, body}}) do
    {:ok,
     %{
       status: status,
       headers: normalize_headers(headers),
       body: body || ""
     }}
  end

  defp normalize_response({:error, reason}), do: {:error, reason}

  defp normalize_headers(headers) do
    Enum.map(headers, fn {key, value} ->
      {to_string(key), to_string(value)}
    end)
  end
end
