defmodule MakePay.Error do
  @moduledoc "Structured error returned by MakePay client and webhook helpers."

  defexception [:message, :status, :body, :reason]

  @type t :: %__MODULE__{
          message: String.t(),
          status: nil | pos_integer(),
          body: term(),
          reason: term()
        }

  @spec missing_config(atom()) :: t()
  def missing_config(key) do
    %__MODULE__{message: "Missing MakePay configuration value: #{key}.", reason: :missing_config}
  end

  @spec encoding(term()) :: t()
  def encoding(reason) do
    %__MODULE__{message: "Unable to encode MakePay request JSON.", reason: reason}
  end

  @spec decoding(term()) :: t()
  def decoding(reason) do
    %__MODULE__{message: "Unable to decode MakePay response JSON.", reason: reason}
  end

  @spec transport(term()) :: t()
  def transport(reason) do
    %__MODULE__{message: "MakePay transport request failed.", reason: reason}
  end

  @spec http(pos_integer(), term()) :: t()
  def http(status, body) do
    %__MODULE__{
      message: "MakePay API returned HTTP #{status}.",
      status: status,
      body: body,
      reason: :http_error
    }
  end
end
