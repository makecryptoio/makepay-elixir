defmodule MakePay.WebhookTest do
  use ExUnit.Case, async: true

  alias MakePay.Webhook

  test "accepts valid t/v1 signatures" do
    raw_body = ~s({"id":"evt_test","type":"payment_link.paid"})
    timestamp = 1_700_000_000
    signature = signature(raw_body, timestamp)
    header = "t=#{timestamp},v1=#{signature}"

    assert :ok == Webhook.verify(raw_body, header, "whsec_test", now: timestamp)
    assert Webhook.valid?(raw_body, header, "whsec_test", now: timestamp)
    assert {:ok, %{"id" => "evt_test"}} = Webhook.parse_event(raw_body, header, "whsec_test", now: timestamp)
  end

  test "rejects changed payloads" do
    raw_body = ~s({"id":"evt_test"})
    timestamp = 1_700_000_000
    header = "t=#{timestamp},v1=#{signature(raw_body, timestamp)}"

    assert {:error, :invalid_signature} =
             Webhook.verify(~s({"id":"evt_tampered"}), header, "whsec_test", now: timestamp)
  end

  test "rejects stale timestamps" do
    raw_body = ~s({"id":"evt_test"})
    timestamp = 1_700_000_000
    header = "t=#{timestamp},v1=#{signature(raw_body, timestamp)}"

    assert {:error, :timestamp_outside_tolerance} =
             Webhook.verify(raw_body, header, "whsec_test", now: timestamp + 301)
  end

  defp signature(raw_body, timestamp) do
    :crypto.mac(:hmac, :sha256, "whsec_test", "#{timestamp}.#{raw_body}")
    |> Base.encode16(case: :lower)
  end
end
