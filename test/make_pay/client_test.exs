defmodule MakePay.ClientTest do
  use ExUnit.Case, async: true

  alias MakePay.Client

  defmodule FakeTransport do
    @behaviour MakePay.Transport

    @impl MakePay.Transport
    def request(method, url, headers, body, _opts) do
      send(self(), {:makepay_request, method, url, headers, body})

      {:ok,
       %{
         status: 200,
         headers: [{"content-type", "application/json"}],
         body: ~s({"paymentLink":{"uid":"plink_test"}})
       }}
    end
  end

  test "creates payment link requests with MakePay auth headers" do
    client =
      Client.new!(
        base_url: "https://api.example.test/",
        key_id: "mk_test",
        key_secret: "mksec_test",
        transport: FakeTransport
      )

    assert {:ok, %{"paymentLink" => %{"uid" => "plink_test"}}} =
             Client.create_payment_link(client, %{
               title: "Pro plan",
               amount: "49.00",
               currency: "USD",
               customer_email: "customer@example.com",
               order_id: "order_123",
               return_url: "https://example.com/return",
               metadata: %{account_id: "acct_123"}
             })

    assert_receive {:makepay_request, :post,
                    "https://api.example.test/api/partner/v1/makepay/payment-links", headers,
                    body}

    assert {"X-MakeCrypto-Key-Id", "mk_test"} in headers
    assert {"X-MakeCrypto-Key-Secret", "mksec_test"} in headers

    assert {:ok,
            %{
              "status" => "active",
              "sendPaymentRequestEmail" => true,
              "payload" => %{
                "title" => "Pro plan",
                "amount" => "49.00",
                "currency" => "USD",
                "customerEmail" => "customer@example.com",
                "orderId" => "order_123",
                "returnUrl" => "https://example.com/return",
                "metadata" => %{"account_id" => "acct_123"}
              }
            }} = Jason.decode(body)
  end

  test "returns a structured error when credentials are missing" do
    assert {:error, %MakePay.Error{reason: :missing_config}} = Client.new(key_id: "")
  end
end
