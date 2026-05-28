# Contributing

Thanks for improving the MakePay Elixir package.

## Development

1. Install Elixir and Erlang/OTP.
2. Run `mix deps.get`.
3. Run `mix format --check-formatted`.
4. Run `mix test`.
5. Run `npm run validate`.

Keep credential handling server-side. Changes that touch checkout creation,
webhook verification, or Phoenix response handling should include tests and a
short security note in the pull request.
