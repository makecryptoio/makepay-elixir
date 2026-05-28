defmodule MakePay.Phoenix.WebhookPlug do
  @moduledoc """
  Plug-compatible endpoint for MakePay webhook routes.

  Phoenix applications can forward a route to this module and pass a handler
  function. The raw request body is read before JSON parsing so the signature
  can be verified exactly as delivered.
  """

  @default_read_opts [length: 2_000_000, read_length: 1_000_000, read_timeout: 15_000]

  @doc false
  def init(opts), do: opts

  @doc false
  def call(conn, opts) do
    secret = Keyword.get(opts, :secret) || Application.get_env(:make_pay, :webhook_secret)
    handler = Keyword.get(opts, :handler, fn _event, conn -> conn end)
    tolerance_seconds = Keyword.get(opts, :tolerance_seconds, 300)

    with {:ok, secret} <- require_secret(secret),
         {:ok, raw_body, conn} <- read_full_body(conn, Keyword.get(opts, :read_body, [])),
         {:ok, signature_header} <- signature_header(conn),
         {:ok, event} <-
           MakePay.Webhook.parse_event(raw_body, signature_header, secret,
             tolerance_seconds: tolerance_seconds
           ) do
      dispatch_handler(conn, event, handler)
    else
      {:error, :missing_secret} ->
        json(conn, 500, %{ok: false, error: "Missing MakePay webhook secret."})

      {:error, :missing_signature} ->
        json(conn, 401, %{ok: false, error: "Missing MakePay signature."})

      {:error, reason} ->
        json(conn, 401, %{ok: false, error: to_string(reason)})

      {:error, reason, conn} ->
        json(conn, 400, %{ok: false, error: to_string(reason)})
    end
  end

  defp dispatch_handler(conn, event, handler) when is_function(handler, 2) do
    handler
    |> handler_result(event, conn)
    |> response(conn)
  end

  defp dispatch_handler(conn, event, {module, function}) when is_atom(module) and is_atom(function) do
    response(apply(module, function, [event, conn]), conn)
  end

  defp handler_result(handler, event, conn), do: handler.(event, conn)

  defp response(:ok, conn), do: json(conn, 200, %{ok: true})
  defp response({:ok, body}, conn), do: json(conn, 200, body)
  defp response({:error, reason}, conn), do: json(conn, 422, %{ok: false, error: to_string(reason)})
  defp response(%{__struct__: Plug.Conn} = conn, _original_conn), do: conn
  defp response(%{} = body, conn), do: json(conn, 200, body)
  defp response(conn, _original_conn), do: conn

  defp read_full_body(conn, read_opts) do
    conn
    |> do_read_body(Keyword.merge(@default_read_opts, read_opts), [])
  end

  defp do_read_body(conn, opts, parts) do
    case Plug.Conn.read_body(conn, opts) do
      {:ok, part, conn} ->
        {:ok, IO.iodata_to_binary(Enum.reverse([part | parts])), conn}

      {:more, part, conn} ->
        do_read_body(conn, opts, [part | parts])

      {:error, reason} ->
        {:error, reason, conn}
    end
  end

  defp require_secret(secret) when is_binary(secret) and secret != "", do: {:ok, secret}
  defp require_secret(_secret), do: {:error, :missing_secret}

  defp signature_header(conn) do
    case Plug.Conn.get_req_header(conn, "x-makepay-signature") do
      [signature | _rest] when signature != "" -> {:ok, signature}
      _missing -> {:error, :missing_signature}
    end
  end

  defp json(conn, status, body) do
    encoded = Jason.encode!(body)

    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.send_resp(status, encoded)
  end
end
