# JMeter Performance Issue Fixes

## Fixes Applied

| # | Endpoint / Area | Issue | Metric Before | Fix Applied | Observed Impact |
|---|---|---|---|---|---|
| 1 | Report generation side effects | Every report request wrote `Reports` and `ReportItems`, adding avoidable write pressure during load. | `GET /reports/account-ledger` p100 p95 `703.75ms`; soak total p95 `970.95ms` | Stopped persisting report snapshots and kept audit logging only. | Removed write amplification and dropped total p95 materially across all mixed profiles. |
| 2 | Trial balance / profit-loss / balance-sheet | Summary reports recomputed period balances from raw journal lines on every request even though `LedgerBalances` exists. | `GET /reports/trial-balance` spike p95 `10585ms`; `GET /reports/profit-loss` spike p95 `7118.35ms`; `GET /reports/balance-sheet` spike p95 `5768.95ms` | Added lazy materialization and reuse of `LedgerBalances` for summary report reads. | Summary report spike p95 fell to `1307.95ms`, `683.95ms`, and `732.95ms` respectively. |
| 3 | Account-ledger query path | The remaining hot query filtered and joined on columns backed only by single-column indexes. | `GET /reports/account-ledger` spike p95 `8073.4ms`; soak p95 `1783.95ms` | Added composite indexes in the EF model and a SQL Server startup step that creates them if missing. | Account-ledger p95 improved to `3819.8ms` in spike and `322ms` in soak. |
| 4 | Account-ledger response serialization | The ledger dataset stays static during the JMeter run, but the API was still rebuilding and serializing the same large JSON body on every request. | `GET /reports/account-ledger` spike p95 `6073.30ms`; soak p95 `363.95ms` on the first cache-based retest | Cached the serialized `account-ledger` JSON payload and returned it directly from the controller while keeping cache invalidation for posted/reversed entries. | `GET /reports/account-ledger` fell further to `3435.95ms` p95 in spike and `279ms` in soak. |
| 5 | Transport optimization | Large JSON report responses benefit from gzip, but only when the client advertises compression support. | Integration test proved the API returned uncompressed ledger responses even when the client requested gzip. | Enabled ASP.NET Core response compression for JSON payloads and added regression coverage. | Functional improvement confirmed by tests; the JMeter benchmark client does not send `Accept-Encoding`, so this change does not affect the benchmark numbers below. |

## Results After Fix

Comparison source:
- Before: `Document/performance/report-20260324-002610-*`
- After: `Document/performance/report-20260324-113540-*`

| Scenario | Error % Before | Error % After | p95 Before (ms) | p95 After (ms) | p99 Before (ms) | p99 After (ms) | Throughput Before (tx/s) | Throughput After (tx/s) | Gate Status |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| p50 | 0.0000 | 0.0000 | 49.45 | 13.00 | 122.49 | 66.00 | 54.47 | 54.74 | PASS |
| p100 | 0.0000 | 0.0000 | 261.95 | 34.00 | 1859.94 | 74.99 | 57.53 | 59.82 | PASS |
| p500 | 0.0000 | 0.0000 | 176.00 | 28.00 | 765.99 | 46.00 | 62.93 | 63.74 | PASS |
| soak | 0.0000 | 0.0000 | 970.95 | 56.00 | 4853.89 | 129.00 | 125.99 | 240.36 | FAIL on drift |
| spike | 0.0022 | 0.0000 | 6795.00 | 1420.00 | 9212.88 | 2552.98 | 108.28 | 363.42 | FAIL on recovery drift |

### Drift Checks

| Scenario | First-Window p95 Before | Last-Window p95 Before | Drift Before | First-Window p95 After | Last-Window p95 After | Drift After | Threshold | Status |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| soak | 423.00 | 1004.00 | 137.35% | 42.00 | 55.00 | 30.95% | <= 20% | FAIL |
| spike | 3802.00 | 7293.00 | 91.82% | 714.00 | 1178.00 | 64.99% | <= 20% | FAIL |

## Key Endpoint Comparison

| Endpoint | Profile | Avg Before (ms) | Avg After (ms) | p95 Before (ms) | p95 After (ms) | p99 Before (ms) | p99 After (ms) | Error % After |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| GET /reports/trial-balance | spike | 6612.00 | 356.32 | 10585.00 | 1244.85 | 12928.90 | 2044.58 | 0.0000 |
| GET /reports/profit-loss | spike | 4166.56 | 233.42 | 7118.35 | 690.90 | 8873.84 | 1216.92 | 0.0000 |
| GET /reports/balance-sheet | spike | 3378.43 | 219.34 | 5768.95 | 650.95 | 7815.78 | 1103.92 | 0.0000 |
| GET /reports/account-ledger | spike | 2398.08 | 1362.01 | 8073.40 | 3435.95 | 12883.63 | 4724.41 | 0.0000 |
| GET /reports/account-ledger | soak | 846.57 | 101.32 | 1783.95 | 279.00 | 8267.87 | 482.98 | 0.0000 |
| POST /journal-entries/bulk | spike | 574.10 | 225.07 | 1401.70 | 634.00 | 2478.94 | 1000.90 | 0.0000 |

## Final Assessment

- The branch now clears the p50, p100, and p500 JMeter gates with zero errors, and it materially improves soak/spike absolute latency with zero errors.
- The remaining red benchmark is the drift gate only. In the latest soak run, the heavy report endpoints all improve over time, including `GET /reports/account-ledger` (`367ms` first-window p95 to `133ms` last-window p95), while the overall drift stays red because the last 20% of the mixed run is dominated by the complex/report thread group instead of the lighter core requests.
- Spike shows the same pattern for the report endpoints: `GET /reports/account-ledger` drops from `3951ms` first-window p95 to `1070ms` last-window p95, while the overall mixed-window recovery metric remains red because the last window is compositionally different and still contains slower core list endpoints under burst contention.
- The branch no longer has a clear report-generation bottleneck. The unresolved item is whether to accept the documented mixed-workload drift caveat as the Phase 3 stopping point or continue optimizing unrelated core list endpoints specifically to satisfy the current heuristic.

## Artifacts

- `Document/performance/jmeter-20260324-113540-p50.jtl`
- `Document/performance/jmeter-20260324-113540-p100.jtl`
- `Document/performance/jmeter-20260324-113540-p500.jtl`
- `Document/performance/jmeter-20260324-113540-soak.jtl`
- `Document/performance/jmeter-20260324-113540-spike.jtl`
- `Document/performance/report-20260324-113540-p50/`
- `Document/performance/report-20260324-113540-p100/`
- `Document/performance/report-20260324-113540-p500/`
- `Document/performance/report-20260324-113540-soak/`
- `Document/performance/report-20260324-113540-spike/`
