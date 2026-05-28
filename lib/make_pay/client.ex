defmodule MakePay.Client do
  @moduledoc """
  Server-side MakePay Partner API client.

  The client sends merchant key credentials in MakePay's partner headers:
  `X-MakeCrypto-Key-Id` and `X-MakeCrypto-Key-Secret`.
  """

  alias MakePay.Error
  alias MakePay.Transport.Httpc

  @default_base_url "https://www.makecrypto.io"
  @default_timeout 15_000

  defstruct base_url: @default_base_url,
            key_id: nil,
            key_secret: nil,
            timeout: @default_timeout,
            transport: Httpc

  @type t :: %__MODULE__{
          base_url: String.t(),
          key_id: String.t(),
          key_secret: String.t(),
          timeout: pos_integer(),
          transport: module()
        }

  @type api_result :: {:ok, map()} | {:error, Error.t()}

  @doc """
  Creates a client from options, application config, or environment variables.

  Supported options are `:key_id`, `:key_secret`, `:base_url`, `:timeout`, and
  `:transport`.
  """
  @spec new(keyword()) :: {:ok, t()} | {:error, Error.t()}
  def new(opts \\ []) do
    with {:ok, key_id} <- required_value(:key_id, opts, "MAKEPAY_KEY_ID"),
         {:ok, key_secret} <- required_value(:key_secret, opts, "MAKEPAY_KEY_SECRET") do
      {:ok,
       %__MODULE__{
         base_url: normalize_base_url(config_value(:base_url, opts, @default_base_url)),
         key_id: key_id,
         key_secret: key_secret,
         timeout: config_value(:timeout, opts, @default_timeout),
         transport: config_value(:transport, opts, Httpc)
       }}
    end
  end

  @doc "Creates a client and raises `MakePay.Error` when configuration is invalid."
  @spec new!(keyword()) :: t()
  def new!(opts \\ []) do
    case new(opts) do
      {:ok, client} -> client
      {:error, error} -> raise error
    end
  end

  @doc "Creates a hosted MakePay payment link."
  @spec create_payment_link(t(), map()) :: api_result()
  def create_payment_link(%__MODULE__{} = client, attrs) when is_map(attrs) do
    request(client, :post, "/api/partner/v1/makepay/payment-links", payment_link_body(attrs))
  end

  @doc "Fetches a hosted MakePay payment link by UID."
  @spec get_payment_link(t(), String.t()) :: api_result()
  def get_payment_link(%__MODULE__{} = client, uid) when is_binary(uid) do
    request(client, :get, "/api/partner/v1/makepay/payment-links/#{URI.encode_www_form(uid)}")
  end

  @doc "Creates or updates a MakePay customer."
  @spec create_customer(t(), map()) :: api_result()
  def create_customer(%__MODULE__{} = client, attrs) when is_map(attrs) do
    request(client, :post, "/api/partner/v1/makepay/customers", customer_body(attrs))
  end

  @doc "Creates a MakePay bookkeeping invoice."
  @spec create_bookkeeping_invoice(t(), map()) :: api_result()
  def create_bookkeeping_invoice(%__MODULE__{} = client, attrs) when is_map(attrs) do
    request(client, :post, "/api/partner/v1/makepay/bookkeeping/invoices", invoice_body(attrs))
  end

  @doc "Creates a hosted payment link for a MakePay bookkeeping invoice."
  @spec create_invoice_payment_link(t(), String.t(), keyword()) :: api_result()
  def create_invoice_payment_link(%__MODULE__{} = client, invoice_id, opts \\ [])
      when is_binary(invoice_id) do
    request(
      client,
      :post,
      "/api/partner/v1/makepay/bookkeeping/invoices/#{URI.encode_www_form(invoice_id)}/payment-link",
      %{
        "status" => Keyword.get(opts, :status, "active"),
        "sendPaymentRequestEmail" => Keyword.get(opts, :send_payment_request_email, true)
      }
    )
  end

  @doc false
  @spec request(t(), atom(), String.t(), nil | binary() | map() | list(), keyword()) :: api_result()
  def request(%__MODULE__{} = client, method, path, payload \\ nil, opts \\ []) do
    with {:ok, request} <- build_request(client, method, path, payload),
         {:ok, response} <- execute(client, request, opts) do
      decode_response(response.status, response.body)
    end
  end

  @doc false
  @spec build_request(t(), atom(), String.t(), nil | binary() | map() | list()) ::
          {:ok, map()} | {:error, Error.t()}
  def build_request(%__MODULE__{} = client, method, path, payload \\ nil) do
    with {:ok, body} <- encode_payload(payload) do
      {:ok,
       %{
         method: method,
         url: endpoint(client.base_url, path),
         headers: headers(client),
         body: body
       }}
    end
  end

  defp execute(client, request, opts) do
    request_opts = Keyword.put_new(opts, :timeout, client.timeout)

    case client.transport.request(
           request.method,
           request.url,
           request.headers,
           request.body,
           request_opts
         ) do
      {:ok, %{status: _status, body: _body} = response} ->
        {:ok, response}

      {:error, %Error{} = error} ->
        {:error, error}

      {:error, reason} ->
        {:error, Error.transport(reason)}
    end
  end

  defp decode_response(status, body) when status in 200..299 do
    decode_body(body)
  end

  defp decode_response(status, body) do
    decoded =
      case decode_body(body) do
        {:ok, value} -> value
        {:error, _error} -> body
      end

    {:error, Error.http(status, decoded)}
  end

  defp decode_body(body) when body in [nil, ""] do
    {:ok, %{}}
  end

  defp decode_body(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded} -> {:ok, decoded}
      {:error, reason} -> {:error, Error.decoding(reason)}
    end
  end

  defp encode_payload(nil), do: {:ok, ""}
  defp encode_payload(payload) when is_binary(payload), do: {:ok, payload}

  defp encode_payload(payload) when is_map(payload) or is_list(payload) do
    case Jason.encode(payload) do
      {:ok, body} -> {:ok, body}
      {:error, reason} -> {:error, Error.encoding(reason)}
    end
  end

  defp headers(client) do
    [
      {"Accept", "application/json"},
      {"Content-Type", "application/json"},
      {"X-MakeCrypto-Key-Id", client.key_id},
      {"X-MakeCrypto-Key-Secret", client.key_secret}
    ]
  end

  defp endpoint(base_url, path) do
    normalize_base_url(base_url) <> "/" <> String.trim_leading(path, "/")
  end

  defp normalize_base_url(base_url) do
    base_url
    |> to_string()
    |> String.trim_trailing("/")
  end

  defp required_value(key, opts, env_key) do
    case config_value(key, opts, nil) || System.get_env(env_key) do
      value when is_binary(value) and value != "" ->
        {:ok, value}

      _missing ->
        {:error, Error.missing_config(key)}
    end
  end

  defp config_value(key, opts, default) do
    Keyword.get(opts, key) || Application.get_env(:make_pay, key, default)
  end

  defp payment_link_body(attrs) do
    %{
      "status" => get_attr(attrs, :status, "active"),
      "sendPaymentRequestEmail" => get_attr(attrs, :send_payment_request_email, true),
      "payload" =>
        attrs
        |> project_keys(%{
          title: "title",
          description: "description",
          amount: "amount",
          currency: "currency",
          order_id: "orderId",
          customer_email: "customerEmail",
          return_url: "returnUrl",
          success_url: "successUrl",
          failure_url: "failureUrl",
          metadata: "metadata"
        })
        |> compact()
    }
  end

  defp customer_body(attrs) do
    attrs
    |> project_keys(%{
      id: "id",
      customer_id: "id",
      email: "email",
      name: "name",
      metadata: "metadata"
    })
    |> compact()
  end

  defp invoice_body(attrs) do
    attrs
    |> project_keys(%{
      customer_email: "customerEmail",
      customer_name: "customerName",
      amount: "amount",
      currency: "currency",
      due_date: "dueDate",
      line_items: "lineItems",
      metadata: "metadata"
    })
    |> compact()
  end

  defp project_keys(attrs, mapping) do
    Enum.reduce(mapping, %{}, fn {source_key, target_key}, acc ->
      case fetch_attr(attrs, source_key) do
        {:ok, value} -> Map.put(acc, target_key, value)
        :error -> acc
      end
    end)
  end

  defp fetch_attr(attrs, key) do
    string_key = Atom.to_string(key)

    cond do
      Map.has_key?(attrs, key) -> {:ok, Map.fetch!(attrs, key)}
      Map.has_key?(attrs, string_key) -> {:ok, Map.fetch!(attrs, string_key)}
      true -> :error
    end
  end

  defp get_attr(attrs, key, default) do
    case fetch_attr(attrs, key) do
      {:ok, value} -> value
      :error -> default
    end
  end

  defp compact(map) do
    Map.reject(map, fn {_key, value} -> is_nil(value) end)
  end
end
