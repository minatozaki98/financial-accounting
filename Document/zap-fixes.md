# ZAP Security Issue Fixes

| # | Alert Name | Risk Level | CWE | Affected URL/Endpoint | Fix Applied |
|---|------------|------------|-----|-----------------------|-------------|
| 1 | Content Security Policy (CSP) Header Not Set | Medium | CWE-693 | `/`, `/swagger`, `/swagger/index.html` | Moved `SecurityHeadersMiddleware` ahead of Swagger/OpenAPI middleware so security headers are applied before Swagger can short-circuit the request pipeline. |
| 2 | X-Content-Type-Options Header Missing | Low | CWE-693 | `/swagger/v1/swagger.json` | Applied the existing security-header middleware to OpenAPI document responses and verified the `nosniff` header with an integration test. |
| 3 | Cross-origin and permissions headers missing (`COEP`, `COOP`, `CORP`, `Permissions-Policy`) | Low | CWE-693 | Swagger/OpenAPI responses | Reused the configured security-header policy for Swagger/OpenAPI responses and added regression coverage for the headers on `/swagger/v1/swagger.json`. |
| 4 | Vulnerable JS Library (DOMPurify in Swagger UI bundle) | Medium | CWE-1395 | `/swagger/swagger-ui-bundle.js` | Upgraded `Swashbuckle.AspNetCore` from `6.7.3` to `10.1.5` and `Swashbuckle.AspNetCore.Filters` from `9.0.0` to `10.0.1`. |
| 5 | Unexpected Content-Type was returned | Low | N/A | `/`, `/swagger`, `/swagger/index.html` | Disabled Swagger UI by default, kept the OpenAPI document at `/swagger/v1/swagger.json`, and redirected `/` to the OpenAPI document when Swagger is enabled without the UI. |

## Results After Fix

### Baseline Scan

| Severity | Before (`zap-baseline-20260323-001410.md`) | After (`zap-baseline-20260324-000724.md`) | Change |
|----------|--------------------------------------------|-------------------------------------------|--------|
| High | 0 | 0 | 0 |
| Medium | 2 | 0 | -2 |
| Low | 6 | 0 | -6 |
| Informational | 3 | 4 | +1 |

Remaining alerts after fix:
- `Authentication Request Identified` (informational, 2 instances)
- `Information Disclosure - Sensitive Information in URL` (informational, 1 instance on `GET /audit-logs?...userId=...`)
- `Non-Storable Content` (informational, systemic)
- `Storable and Cacheable Content` (informational, 2 instances)

### API Scan

| Severity | Before (`zap-api-20260323-001410.md`) | After (`zap-api-20260324-000856.md`) | Change |
|----------|---------------------------------------|--------------------------------------|--------|
| High | 0 | 0 | 0 |
| Medium | 0 | 0 | 0 |
| Low | 3 | 0 | -3 |
| Informational | 5 | 5 | 0 |

Remaining alerts after fix:
- `A Client Error response code was returned by the server` (informational, expected 400/401/403/404 responses during active scanning)
- `Authentication Request Identified` (informational, 2 instances)
- `Information Disclosure - Sensitive Information in URL` (informational, 1 instance on `GET /audit-logs?...userId=...`)
- `Non-Storable Content` (informational, systemic)
- `User Agent Fuzzer` (informational, systemic)

### Verification

- `dotnet test API/API.sln` -> Passed (`105/105` total tests: `2` unit, `103` integration)
- `./scripts/phase4/run-zap-baseline.ps1 -TargetUrl http://localhost:5296 -OutputPrefix zap-baseline-20260324-000724 -IgnoreWarnings`
- `./scripts/phase4/run-zap-api.ps1 -OpenApiUrl http://localhost:5296/swagger/v1/swagger.json -BaseUrl http://localhost:5296 -OutputPrefix zap-api-20260324-000856 -IgnoreWarnings`

### Generated Artifacts

- `Document/security/zap-baseline-20260324-000724.html`
- `Document/security/zap-baseline-20260324-000724.json`
- `Document/security/zap-baseline-20260324-000724.md`
- `Document/security/zap-api-20260324-000856.html`
- `Document/security/zap-api-20260324-000856.json`
- `Document/security/zap-api-20260324-000856.md`
