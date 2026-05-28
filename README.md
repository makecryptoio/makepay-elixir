# MakePay Elixir

Elixir SDK for MakePay server integrations, with Phoenix-friendly webhook
helpers.

## Features

- Server-side MakePay client using merchant key ID and key secret headers.
- Hosted payment link, customer, and bookkeeping invoice helpers.
- Fixed-time `X-MakePay-Signature` webhook verification.
- Optional Phoenix/Plug endpoint helper for webhook routes.
- Hex package metadata, docs configuration, CI, and repository protection notes.

## Installation

Add `make_pay` to your Mix dependencies:

```elixir
def deps do
  [
    {:make_pay, "~> 0.1.0"}
  ]
end
```

For Phoenix webhook routes, keep `plug` available in your application. Phoenix
apps already include it.

## Client Usage

```elixir
client =
  MakePay.Client.new!(
    key_id: System.fetch_env!("MAKEPAY_KEY_ID"),
    key_secret: System.fetch_env!("MAKEPAY_KEY_SECRET")
  )

{:ok, payment_link} =
  MakePay.Client.create_payment_link(client, %{
    title: "Pro plan",
    amount: "49.00",
    currency: "USD",
    customer_email: "customer@example.com",
    return_url: "https://example.com/billing/return",
    metadata: %{account_id: "acct_123"}
  })
```

The default Partner API base URL is `https://www.makecrypto.io`. Override it
with `base_url: "https://..."` or `config :make_pay, base_url: "https://..."`.

## Webhooks

```elixir
raw_body = ~s({"id":"evt_test","type":"payment_link.paid"})
signature = "t=1700000000,v1=..."

case MakePay.Webhook.parse_event(raw_body, signature, System.fetch_env!("MAKEPAY_WEBHOOK_SECRET")) do
  {:ok, event} ->
    # Reconcile invoices, orders, subscriptions, or entitlements here.
    {:ok, event}

  {:error, reason} ->
    {:error, reason}
end
```

Webhook signatures are verified as HMAC-SHA256 over `timestamp.raw_body` and
are rejected outside a five-minute tolerance by default.

## Phoenix

Configure your webhook secret:

```elixir
config :make_pay,
  webhook_secret: System.fetch_env!("MAKEPAY_WEBHOOK_SECRET")
```

Forward a route to the plug:

```elixir
forward "/webhooks/makepay",
  MakePay.Phoenix.WebhookPlug,
  handler: &MyApp.MakePayWebhook.handle/2
```

The handler receives the decoded event and the `Plug.Conn`. Returning `:ok`
responds with `{"ok":true}`. Returning a `%Plug.Conn{}` lets your handler fully
own the response.

## Development

```bash
mix deps.get
mix format --check-formatted
mix test
npm run validate
```
