# Sonar Challenge Complex API Reference Design

## Purpose

Create a clean, behaviorally specified reference implementation for three complex financial-accounting workflows. This reference will later be copied and deliberately degraded into a separate SonarQube challenge source. GPT-5.4 and GPT-5.5 will remediate that later challenge source; they must not see this reference branch.

This phase does not create SonarQube findings, benchmark weights, model branches, or comparison results.

## Starting Point

- Source branch: `baseline-v0.2`
- Source commit: `11f8cfd`
- Reference branch: `codex/sonar-challenge-api-reference`
- Existing API baseline: 6 unit tests and 107 integration tests passing
- Database providers: SQL Server in the application and SQLite in integration tests

## Workflow 1: Accounting Period Close

### Endpoints

- `GET /periods/{periodId}/close-preview`
- `POST /periods/{periodId}/close`

### Behavior

The preview returns the period version, draft-entry count, unbalanced-posted-entry count, posted-entry count, and explicit blockers. Closing requires an idempotency request ID and the previewed version.

Closing is allowed only when:

- The period exists and is open.
- No draft journal entries fall within the period.
- Every posted journal entry is balanced and has a positive total.
- The submitted version matches the current period version.

The close operation refreshes ledger balances, marks the period closed, writes an audit record, and commits those changes atomically. Repeating the same request ID returns the original successful result. A different close request against an already closed period returns a conflict.

## Workflow 2: Journal Import

### Endpoints

- `POST /journal-imports/validate`
- `POST /journal-imports/{importId}/commit`

### Input

The validation endpoint accepts `multipart/form-data` containing:

- `file`: UTF-8 CSV with the exact header `EntryDate,ReferenceNo,Description,AccountCode,Debit,Credit`
- `idempotencyKey`: caller-supplied key, 8 to 100 characters
- `atomic`: whether any invalid group must block the full commit

Rows are grouped into journal entries by `ReferenceNo`. Every group must:

- Have one consistent entry date.
- Contain at least two lines.
- Reference active accounts.
- Belong to an open accounting period.
- Use exactly one positive debit or credit per line.
- Balance to two decimal places with a positive total.

Validation is idempotent for the same user and key. It stores a staged batch and row-level validation results. Commit creates draft journal entries in one transaction. An atomic batch with any invalid row cannot be committed. Repeating a successful commit returns the same journal-entry IDs.

## Workflow 3: Bank Reconciliation

### Endpoints

- `POST /reconciliations`
- `POST /reconciliations/{reconciliationId}/auto-match`
- `POST /reconciliations/{reconciliationId}/confirm`
- `GET /reconciliations/{reconciliationId}/exceptions`
- `POST /reconciliations/{reconciliationId}/finalize`

### Behavior

A reconciliation belongs to one open accounting period and one active asset account. It contains signed bank transactions, where a positive amount is money received and a negative amount is money paid.

Auto-match examines posted journal-entry lines for the same account and date range:

- Amount must match exactly to two decimals.
- Candidate date must be within three calendar days.
- An exact normalized reference match is preferred.
- A journal entry cannot be assigned to more than one bank transaction in the reconciliation.
- One best candidate becomes an automatic match.
- Multiple equally ranked candidates remain ambiguous.
- No candidates remains unmatched.

Manual confirmation selects a candidate for an ambiguous or unmatched transaction while enforcing uniqueness. The exceptions endpoint returns unmatched and ambiguous transactions. Finalization requires every transaction to be matched, uses optimistic version checking, writes an audit record, and commits atomically. Repeated finalization with the same request ID is idempotent.

## Architecture

Each workflow owns a controller, service interface, service implementation, DTO file, and focused entities:

- Period close extends `AccountingPeriodService` and uses a shared `ILedgerBalanceService`.
- Journal import uses `JournalImportService`, `JournalImportBatch`, and `JournalImportRow`.
- Reconciliation uses `BankReconciliationService`, `BankReconciliation`, `BankTransaction`, and `BankReconciliationCandidate`.
- `DataContext` defines all relationships, uniqueness constraints, precision, and optimistic concurrency tokens.
- `GlobalExceptionMiddleware` maps resource conflicts to HTTP 409.

The service layer owns all business invariants and transactions. Controllers only perform authorization, bind requests, resolve the actor, and translate successful results.

## Authorization

- Period preview and close: `Admin`, `FinanceManager`
- Journal import validate and commit: `Admin`, `FinanceManager`
- Reconciliation create, auto-match, confirm, finalize: `Admin`, `FinanceManager`
- Reconciliation exceptions: `Admin`, `FinanceManager`, `Auditor`

Anonymous requests return 401. Authenticated users outside the permitted roles return 403.

## Verification

- Tests are written before production behavior.
- Integration tests use the existing SQLite `WebApplicationFactory`.
- Model tests verify required indexes, uniqueness, precision, relationships, and concurrency tokens.
- Focused tests cover success, validation failure, idempotency, RBAC, state transitions, and rollback-visible behavior.
- The full solution test suite must pass before this reference is considered ready.
- The SQL Server bootstrap schema is updated alongside EF Core mappings.

## Benchmark Boundary

This branch is the hidden, known-good reference. The later challenge construction must:

- Start from this exact reference commit.
- Change only a separate challenge branch.
- Preserve public API contracts and intended behavior.
- Keep the reference branch, mutation manifest, and hidden tests unavailable to model remediation tasks.
