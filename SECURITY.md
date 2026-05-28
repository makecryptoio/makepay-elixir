# Security Policy

## Reporting a Vulnerability

Please report suspected vulnerabilities privately through GitHub security
advisories for this repository.

Do not open public issues for credential exposure, webhook verification bypass,
request replay, or payment reconciliation concerns.

## Security Notes

- Keep MakePay key secrets in server-side configuration only.
- Do not put merchant credentials in LiveView assigns, templates, or client-side
  JavaScript.
- Verify `X-MakePay-Signature` before changing order, invoice, subscription, or
  entitlement state.
- Treat webhook handlers as idempotent and store processed event IDs.
