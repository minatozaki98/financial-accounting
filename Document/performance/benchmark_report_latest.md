# Benchmark Report (Latest vs Benchmark)

GeneratedAt: 2026-02-22 23:44:39 +07:00
LatestRunId: 20260222-231435
BenchmarkRunId: 20260219-164143

## Scope
- Tools: JMeter, ZAP, SonarQube
- Latest summary: Document\performance\test-summary-20260222-231435.md
- Baseline anchor: Document/performance/thesis-baseline-anchor.json

## Executive Status
- OverallStatus: FAIL
- SecurityGate: PASS
- PerformanceGate: FAIL
- SonarQualityGate: OK
- UnitCoverage: 5.3%
- IntegrationCoverage: 75.71%

## JMeter Comparison
| Profile | Error% (Bench) | Error% (Latest) | Delta Error% | p95 ms (Bench) | p95 ms (Latest) | Delta p95 ms | Throughput (Bench) | Throughput (Latest) | Delta Throughput |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| p50 | 0 | 0 | 0 | 5 | 64 | 59 | 55.04 | 54.65 | -0.39 |
| p100 | 25.53 | 25.53 | 0 | 7 | 43 | 36 | 60.21 | 60.96 | 0.75 |
| p500 | 25 | 25 | 0 | 12 | 48 | 36 | 63.83 | 63.63 | -0.2 |
| soak | 20.66 | 20.66 | 0 | 9.95 | 51 | 41.05 | 256.69 | 239.05 | -17.64 |
| spike | 25.81 | 25.81 | 0 | 312 | 923 | 611 | 608.31 | 483.58 | -124.73 |

### p100 Persistent Failures
- GET /reports/account-ledger: samples=300, errors=300, errorPct=100
- GET /reports/balance-sheet: samples=300, errors=300, errorPct=100
- GET /reports/profit-loss: samples=300, errors=300, errorPct=100
- GET /reports/trial-balance: samples=300, errors=300, errorPct=100

## ZAP Comparison
- Baseline JSON (Bench): C:\Users\Asus\Documents\GitHub\school\financial-accounting\Document\security\zap-baseline-20260219-163915.json
- Baseline JSON (Latest): C:\Users\Asus\Documents\GitHub\school\financial-accounting\Document\security\zap-baseline-20260222-231435.json
- Baseline all-risk H/M/L/I: 0/2/6/4 -> 0/2/1/3
- Baseline business H/M/L/I: 0/0/0/0 -> 0/0/0/0
- API JSON (Bench): C:\Users\Asus\Documents\GitHub\school\financial-accounting\Document\security\zap-api-20260219-164143.json
- API JSON (Latest): C:\Users\Asus\Documents\GitHub\school\financial-accounting\Document\security\zap-api-20260222-231435.json
- API all-risk H/M/L/I: 0/0/3/5 -> 0/0/1/5
- API business H/M/L/I: 0/0/0/4 -> 0/0/0/4

## SonarQube
- Gate=OK, Bugs=13, Vulnerabilities=0, CodeSmells=7314, Coverage=0.0%, DuplicatedLines=74.3% (Analyses=1).

## Findings
- Gates failing now: unit coverage and JMeter error thresholds (100/500/soak/spike).
- ZAP business risk remains stable at High=0 and Medium=0.
- Latency regressed across all JMeter profiles compared with benchmark.

