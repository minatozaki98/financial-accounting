# GPT-5.6 Luna Security Evidence (Attempt 3 Final)

Date: 2026-11-21 (Asia/Bangkok)

## Accepted passive findings used

Shared controller evidence:

- `zap-final/shared-baseline/baseline/report.json`: CSP, X-Frame-Options, COEP, COOP, CORP, Permissions-Policy, and X-Content-Type-Options findings on Swagger/static responses.
- `zap-final/shared-baseline/api/report.json`: only CORP and X-Content-Type-Options remained, both on `GET /swagger/v1/swagger.json`; no API authorization finding was accepted.

## Source corrections and final measured boundary

Moved `SecurityHeadersMiddleware` before `UseSwagger()` and `UseSwaggerUI()` in `API/Program.cs`, covering Swagger static and JSON short-circuit responses. Added `form-action 'self'` to the configured and default CSP. Upgraded `Swashbuckle.AspNetCore` from 6.7.3 to 10.3.1 and `Swashbuckle.AspNetCore.Filters` from 9.0.0 to 10.0.1; migrated the security requirement to the v10 OpenAPI API so Swagger UI and bearer authorization remain functional. The served 10.3.1 bundle was measured locally and still contains `DOMPurify.version="3.4.16"`. The candidate newer Swagger UI 11.0.1 is not compatible with net8.0 (`NU1202`), so the High dependency finding remains an external package compatibility boundary rather than being suppressed. No ZAP scan or deployment was run in this checkout.

## Verification

- Restore: exit code 0.
- Build: `API/API.sln` Debug, 0 warnings, 0 errors; exit code 0.
- Unit suite: 2 total, 2 passed, 0 failed; exit code 0.
- Integration suite: 97 total, 97 passed, 0 failed; exit code 0.
- Swagger regression is included in the 97 integration tests and passed; it verified Swagger HTML/JSON render actual operations, Bearer security metadata, required headers, and bundle delivery.
- Evidence: `.tmp/luna-security-attempt3-final/unit/unit.trx`, `.tmp/luna-security-attempt3-final/integration/integration.trx`, `.tmp/luna-security-attempt3-final-build.log`, and `.tmp/luna-security-attempt3-ui11-restore.log`.

Ready for the central controller's passive ZAP measurements.
