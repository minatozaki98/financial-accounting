# GPT-5.5 JMeter Worker Log

Worktree: `C:\Users\Asus\Documents\GitHub\school\financial-accounting\.worktrees\gpt-5.5-lab`

Branch: `codex/gpt-5.5-jmeter-v1`

Baseline evidence commit: `ec034038c284e77efa4ed2310b13fc9662259286`

Codex task ID: `019f7a66-f631-7493-b2e3-7437e04c86a8`

Model: GPT-5.5

Worker task started: `2026-07-19T12:43:21Z` (`2026-07-19T19:43:21+07:00`)

Worker task completed: `2026-07-19T13:30:40Z` (`2026-07-19T20:30:40+07:00`)

Attempt count: 2 JMeter matrix attempts by the worker:

1. Initial attempt: invalid infrastructure run because Docker could not reach the API bound to `localhost`.
2. Correction attempt 1: valid full matrix with API bound to `0.0.0.0`.

Controller final run: `2026-07-19T20:34:31+07:00` to `2026-07-19T20:51:38+07:00`, run tag `gpt55-after`.

## Changed Files

- `BAL/Shared/FinancialReadCache.cs`
- `BAL/Shared/ServiceManager.cs`
- `BAL/Services/FinancialReportService.cs`
- `BAL/Services/ChartOfAccountsService.cs`
- `BAL/Services/AccountingPeriodService.cs`
- `BAL/Services/JournalEntryService.cs`
- `tests/FinancialAccounting.IntegrationTests/ReportsTests.cs`
- `tests/FinancialAccounting.IntegrationTests/AccountsTests.cs`
- `Document/experiments/gpt-5.5/interactions/jmeter.md`

## Baseline Analysis

Baseline source: `Document/experiments/gpt-5.5/baseline/performance`.

Overall baseline JTL summary:

| Run | Samples | Throughput/s | Error rate | Avg ms | p95 ms | p99 ms | Max ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| p50 | 2050 | 53.35 | 0.00% | 11 | 24 | 61 | 685 |
| p100 | 4700 | 59.47 | 0.00% | 39 | 113 | 584 | 1758 |
| p500 | 12000 | 62.99 | 0.00% | 25 | 88 | 169 | 569 |
| soak | 104530 | 162.37 | 0.00% | 147 | 560 | 1244 | 5566 |
| spike | 46500 | 149.86 | 0.00% | 1299 | 4378 | 7621 | 16007 |

Endpoint-level baseline bottlenecks:

- `GET /reports/account-ledger` was the worst report endpoint in high-load runs: p100 p99 740 ms, p500 p99 348 ms, soak p99 2912 ms, spike p99 12300 ms.
- `GET /reports/trial-balance` was also high: p100 p99 923 ms, soak p99 1644 ms, spike p99 12148 ms.
- Read-heavy lookup/list endpoints drifted during soak/spike: `GET /accounts` soak p99 1224 ms and spike p99 6213 ms; `GET /journal-entries` soak p99 987 ms and spike p99 5241 ms.
- Soak drift: first high-throughput minutes had p99 966-1566 ms and later low-throughput buckets still had p99 up to 3372 ms.
- Spike recovery: p99 stayed above 4 seconds for most 10-second buckets until the final tail buckets; recovery was slow despite 0% errors.

## Bottleneck Hypotheses

1. Repeated report reads are deterministic for the same period/account during the benchmark but each request recomputes aggregate and ledger queries. If cached read models are used while keeping per-request report/audit persistence, report endpoint p95/p99 should fall without changing response JSON or audit/history writes.
2. Stable lookup endpoints (`/accounts`, `/periods`) are repeatedly requested with identical query parameters. If cached with invalidation on account/period mutations, soak/spike pressure should fall without stale results after writes.
3. `GET /journal-entries` remains uncached because the benchmark creates draft entries; caching it would risk stale list responses. It is expected to improve indirectly from reduced database pressure elsewhere, not from direct caching.

## Implementation

- Added `FinancialReadCache`, a singleton `IMemoryCache` wrapper with versioned keys.
- Cached deterministic report aggregate and account-ledger read models in `FinancialReportService`.
- Kept `PersistReportAsync` unchanged in behavior: each report request still inserts `Reports`, `ReportItems`, and `AuditLogs`.
- Cached `/accounts` and `/periods` read models and clone DTOs before returning.
- Invalidated relevant cache generations on account create/update, period create/close, journal post, and journal reverse.
- Added focused regression tests:
  - repeated trial-balance calls still persist two report rows and two `GENERATE_REPORT` audit logs.
  - account list cache refreshes after creating a new account.

## Verification Commands and Results

### Focused Tests

Command:

```powershell
dotnet test tests\FinancialAccounting.IntegrationTests\FinancialAccounting.IntegrationTests.csproj --filter "FullyQualifiedName~ReportsTests|FullyQualifiedName~AccountsTests"
```

Result: passed, 9/9 tests, elapsed 21.8 seconds.

### Build

Command:

```powershell
dotnet build API\API.sln
```

Result: passed, 0 warnings, 0 errors, elapsed 7.1 seconds. Build output included existing Sonar target missing messages but no build warnings/errors.

### Full Tests

Command:

```powershell
dotnet test API\API.sln
```

Result: passed, 2 unit tests and 98 integration tests, elapsed 18.8 seconds. Test output included existing Sonar target missing messages.

### Initial JMeter Attempt

Database restore command: SQL Server `RESTORE DATABASE [Financial] FROM DISK = N'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\Backup\financial-gpt55-clean.bak' WITH REPLACE, RECOVERY`.

API command: `dotnet run --project API\API.csproj --urls http://localhost:5296` inside a PowerShell background job.

JMeter command:

```powershell
scripts\phase4\run-jmeter-thesis-matrix.ps1 -BaseUrl http://localhost:5296 -Username admin -Password 'Admin@123' -ApiVersion 1.0 -PeriodId 202601 -AccountId 1 -ResultsDir Document\experiments\gpt-5.5\after\jmeter -RunTag gpt55-after-worker
```

Result: invalid, elapsed 14:07. All samples failed with `java.net.SocketException: Network unreachable (connect failed)` because the API was bound to `localhost` and Docker could not reach `host.docker.internal:5296`.

Invalid output paths:

- `Document/experiments/gpt-5.5/after/jmeter/jmeter-gpt55-after-worker-*.jtl`
- `Document/experiments/gpt-5.5/after/jmeter/report-gpt55-after-worker-*`

These invalid raw outputs were generated by the worker during infrastructure troubleshooting and are not used as benchmark comparison evidence.

### Correction Attempt 1 JMeter

Database restore command: same SQL Server restore as above, run immediately before the matrix.

API command: `dotnet run --no-launch-profile --project API\API.csproj --urls http://0.0.0.0:5296` inside the same PowerShell process as the JMeter run.

Docker precheck:

```powershell
docker run --rm curlimages/curl:8.10.1 -sS -o /dev/null -w "%{http_code}" http://host.docker.internal:5296/health/live
```

Result: `200`.

JMeter command:

```powershell
scripts\phase4\run-jmeter-thesis-matrix.ps1 -BaseUrl http://localhost:5296 -Username admin -Password 'Admin@123' -ApiVersion 1.0 -PeriodId 202601 -AccountId 1 -ResultsDir Document\experiments\gpt-5.5\after\jmeter -RunTag gpt55-after-worker-attempt2
```

Result: valid, elapsed 16:50, 0 errors in all profiles.

Valid output paths:

- `Document/experiments/gpt-5.5/after/jmeter/jmeter-gpt55-after-worker-attempt2-p50.jtl`
- `Document/experiments/gpt-5.5/after/jmeter/jmeter-gpt55-after-worker-attempt2-p100.jtl`
- `Document/experiments/gpt-5.5/after/jmeter/jmeter-gpt55-after-worker-attempt2-p500.jtl`
- `Document/experiments/gpt-5.5/after/jmeter/jmeter-gpt55-after-worker-attempt2-soak.jtl`
- `Document/experiments/gpt-5.5/after/jmeter/jmeter-gpt55-after-worker-attempt2-spike.jtl`
- `Document/experiments/gpt-5.5/after/jmeter/report-gpt55-after-worker-attempt2-p50`
- `Document/experiments/gpt-5.5/after/jmeter/report-gpt55-after-worker-attempt2-p100`
- `Document/experiments/gpt-5.5/after/jmeter/report-gpt55-after-worker-attempt2-p500`
- `Document/experiments/gpt-5.5/after/jmeter/report-gpt55-after-worker-attempt2-soak`
- `Document/experiments/gpt-5.5/after/jmeter/report-gpt55-after-worker-attempt2-spike`

Overall after summary:

| Run | Samples | Throughput/s | Error rate | Avg ms | p95 ms | p99 ms | Max ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| p50 | 2050 | 54.81 | 0.00% | 9 | 18 | 44 | 985 |
| p100 | 4700 | 59.74 | 0.00% | 12 | 39 | 72 | 327 |
| p500 | 12000 | 63.73 | 0.00% | 12 | 42 | 76 | 247 |
| soak | 104530 | 223.03 | 0.00% | 45 | 184 | 421 | 2157 |
| spike | 46500 | 271.09 | 0.00% | 726 | 2398 | 4310 | 9948 |

Notable endpoint after results:

- `GET /reports/account-ledger`: p100 p99 211 ms, p500 p99 195 ms, soak p99 965 ms, spike p99 7320 ms.
- `GET /reports/trial-balance`: p100 p99 72 ms, p500 p99 89 ms, soak p99 354 ms, spike p99 3611 ms.
- `GET /accounts`: p100 p99 20 ms, p500 p99 46 ms, soak p99 492 ms, spike p99 3903 ms.
- `GET /periods`: p100 p99 12 ms, p500 p99 22 ms, soak p99 239 ms, spike p99 1768 ms.

Soak buckets improved from baseline p99 966-3372 ms to p99 186-625 ms, with the highest p99 at minute bucket 1.

Spike recovery improved but remains the main residual risk: overall spike p99 dropped from 7621 ms to 4310 ms, but `GET /reports/account-ledger` still had spike p99 7320 ms.

### Controller Final JMeter Matrix

Controller database restore command: SQL Server `RESTORE DATABASE [Financial] FROM DISK = N'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\Backup\financial-gpt55-clean.bak' WITH REPLACE, RECOVERY`, run immediately before the matrix.

Controller API command: `dotnet run --no-launch-profile --project API\API.csproj --urls http://0.0.0.0:5296` with API logs written outside the repository.

Controller Docker precheck:

```powershell
docker run --rm curlimages/curl:8.10.1 -sS -o /dev/null -w "%{http_code}" http://host.docker.internal:5296/health/live
```

Result: `200`.

Controller JMeter command:

```powershell
scripts\phase4\run-jmeter-thesis-matrix.ps1 -BaseUrl http://localhost:5296 -Username admin -Password 'Admin@123' -ApiVersion 1.0 -PeriodId 202601 -AccountId 1 -ResultsDir Document\experiments\gpt-5.5\after\jmeter -RunTag gpt55-after
```

Result: valid, 0 errors in all profiles.

Controller final output paths:

- `Document/experiments/gpt-5.5/after/jmeter/jmeter-gpt55-after-p50.jtl`
- `Document/experiments/gpt-5.5/after/jmeter/jmeter-gpt55-after-p100.jtl`
- `Document/experiments/gpt-5.5/after/jmeter/jmeter-gpt55-after-p500.jtl`
- `Document/experiments/gpt-5.5/after/jmeter/jmeter-gpt55-after-soak.jtl`
- `Document/experiments/gpt-5.5/after/jmeter/jmeter-gpt55-after-spike.jtl`
- `Document/experiments/gpt-5.5/after/jmeter/report-gpt55-after-p50`
- `Document/experiments/gpt-5.5/after/jmeter/report-gpt55-after-p100`
- `Document/experiments/gpt-5.5/after/jmeter/report-gpt55-after-p500`
- `Document/experiments/gpt-5.5/after/jmeter/report-gpt55-after-soak`
- `Document/experiments/gpt-5.5/after/jmeter/report-gpt55-after-spike`

Controller final summary:

| Run | Samples | Throughput/s | Error rate | Avg ms | p95 ms | p99 ms | Max ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| p50 | 2050 | 55.02 | 0.00% | 11 | 23 | 48 | 1131 |
| p100 | 4700 | 59.84 | 0.00% | 16 | 52 | 141 | 496 |
| p500 | 12000 | 63.68 | 0.00% | 13 | 40 | 99 | 633 |
| soak | 104530 | 222.18 | 0.00% | 48 | 143 | 287 | 2780 |
| spike | 46500 | 265.04 | 0.00% | 737 | 2482 | 4226 | 11281 |

Controller final improvement against the committed GPT-5.5 baseline:

- p50 p99: 62 ms to 48 ms, 21.8% lower; throughput 53.34/s to 55.02/s.
- p100 p99: 585 ms to 141 ms, 75.9% lower; throughput 59.42/s to 59.84/s.
- p500 p99: 170 ms to 99 ms, 41.8% lower; throughput 62.97/s to 63.68/s.
- soak p99: 892 ms to 287 ms, 67.8% lower; throughput 162.35/s to 222.18/s.
- spike p99: 6431 ms to 4226 ms, 34.3% lower; throughput 149.83/s to 265.04/s.

Notable controller endpoint p99 results:

- `GET /reports/account-ledger`: p100 330 ms, p500 259 ms, soak 1121 ms, spike 8167 ms.
- `GET /reports/trial-balance`: p100 157 ms, p500 107 ms, soak 367 ms, spike 4505 ms.
- `GET /accounts`: p100 92 ms, p500 50 ms, soak 541 ms, spike 4626 ms.
- `GET /periods`: p100 30 ms, p500 21 ms, soak 274 ms, spike 2075 ms.
- `GET /journal-entries`: p100 57 ms, p500 71 ms, soak 417 ms, spike 3916 ms.

## Human Intervention

None.

## Remaining Risk

- The cache is process-local. It is correct for this single-instance benchmark and invalidates on in-process writes, but a multi-instance deployment would need distributed invalidation or a shared cache before relying on it for cross-instance freshness.
- `GET /reports/account-ledger` remains the highest spike-tail endpoint because it still writes report/audit rows per request and returns ledger lines; caching removed repeated reads but not the required per-request persistence.
