defmodule MakePay do
  @moduledoc """
  Entry point for MakePay server integrations.

  Most applications call `MakePay.Client` directly after creating a configured
  client with merchant credentials. Webhook helpers live in `MakePay.Webhook`
  and `MakePay.Phoenix.WebhookPlug`.
  """

  alias MakePay.Client
  alias MakePay.Webhook

  @doc "Creates a MakePay API client."
  defdelegate new(opts \\ []), to: Client

  @doc "Creates a MakePay API client and raises when credentials are missing."
  defdelegate new!(opts \\ []), to: Client

  @doc "Verifies a MakePay webhook signature."
  defdelegate verify_webhook(raw_body, signature_header, secret, opts \\ []), to: Webhook, as: :verify

  @doc "Verifies and decodes a MakePay webhook JSON event."
  defdelegate parse_webhook(raw_body, signature_header, secret, opts \\ []), to: Webhook, as: :parse_event
end
