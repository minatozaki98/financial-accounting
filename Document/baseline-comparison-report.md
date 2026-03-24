# Baseline Comparison Report

## baseline-v0.1 (before) vs v1 fix branches (after)

Generated on **March 24, 2026** from the branch reports below:

- `baseline-sonarqube-v1` -> `Document/sonarqube-fixes.md`
- `baseline-zap-v1` -> `Document/zap-fixes.md`
- `baseline-jmeter-v1` -> `Document/jmeter-fixes.md`

## SonarQube Code Quality

| Metric | Before (`baseline-v0.1`) | After (`baseline-sonarqube-v1`) | Change |
|--------|--------------------------:|--------------------------------:|--------|
| Baseline C# findings | 28 | 0 | -28 |
| Bugs | 0 | 0 | 0 |
| Vulnerabilities | 0 | 0 | 0 |
| Code Smells | 21 | 0 | -21 |
| Security Hotspots | 0 | 0 | 0 |
| Quality Gate | Baseline event payload not retained | OK | Passed |

SonarQube outcome:
- The retained baseline event did not preserve a quality-gate flag, but the issue files and measure history show a clean after-state.
- The final rerun on **March 23, 2026** reached `Quality Gate = OK`, `remaining issues = 0`, `coverage = 74.3%`, and `duplicated lines density = 0.0%`.

## OWASP ZAP Security

### Baseline Scan

| Severity | Before (`baseline-v0.1`) | After (`baseline-zap-v1`) | Change |
|----------|-------------------------:|--------------------------:|--------|
| High | 0 | 0 | 0 |
| Medium | 2 | 0 | -2 |
| Low | 6 | 0 | -6 |
| Informational | 3 | 4 | +1 |

### Authenticated API Scan

| Severity | Before (`baseline-v0.1`) | After (`baseline-zap-v1`) | Change |
|----------|-------------------------:|--------------------------:|--------|
| High | 0 | 0 | 0 |
| Medium | 0 | 0 | 0 |
| Low | 3 | 0 | -3 |
| Informational | 5 | 5 | 0 |

ZAP outcome:
- All business-endpoint High, Medium, and Low alerts were cleared by the **March 24, 2026** reruns.
- Remaining alerts are informational only and mostly reflect expected scanner behavior or non-gated caching/URL observations.

## JMeter Performance

| Metric | Before (`baseline-v0.1`) | After (`baseline-jmeter-v1`) | Change | Verdict |
|--------|--------------------------:|-----------------------------:|--------|---------|
| p50 total p95 (ms) | 49.45 | 13.00 | -73.71% | PASS |
| p100 total p95 (ms) | 261.95 | 34.00 | -87.02% | PASS |
| p500 total p95 (ms) | 176.00 | 28.00 | -84.09% | PASS |
| p100 throughput (tx/s) | 57.53 | 59.82 | +3.98% | PASS |
| p500 error rate (%) | 0.00 | 0.00 | 0.00 pts | PASS |
| Soak total p95 (ms) | 970.95 | 56.00 | -94.23% | Improved |
| Soak drift (%) | 137.35 | 30.95 | -106.40 pts | FAIL |
| Spike total p95 (ms) | 6795.00 | 1420.00 | -79.10% | Improved |
| Spike recovery drift (%) | 91.82 | 64.99 | -26.83 pts | FAIL |

### JMeter Hotspot Detail

| Endpoint | Profile | Before p95 (ms) | After p95 (ms) | Change |
|----------|---------|----------------:|---------------:|--------|
| `GET /reports/account-ledger` | soak | 1783.95 | 279.00 | -84.36% |
| `GET /reports/account-ledger` | spike | 8073.40 | 3435.95 | -57.44% |
| `GET /reports/trial-balance` | spike | 10585.00 | 1244.85 | -88.24% |
| `GET /reports/profit-loss` | spike | 7118.35 | 690.90 | -90.29% |
| `GET /reports/balance-sheet` | spike | 5768.95 | 650.95 | -88.72% |
| `POST /journal-entries/bulk` | spike | 1401.70 | 634.00 | -54.77% |

JMeter outcome:
- The final rerun on **March 24, 2026** (`run tag 20260324-113540`) cleared the `p50`, `p100`, and `p500` gates with `0%` errors.
- The branch also cut absolute soak and spike latency sharply, especially on the report endpoints that dominated the original failures.
- The only remaining benchmark miss is the mixed-workload drift heuristic. Endpoint-level drift for the heavy report requests improved, but the overall first-window vs last-window calculation still stays above the thesis threshold because the last window is compositionally heavier than the first.

## Overall Summary

- `baseline-sonarqube-v1` fully cleared the retained SonarQube findings and reached an `OK` quality gate.
- `baseline-zap-v1` fully cleared all gated ZAP alerts on business endpoints.
- `baseline-jmeter-v1` delivered major performance gains and cleared the absolute load gates, with one documented caveat: the soak and spike drift benchmarks remain red under the current mixed-window heuristic even though the report bottlenecks were materially reduced.
