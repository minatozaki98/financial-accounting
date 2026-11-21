# GPT-5.6 Luna Security Evidence

Date: 2026-11-21 (Asia/Bangkok)

## Accepted passive findings used

Shared controller evidence:

- `zap-final/shared-baseline/baseline/report.json`: CSP, X-Frame-Options, COEP, COOP, CORP, Permissions-Policy, and X-Content-Type-Options findings on Swagger/static responses.
- `zap-final/shared-baseline/api/report.json`: only CORP and X-Content-Type-Options remained, both on `GET /swagger/v1/swagger.json`; no API authorization finding was accepted.

## Source correction

Moved `SecurityHeadersMiddleware` before `UseSwagger()` and `UseSwaggerUI()` in `API/Program.cs`. This covers Swagger static and JSON short-circuit responses while preserving the existing Swagger and authorization configuration. No ZAP scan or deployment was run in this checkout.

## Verification

- Unit suite: 2 total, 2 passed, 0 failed; exit code 0.
- Integration suite: 96 total, 96 passed, 0 failed; exit code 0.
- Evidence: `.tmp/luna-security-tests/unit/luna-security-unit.trx` and `.tmp/luna-security-tests/integration/luna-security-integration.trx`.

Ready for the central controller's passive ZAP measurements.
