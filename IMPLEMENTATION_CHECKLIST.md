# Financial API Implementation Checklist

## Current Gaps
- [ ] `dotnet build API/API.sln` fails at restore; fix build baseline first.
- [ ] JWT secret is hardcoded in `API/Program.cs` and `API/Helpers/TokenGenerator.cs`.
- [ ] Azure storage secrets are hardcoded in `API/Helpers/ImageHandler.cs`.
- [ ] Speech API key is hardcoded in `API/Controllers/TextToSpeechController.cs`.
- [x] Auth pipeline includes `UseAuthentication()` before `UseAuthorization()`.
- [ ] `[Authorize]` is commented out in `TodoController`, `LogController`, and `TextToSpeechController`.
- [x] CORS moved to allowlist configuration (`AllowedOrigins`) with credentials only on explicit origins.
- [ ] Cookie `HttpOnly` is disabled.
- [ ] No financial domain endpoints/entities for transactions/reports yet.

## Implementation Checklist

### Phase 1: Foundation and Security
- [ ] Add `global.json` to pin SDK (use installed `9.0.308`) and make restore/build stable.
- [ ] Move all secrets to `appsettings`/user-secrets/environment variables.
- [x] Add `app.UseAuthentication()` before `app.UseAuthorization()`.
- [ ] Re-enable `[Authorize]` and define role policies (`Admin`, `User`, `Auditor`, `FinanceManager`).
- [x] Tighten CORS to allowlisted origins only; remove wildcard with credentials.
- [x] Set secure cookie defaults (`HttpOnly=true`, proper `SameSite`, secure policy).
- [ ] Replace "200 on error" responses with proper HTTP status codes and `ProblemDetails`.
- [ ] Add request validation (DataAnnotations or FluentValidation) for DTOs.

### Phase 2: Financial Domain Features
- [ ] Create entities: `Account`, `Transaction`, `Report` (+ enums/status/currency).
- [ ] Add EF Core configurations, migrations, and indexes.
- [ ] Add repositories/interfaces and wire into `IUnitOfWork` and `UnitOfWork`.
- [ ] Add BAL services for transaction workflows and report generation.
- [ ] Implement endpoints:
  - [ ] `POST /transactions`
  - [ ] `GET /transactions/{id}`
  - [ ] `GET /transactions` (pagination/filter/sort)
  - [ ] `POST /transactions/bulk`
  - [ ] `GET /reports/summary`
  - [ ] `GET /reports/breakdown`
- [ ] Enforce role-based access per endpoint.

### Phase 3: Performance and Quality
- [ ] Add read-path optimizations (`AsNoTracking`, query shaping).
- [ ] Add caching for report endpoints (memory or Redis).
- [ ] Add structured logging and request correlation ID.
- [ ] Add global exception middleware.
- [ ] Add health check endpoint(s) for app and database.

### Phase 4: Testing and Thesis Metrics
- [x] Add unit tests for BAL/config/token generation behaviors.
- [x] Add integration tests for auth + financial endpoints and RBAC matrix.
- [x] Install SonarQube tooling (Docker) and prepare scan setup.
- [x] Install OWASP ZAP tooling (Docker) and prepare baseline scan script.
- [x] Install Apache JMeter tooling (Docker) and prepare test-run script.
- [x] Setup SonarQube bootstrap + scan scripts for this repository.
- [x] Setup OWASP ZAP baseline rule profile for this repository.
- [x] Setup Apache JMeter ready test plan and 50/100/500 profile runners.
- [ ] Record baseline vs post-improvement metrics (implementation complete; run pending):
  - [ ] Vulnerability count and severity
  - [ ] Response time and throughput
  - [ ] CPU and memory usage
  - [ ] Code smells and cyclomatic complexity
  - [ ] Maintainability index

### Phase 5: Documentation and Delivery
- [x] Replace placeholder `README.md` with real setup/run/test instructions.
- [ ] Add API usage examples (Swagger/Postman collection).
- [ ] Add benchmark and security report summaries for thesis evidence.
- [ ] Add deployment notes and environment configuration guide.
