# Sonar Challenge v2 Reference Manifest

## Status

- Phase: clean reference implementation
- Date verified: 2026-07-20
- Source branch: `baseline-v0.2`
- Source commit: `11f8cfd664e09f1c6831dd1e8f7f05a5c40bfc08`
- Working branch: `codex/sonar-challenge-api-reference`
- Reference code commit: `703a33ddcc7e62ee45d263e34084ff4244526c68`
- Reference tag: `benchmark-v2-reference-code`
- Reference manifest commit: recorded by Git history; not embedded recursively
- Worktree: `.worktrees/sonar-challenge-api-reference`

The reference code commit is the boundary from which separate, deliberately
degraded challenge sources must be created. The clean reference branch, this
manifest, and behavior tests must not be included in model remediation prompts.

## Implemented Workflows

### Accounting period close

- `GET /periods/{periodId}/close-preview`
- `POST /periods/{periodId}/close`
- Explicit blockers for draft or unbalanced entries
- Optimistic version checking
- Request-level idempotency
- Atomic ledger refresh, period close, and audit write
- Compatibility path for the existing close endpoint contract

### Staged journal import

- `POST /journal-imports/validate`
- `POST /journal-imports/{importId}/commit`
- Size-limited multipart CSV upload with a fixed six-column schema
- Streaming parsing and row/group validation
- Per-user validation idempotency
- Staged row-level errors
- Atomic commit option and replay-safe commit results

### Bank reconciliation

- `POST /reconciliations`
- `POST /reconciliations/{reconciliationId}/auto-match`
- `POST /reconciliations/{reconciliationId}/confirm`
- `GET /reconciliations/{reconciliationId}/exceptions`
- `POST /reconciliations/{reconciliationId}/finalize`
- Deterministic amount/date/reference candidate ranking
- Explicit unmatched and ambiguous states
- Unique journal assignment enforcement
- Manual confirmation, optimistic finalization, idempotency, and audit

## Persistence and Cross-Cutting Changes

- EF Core mappings and SQL Server bootstrap schema cover import batches and rows,
  reconciliation aggregates, candidate relationships, filtered request indexes,
  decimal precision, and integer concurrency tokens.
- Ledger refresh is shared through `ILedgerBalanceService`.
- Resource state conflicts map to HTTP 409.
- New routes are included in the role-based access-control matrix.
- Multipart upload fields use a single API form model so OpenAPI generation remains valid.

## Verification Evidence

Baseline before implementation:

- Unit tests: 6 passed
- Integration tests: 107 passed

Fresh verification after implementation:

| Command | Result |
| --- | --- |
| `dotnet test tests/FinancialAccounting.IntegrationTests/FinancialAccounting.IntegrationTests.csproj --filter "FullyQualifiedName~SecurityHeadersTests.SwaggerDocumentResponses" --nologo` | 6 passed |
| `dotnet test tests/FinancialAccounting.IntegrationTests/FinancialAccounting.IntegrationTests.csproj --filter "FullyQualifiedName~JournalImportsTests" --nologo` | 4 passed |
| `dotnet test tests/FinancialAccounting.IntegrationTests/FinancialAccounting.IntegrationTests.csproj --filter "FullyQualifiedName~ReportsTests" --nologo` | 8 passed, including aggregate refresh and stale-row removal |
| `dotnet test API/API.sln -c Debug --nologo` | 9 unit and 134 integration tests passed |
| `dotnet build API/API.sln -c Release --nologo` | succeeded with 0 warnings and 0 errors |

The implementation used red-green focused tests for model constraints, period
close, journal import, and reconciliation before the complete solution run.

## Benchmark Boundary

This phase does not contain:

- Deliberate SonarQube defects
- A SonarQube scan or score for the new workflows
- GPT-5.4 or GPT-5.5 remediation runs
- Model-specific branches
- JMeter or OWASP ZAP benchmark changes
- Comparative claims about model performance

Those activities belong to the later challenge-construction and testing phase,
after this clean reference is reviewed and committed.
