defmodule MakePay.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/makecryptoio/makepay-elixir"

  def project do
    [
      app: :make_pay,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      deps: deps(),
      docs: docs(),
      name: "MakePay",
      source_url: @source_url,
      homepage_url: "https://www.makepay.io"
    ]
  end

  def application do
    [
      extra_applications: [:crypto, :inets, :logger, :ssl]
    ]
  end

  defp deps do
    [
      {:jason, "~> 1.4"},
      {:plug, "~> 1.15", optional: true},
      {:ex_doc, "~> 0.38", only: :dev, runtime: false}
    ]
  end

  defp description do
    "Elixir SDK and Phoenix webhook helpers for MakePay payment links, customers, and bookkeeping invoices."
  end

  defp package do
    [
      name: "make_pay",
      licenses: ["MIT"],
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE CHANGELOG.md),
      links: %{
        "GitHub" => @source_url,
        "MakePay" => "https://www.makepay.io"
      }
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "SECURITY.md", "docs/ROADMAP.md"],
      source_ref: "v#{@version}"
    ]
  end
end
