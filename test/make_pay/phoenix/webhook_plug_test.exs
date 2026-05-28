defmodule MakePay.Phoenix.WebhookPlugTest do
  use ExUnit.Case, async: true

  import Plug.Test

  alias MakePay.Phoenix.WebhookPlug

  test "verifies signature and dispatches handler" do
    raw_body = ~s({"id":"evt_test","type":"payment_link.paid"})
    timestamp = 1_700_000_000
    signature = signature(raw_body, timestamp)

    conn =
      conn(:post, "/webhooks/makepay", raw_body)
      |> Plug.Conn.put_req_header("x-makepay-signature", "t=#{timestamp},v1=#{signature}")
      |> WebhookPlug.call(Keyword.put(opts(), :tolerance_seconds, 9_999_999_999))

    assert conn.assigns.makepay_event_id == "evt_test"
    assert_receive {:webhook_event, %{"id" => "evt_test", "type" => "payment_link.paid"}}
  end

  test "rejects invalid signatures" do
    raw_body = ~s({"id":"evt_test"})

    conn =
      conn(:post, "/webhooks/makepay", raw_body)
      |> Plug.Conn.put_req_header("x-makepay-signature", "t=1700000000,v1=bad")
      |> WebhookPlug.call(Keyword.put(opts(), :tolerance_seconds, 9_999_999_999))

    assert conn.status == 401
    assert conn.resp_body =~ "invalid_signature"
  end

  defp opts do
    WebhookPlug.init(
      secret: "whsec_test",
      handler: fn event, conn ->
        send(self(), {:webhook_event, event})
        Plug.Conn.assign(conn, :makepay_event_id, event["id"])
      end
    )
  end

  defp signature(raw_body, timestamp) do
    :crypto.mac(:hmac, :sha256, "whsec_test", "#{timestamp}.#{raw_body}")
    |> Base.encode16(case: :lower)
  end
end
