defmodule MakePay.Transport do
  @moduledoc "Transport behaviour used by `MakePay.Client`."

  @callback request(
              method :: atom(),
              url :: String.t(),
              headers :: [{String.t(), String.t()}],
              body :: binary(),
              opts :: keyword()
            ) ::
              {:ok, %{status: pos_integer(), headers: [{String.t(), String.t()}], body: binary()}}
              | {:error, term()}
end
