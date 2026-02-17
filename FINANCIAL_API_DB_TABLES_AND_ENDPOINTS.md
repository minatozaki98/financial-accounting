# Financial Accounting API — Database Tables & Endpoints (Simple vs Complex)

This document defines the **updated financial accounting concept** (Chart of Accounts + Journal Entries + double-entry) and lists:
- **Database tables** (SQL Server-ready design level)
- **Planned API endpoints** for **Simple** and **Complex** projects (for benchmarking with SonarQube, OWASP ZAP, JMeter)

---

## 1) Simple vs Complex Scope

### Simple (Baseline / Low Complexity)
Focus: **Core bookkeeping workflow**
- Chart of Accounts
- Journal Entries (Draft → Posted)
- Account balance lookup
- Basic authentication + basic roles

Typical dataset target:
- Accounts: 10–20
- Journal entries: 50–200
- Journal lines: 200–800

### Complex (Enterprise-like / High Complexity)
Focus: **Realistic accounting + compliance + reporting + performance stress**
- Multi-role RBAC (Admin / FinanceManager / Auditor / User)
- Accounting periods (open/close)
- Reversal workflow
- Report aggregation endpoints (Trial Balance, P&L, Balance Sheet, Ledger)
- Bulk entry import
- Audit logs
- Refresh tokens
- Optional cached balances

Typical dataset target:
- Accounts: 100–300
- Journal entries: 100,000–1,000,000
- Journal lines: 300,000–3,000,000

---

## 2) Database Tables Needed

> **Notes**
> - Use `uniqueidentifier` (GUID) for IDs if you prefer distributed IDs; otherwise use `int/bigint`.
> - For performance in complex system, add indexes on: dates, status, accountId, periodId, and common report query filters.

### 2.1 Identity & Authorization

#### `Users`
| Column | Type | Key | Notes |
|---|---|---|---|
| UserId | uniqueidentifier | PK | GUID |
| Username | nvarchar(100) | UQ | Unique |
| Email | nvarchar(200) | UQ | Unique |
| PasswordHash | nvarchar(500) |  | Hashed |
| IsActive | bit |  | |
| CreatedAt | datetime2 |  | |
| UpdatedAt | datetime2 |  | |

#### `Roles`
| Column | Type | Key | Notes |
|---|---|---|---|
| RoleId | int | PK | |
| RoleName | nvarchar(50) | UQ | Admin, User, Auditor, FinanceManager |
| Description | nvarchar(200) |  | |

#### `UserRoles`
| Column | Type | Key | Notes |
|---|---|---|---|
| UserRoleId | int | PK | |
| UserId | uniqueidentifier | FK | → Users(UserId) |
| RoleId | int | FK | → Roles(RoleId) |

---

### 2.2 Accounting Core (Double-entry)

#### `ChartOfAccounts`
(Your accounting chart: Assets, Liabilities, Equity, Revenue, Expense)

| Column | Type | Key | Notes |
|---|---|---|---|
| AccountId | int | PK | |
| AccountCode | nvarchar(20) | UQ | e.g., 1000, 4000 |
| AccountName | nvarchar(200) |  | e.g., Cash, Sales Revenue |
| AccountType | nvarchar(20) | IX | Asset/Liability/Equity/Revenue/Expense |
| IsActive | bit |  | |
| CreatedAt | datetime2 |  | |
| UpdatedAt | datetime2 |  | |

#### `JournalEntries`
(One accounting document: “Invoice #123”, “Cash receipt”, etc.)

| Column | Type | Key | Notes |
|---|---|---|---|
| JournalEntryId | bigint | PK | |
| EntryDate | date | IX | |
| Description | nvarchar(500) |  | |
| ReferenceNo | nvarchar(100) | IX | invoice no, receipt no |
| Status | nvarchar(20) | IX | Draft/Posted/Reversed |
| CreatedByUserId | uniqueidentifier | FK | → Users(UserId) |
| CreatedAt | datetime2 |  | |
| PostedAt | datetime2 |  | null if Draft |
| ReversedAt | datetime2 |  | null if not reversed |

#### `JournalEntryLines`
(Double-entry lines; validate SUM(Debit)=SUM(Credit) per JournalEntry)

| Column | Type | Key | Notes |
|---|---|---|---|
| JournalEntryLineId | bigint | PK | |
| JournalEntryId | bigint | FK | → JournalEntries(JournalEntryId) |
| AccountId | int | FK | → ChartOfAccounts(AccountId) |
| LineDescription | nvarchar(500) |  | |
| Debit | decimal(18,2) |  | default 0 |
| Credit | decimal(18,2) |  | default 0 |

**Important rule**  
For each `JournalEntryId`: `SUM(Debit) = SUM(Credit)` (only allow posting when balanced).

---

### 2.3 Periods, Currency, Reporting (Complex-focused)

#### `AccountingPeriods` *(Complex)*
| Column | Type | Key | Notes |
|---|---|---|---|
| PeriodId | int | PK | e.g., 202601 |
| StartDate | date |  | |
| EndDate | date |  | |
| IsClosed | bit | IX | |
| ClosedAt | datetime2 |  | |
| ClosedByUserId | uniqueidentifier | FK | → Users(UserId) |

#### `Currencies` *(Optional; recommended for Complex)*
| Column | Type | Key | Notes |
|---|---|---|---|
| CurrencyCode | nvarchar(10) | PK | USD, EUR, THB |
| Name | nvarchar(50) |  | |
| Symbol | nvarchar(10) |  | |

> If you enable multi-currency: add `CurrencyCode` to `JournalEntries` or `JournalEntryLines` plus optional FX fields.

#### `Reports` *(Complex)*
Metadata for generated reports (optional persistence).

| Column | Type | Key | Notes |
|---|---|---|---|
| ReportId | bigint | PK | |
| ReportType | nvarchar(50) | IX | TrialBalance/ProfitLoss/BalanceSheet/Ledger |
| PeriodId | int | FK | → AccountingPeriods(PeriodId) |
| GeneratedByUserId | uniqueidentifier | FK | → Users(UserId) |
| GeneratedAt | datetime2 |  | |

#### `ReportItems` *(Optional; Complex)*
Precomputed items per report (helps reproduce results & compare performance)

| Column | Type | Key | Notes |
|---|---|---|---|
| ReportItemId | bigint | PK | |
| ReportId | bigint | FK | → Reports(ReportId) |
| AccountId | int | FK | → ChartOfAccounts(AccountId) |
| DebitTotal | decimal(18,2) |  | |
| CreditTotal | decimal(18,2) |  | |
| Balance | decimal(18,2) |  | |

#### `LedgerBalances` *(Optional cache; Complex)*
Materialized balances per account/period to speed report endpoints.

| Column | Type | Key | Notes |
|---|---|---|---|
| LedgerBalanceId | bigint | PK | |
| AccountId | int | FK | → ChartOfAccounts(AccountId) |
| PeriodId | int | FK | → AccountingPeriods(PeriodId) |
| DebitTotal | decimal(18,2) |  | |
| CreditTotal | decimal(18,2) |  | |
| Balance | decimal(18,2) |  | |
| UpdatedAt | datetime2 |  | |

---

### 2.4 Security, Audit, Tokens (Complex-focused; great for thesis)

#### `AuditLogs` *(Complex)*
| Column | Type | Key | Notes |
|---|---|---|---|
| AuditLogId | bigint | PK | |
| UserId | uniqueidentifier | FK | → Users(UserId) |
| Action | nvarchar(100) | IX | e.g., POST_ENTRY, REVERSE_ENTRY |
| EntityName | nvarchar(100) |  | JournalEntry, Account |
| EntityId | nvarchar(50) |  | store ID as string |
| Timestamp | datetime2 | IX | |
| IpAddress | nvarchar(50) |  | |
| DetailsJson | nvarchar(max) |  | optional structured details |

#### `RefreshTokens` *(If using refresh tokens; Complex)*
| Column | Type | Key | Notes |
|---|---|---|---|
| RefreshTokenId | bigint | PK | |
| UserId | uniqueidentifier | FK | → Users(UserId) |
| TokenHash | nvarchar(500) |  | store hash only |
| ExpiresAt | datetime2 | IX | |
| RevokedAt | datetime2 |  | null if active |
| CreatedAt | datetime2 |  | |

---

## 3) Planned API Endpoints

### 3.1 Simple Endpoints (Baseline)

#### Auth
- `POST /auth/login`  
  Body: `{ "username": "...", "password": "..." }` → JWT

#### Chart of Accounts
- `GET /accounts`
- `GET /accounts/{accountId}`
- `GET /accounts/{accountId}/balance`

#### Journal Entries
- `POST /journal-entries` *(create Draft entry + lines)*
- `GET /journal-entries/{id}` *(view entry + lines)*
- `GET /journal-entries?page=1&pageSize=20` *(list)*
- `POST /journal-entries/{id}/post` *(validate balanced; set Posted)*

**Suggested minimal roles**
- Admin: full access
- User: create/view/post (or post restricted to Admin—your choice)

---

### 3.2 Complex Endpoints (Enterprise-like)

#### Auth & session
- `POST /auth/login`
- `POST /auth/refresh`
- `POST /auth/logout`
- `GET /users/me`

#### Chart of Accounts (admin-managed)
- `GET /accounts?type=Asset&isActive=true&search=cash`
- `POST /accounts` *(Admin)*
- `PUT /accounts/{accountId}` *(Admin)*

#### Accounting periods
- `GET /periods`
- `POST /periods` *(Admin)*
- `POST /periods/{periodId}/close` *(Admin/FinanceManager)*

#### Journal entry workflows
- `POST /journal-entries` *(Draft)*
- `POST /journal-entries/bulk` *(FinanceManager; performance)*
- `GET /journal-entries/{id}`
- `GET /journal-entries?from=YYYY-MM-DD&to=YYYY-MM-DD&status=Posted&accountId=...&search=...&page=1&pageSize=50&sort=entryDate_desc`
- `POST /journal-entries/{id}/post` *(FinanceManager)*
- `POST /journal-entries/{id}/reverse` *(FinanceManager; creates reversing entry)*
- `DELETE /journal-entries/{id}` *(Admin; Draft only)*

#### Reporting (heavy endpoints for performance + caching)
- `GET /reports/trial-balance?periodId=202601`
- `GET /reports/profit-loss?periodId=202601`
- `GET /reports/balance-sheet?periodId=202601`
- `GET /reports/account-ledger?accountId=1001&periodId=202601`

#### Audit & compliance (Auditor role)
- `GET /audit-logs?from=YYYY-MM-DD&to=YYYY-MM-DD&userId=...&action=...&page=1&pageSize=50`

**Recommended roles**
- Admin: manage accounts, periods, and system-level operations
- FinanceManager: posting, reversing, bulk import, closing periods, reports
- Auditor: read-only access to reports and audit logs
- User: draft creation + limited reads

---

## 4) Benchmark Targets (Why these endpoints)
Use these endpoints for repeatable benchmark suites:

### Performance (JMeter)
- Simple: `POST /journal-entries`, `POST /journal-entries/{id}/post`, `GET /accounts/{id}/balance`, `GET /journal-entries`
- Complex: `POST /journal-entries/bulk`, `GET /reports/trial-balance`, `GET /reports/profit-loss`, `GET /reports/account-ledger`

### Security (ZAP + Postman)
- Auth endpoints (token handling, role-based access)
- Posting/reversal/period close (privileged actions)
- Report endpoints (protect sensitive financial data)
- Input validation on journal entry creation and bulk import

### Code Quality (SonarQube)
- Service layer complexity (posting validation, reversal logic)
- DTO validation rules
- Error handling (ProblemDetails)
- Authentication/authorization pipeline and configuration

---

## 5) Minimal Implementation Notes
- Enforce: **Debits = Credits** before posting.
- Require proper HTTP status codes (no “200 on error”).
- Use RBAC policies consistently across endpoints.
- Add indexes for complex reporting filters (EntryDate, Status, AccountId, PeriodId).
- Prefer paging on list endpoints; avoid returning large result sets.
