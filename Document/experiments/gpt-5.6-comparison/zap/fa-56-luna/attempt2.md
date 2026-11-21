# GPT-5.6 Luna Security Evidence (Attempt 2)

Date: 2026-11-21 (Asia/Bangkok)

## Accepted passive findings used

Shared controller evidence:

- `zap-final/shared-baseline/baseline/report.json`: CSP, X-Frame-Options, COEP, COOP, CORP, Permissions-Policy, and X-Content-Type-Options findings on Swagger/static responses.
- `zap-final/shared-baseline/api/report.json`: only CORP and X-Content-Type-Options remained, both on `GET /swagger/v1/swagger.json`; no API authorization finding was accepted.

## Source corrections

Moved `SecurityHeadersMiddleware` before `UseSwagger()` and `UseSwaggerUI()` in `API/Program.cs`, covering Swagger static and JSON short-circuit responses. Added `form-action 'self'` to the configured and default CSP. Upgraded `Swashbuckle.AspNetCore` from 6.7.3 to 10.3.1 and `Swashbuckle.AspNetCore.Filters` from 9.0.0 to 10.0.1; migrated the security requirement to the v10 OpenAPI API so Swagger UI and bearer authorization remain functional. No ZAP scan or deployment was run in this checkout.

## Verification

- Restore: exit code 0.
- Build: `API/API.sln` Debug, 0 warnings, 0 errors; exit code 0.
- Unit suite: 2 total, 2 passed, 0 failed; exit code 0.
- Integration suite: 97 total, 97 passed, 0 failed; exit code 0.
- Swagger regression: 1 total, 1 passed, 0 failed; verified Swagger HTML and JSON render actual operations, Bearer security metadata, and required headers.
- Evidence: `.tmp/luna-security-attempt2-final/full-unit/luna-security-attempt2-unit.trx`, `.tmp/luna-security-attempt2-final/full-integration/luna-security-attempt2-integration.trx`, and `.tmp/luna-security-attempt2-final/swagger/luna-security-swagger.trx`.

Ready for the central controller's passive ZAP measurements.
