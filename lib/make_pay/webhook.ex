defmodule MakePay.Webhook do
  @moduledoc """
  MakePay webhook signature verification.

  `X-MakePay-Signature` is expected to contain a Unix timestamp and v1 digest,
  for example `t=1700000000,v1=<hex>`. The v1 digest is HMAC-SHA256 over
  `timestamp.raw_body` using the webhook secret.
  """

  import Bitwise, only: [bor: 2, bxor: 2]

  @default_tolerance_seconds 300

  @type verify_error ::
          :missing_signature
          | :missing_secret
          | :invalid_signature_header
          | :invalid_signature
          | :timestamp_outside_tolerance
          | :invalid_json

  @doc "Returns true when the MakePay webhook signature is valid."
  @spec valid?(binary(), binary(), binary(), keyword()) :: boolean()
  def valid?(raw_body, signature_header, secret, opts \\ []) do
    verify(raw_body, signature_header, secret, opts) == :ok
  end

  @doc "Verifies the MakePay webhook signature."
  @spec verify(binary(), binary(), binary(), keyword()) :: :ok | {:error, verify_error()}
  def verify(raw_body, signature_header, secret, opts \\ []) do
    with {:ok, secret} <- require_secret(secret),
         {:ok, timestamp, signature} <- parse_signature_header(signature_header),
         :ok <- verify_timestamp(timestamp, opts),
         :ok <- verify_signature(raw_body, timestamp, signature, secret) do
      :ok
    end
  end

  @doc "Verifies the signature and decodes the JSON event body."
  @spec parse_event(binary(), binary(), binary(), keyword()) ::
          {:ok, map()} | {:error, verify_error()}
  def parse_event(raw_body, signature_header, secret, opts \\ []) do
    with :ok <- verify(raw_body, signature_header, secret, opts),
         {:ok, event} <- Jason.decode(raw_body) do
      {:ok, event}
    else
      {:error, %Jason.DecodeError{}} -> {:error, :invalid_json}
      {:error, reason} -> {:error, reason}
    end
  end

  defp require_secret(secret) when is_binary(secret) and secret != "", do: {:ok, secret}
  defp require_secret(_secret), do: {:error, :missing_secret}

  defp parse_signature_header(signature_header) when is_binary(signature_header) do
    parts =
      signature_header
      |> String.split(",", trim: true)
      |> Enum.map(&String.split(&1, "=", parts: 2))
      |> Enum.reduce(%{}, fn
        [key, value], acc -> Map.put(acc, String.trim(key), String.trim(value))
        _part, acc -> acc
      end)

    with {:ok, timestamp} <- parse_timestamp(parts["t"]),
         signature when is_binary(signature) and signature != "" <- parts["v1"],
         true <- hex?(signature) do
      {:ok, timestamp, String.downcase(signature)}
    else
      _invalid -> {:error, :invalid_signature_header}
    end
  end

  defp parse_signature_header(_signature_header), do: {:error, :missing_signature}

  defp parse_timestamp(nil), do: {:error, :invalid_signature_header}

  defp parse_timestamp(value) do
    case Integer.parse(value) do
      {timestamp, ""} when timestamp > 0 -> {:ok, timestamp}
      _invalid -> {:error, :invalid_signature_header}
    end
  end

  defp verify_timestamp(timestamp, opts) do
    now = Keyword.get(opts, :now, System.system_time(:second))
    tolerance_seconds = Keyword.get(opts, :tolerance_seconds, @default_tolerance_seconds)

    if abs(now - timestamp) <= tolerance_seconds do
      :ok
    else
      {:error, :timestamp_outside_tolerance}
    end
  end

  defp verify_signature(raw_body, timestamp, signature, secret) do
    expected =
      :crypto.mac(:hmac, :sha256, secret, "#{timestamp}.#{raw_body}")
      |> Base.encode16(case: :lower)

    if secure_compare(expected, signature) do
      :ok
    else
      {:error, :invalid_signature}
    end
  end

  defp hex?(value), do: String.match?(value, ~r/\A[0-9a-fA-F]+\z/)

  defp secure_compare(left, right) when byte_size(left) == byte_size(right) do
    secure_compare(left, right, 0) == 0
  end

  defp secure_compare(_left, _right), do: false

  defp secure_compare(<<left, rest_left::binary>>, <<right, rest_right::binary>>, acc) do
    secure_compare(rest_left, rest_right, bor(acc, bxor(left, right)))
  end

  defp secure_compare(<<>>, <<>>, acc), do: acc
end
