# Sonar Challenge Complex API Reference Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the clean reference implementation of transactional period close, staged journal import, and bank reconciliation APIs for the later SonarQube challenge.

**Architecture:** Add focused service and entity boundaries for each workflow, share ledger-balance refresh logic, and keep controllers thin. Use EF Core transactions and integer optimistic-concurrency tokens so SQL Server production behavior and SQLite integration tests share the same contract.

**Tech Stack:** ASP.NET Core 8, EF Core 8, SQL Server, SQLite integration tests, xUnit, FluentAssertions.

## Global Constraints

- Work only on `codex/sonar-challenge-api-reference`.
- Do not create Sonar mutations, model-remediation branches, benchmark scores, or comparison reports.
- Preserve existing endpoint contracts and all current tests.
- Use test-first red-green cycles for every new behavior.
- Do not add a CSV parsing dependency; parse the fixed six-column format with focused internal code.
- Update `Document/sql/financial_accounting_schema.sql` for every new table or column.
- Do not commit or push unless the user explicitly requests it.

---

### Task 1: Model and conflict foundation

**Files:**
- Modify: `MODEL/DataContext.cs`
- Modify: `MODEL/Entities/AccountingPeriod.cs`
- Modify: `MODEL/Entities/JournalEntry.cs`
- Create: `MODEL/Entities/JournalImportBatch.cs`
- Create: `MODEL/Entities/JournalImportRow.cs`
- Create: `MODEL/Entities/BankReconciliation.cs`
- Create: `MODEL/Entities/BankTransaction.cs`
- Create: `MODEL/Entities/BankReconciliationCandidate.cs`
- Create: `BAL/Shared/ResourceConflictException.cs`
- Modify: `API/Middleware/GlobalExceptionMiddleware.cs`
- Modify: `tests/FinancialAccounting.UnitTests/DataContextModelTests.cs`

**Interfaces:**
- Produces: integer `Version` concurrency tokens on period and reconciliation records.
- Produces: unique import `(CreatedByUserId, IdempotencyKey)` and reconciliation finalize request constraints.
- Produces: HTTP 409 mapping for `ResourceConflictException`.

- [x] Add failing model-metadata tests for the new keys, indexes, precision, relationships, and concurrency tokens.
- [x] Run `dotnet test tests/FinancialAccounting.UnitTests/FinancialAccounting.UnitTests.csproj --filter DataContextModelTests`.
- [x] Add the minimal entities, mappings, and conflict exception handling.
- [x] Rerun the focused unit tests and confirm they pass.

### Task 2: Shared ledger balance refresh

**Files:**
- Create: `BAL/IServices/ILedgerBalanceService.cs`
- Create: `BAL/Services/LedgerBalanceService.cs`
- Modify: `BAL/Services/JournalEntryService.cs`
- Modify: `BAL/Shared/ServiceManager.cs`
- Modify: `tests/FinancialAccounting.IntegrationTests/ReportsTests.cs`

**Interfaces:**
- Produces: `Task RefreshForPeriodAsync(int periodId, CancellationToken cancellationToken = default)`.
- Consumes: `DataContext`.

- [x] Add a focused test proving a period refresh updates and removes stale balances.
- [x] Run the focused refresh regression test after extraction and confirm it passes.
- [x] Extract the existing refresh algorithm into `LedgerBalanceService` and inject it into `JournalEntryService`.
- [x] Rerun report and journal-entry integration tests.

### Task 3: Period close workflow

**Files:**
- Create: `MODEL/DTOs/PeriodCloseDTOs.cs`
- Modify: `BAL/IServices/IAccountingPeriodService.cs`
- Modify: `BAL/Services/AccountingPeriodService.cs`
- Modify: `API/Controllers/PeriodsController.cs`
- Modify: `tests/FinancialAccounting.IntegrationTests/PeriodsTests.cs`
- Modify: `tests/FinancialAccounting.IntegrationTests/Support/ExpectedStatusMatrix.cs`
- Modify: `tests/FinancialAccounting.IntegrationTests/RbacMatrixTests.cs`

**Interfaces:**
- Produces: `Task<PeriodClosePreviewDto> PreviewCloseAsync(int periodId, CancellationToken cancellationToken = default)`.
- Produces: `Task<PeriodCloseResultDto> CloseAsync(int periodId, CloseAccountingPeriodRequestDto request, Guid actorUserId, string? ipAddress, CancellationToken cancellationToken = default)`.

- [x] Add failing integration tests for preview blockers, successful atomic close, idempotent replay, version conflict, and RBAC.
- [x] Run only `PeriodsTests` and verify the new endpoint tests fail because routes do not exist.
- [x] Implement DTOs, service behavior, transactions, audit, and controller routes.
- [x] Rerun `PeriodsTests` and the RBAC matrix.

### Task 4: Journal import workflow

**Files:**
- Create: `MODEL/DTOs/JournalImportDTOs.cs`
- Create: `BAL/IServices/IJournalImportService.cs`
- Create: `BAL/Services/JournalImportService.cs`
- Create: `API/Controllers/JournalImportsController.cs`
- Modify: `BAL/Shared/ServiceManager.cs`
- Create: `tests/FinancialAccounting.IntegrationTests/JournalImportsTests.cs`
- Modify: `tests/FinancialAccounting.IntegrationTests/Support/ExpectedStatusMatrix.cs`
- Modify: `tests/FinancialAccounting.IntegrationTests/RbacMatrixTests.cs`

**Interfaces:**
- Produces: `Task<JournalImportValidationResponseDto> ValidateCsvAsync(Stream csv, string fileName, string idempotencyKey, bool atomic, Guid actorUserId, string? ipAddress, CancellationToken cancellationToken = default)`.
- Produces: `Task<JournalImportCommitResponseDto> CommitAsync(Guid importId, Guid actorUserId, string? ipAddress, CancellationToken cancellationToken = default)`.

- [x] Add failing tests for valid CSV staging, row errors, idempotent validation, atomic rejection, successful commit, commit replay, and RBAC.
- [x] Run `JournalImportsTests` and verify the missing routes fail.
- [x] Implement streaming CSV parsing, grouped validation, staged persistence, transactional commit, and audit.
- [x] Rerun `JournalImportsTests` and the RBAC matrix.

### Task 5: Bank reconciliation workflow

**Files:**
- Create: `MODEL/DTOs/BankReconciliationDTOs.cs`
- Create: `BAL/IServices/IBankReconciliationService.cs`
- Create: `BAL/Services/BankReconciliationService.cs`
- Create: `API/Controllers/ReconciliationsController.cs`
- Modify: `BAL/Shared/ServiceManager.cs`
- Create: `tests/FinancialAccounting.IntegrationTests/ReconciliationsTests.cs`
- Modify: `tests/FinancialAccounting.IntegrationTests/Support/ExpectedStatusMatrix.cs`
- Modify: `tests/FinancialAccounting.IntegrationTests/RbacMatrixTests.cs`

**Interfaces:**
- Produces: create, auto-match, confirm, exceptions, and finalize service methods using DTOs defined in `BankReconciliationDTOs.cs`.
- Consumes: posted journal entries and journal lines for the reconciliation account and period.

- [x] Add failing tests for creation, exact auto-match, ambiguity, manual confirmation, duplicate assignment rejection, exception listing, finalization, replay, version conflict, and RBAC.
- [x] Run `ReconciliationsTests` and verify the missing routes fail.
- [x] Implement reconciliation persistence, deterministic candidate ranking, state transitions, transactions, concurrency, audit, and controllers.
- [x] Rerun `ReconciliationsTests` and the RBAC matrix.

### Task 6: SQL schema and full verification

**Files:**
- Modify: `Document/sql/financial_accounting_schema.sql`
- Create: `Document/experiments/sonar-challenge-v2/reference-manifest.md`

**Interfaces:**
- Produces: an idempotent SQL Server schema matching `DataContext`.
- Produces: a reference manifest recording branch, source SHA, contracts, verification commands, and benchmark boundary.

- [x] Add SQL Server tables, columns, foreign keys, unique constraints, and indexes.
- [x] Run `dotnet test API/API.sln -c Debug --nologo`.
- [x] Run `dotnet build API/API.sln -c Release --nologo`.
- [x] Run `git diff --check` and inspect `git diff --stat`.
- [x] Scan the design, plan, and manifest for incomplete placeholders and contradictions.
