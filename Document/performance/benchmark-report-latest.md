# Benchmark Report (JMeter, ZAP, SonarQube)

Generated at: 2026-02-21 (local environment)

## Scope

This report summarizes benchmark targets and latest observed results for:
- Apache JMeter performance and reliability gates
- OWASP ZAP security gates
- SonarQube quality gate and key measures

## Benchmark Definitions

### JMeter thresholds

Source: `scripts/phase4/run-thesis-suite.ps1`

| Scenario | Error % Target | p95 Target |
| --- | ---: | ---: |
| p50 | <= 0.5 | <= 300 ms |
| p100 | <= 1.0 | <= 500 ms |
| p500 | <= 2.0 | <= 1200 ms |
| soak | <= 1.0 | drift <= 20% |
| spike | <= 3.0 | recovery drift <= 20% |

### ZAP thresholds

Source: `scripts/phase4/run-thesis-suite.ps1`, `scripts/phase4/zap-api-rules.tsv`

- Business API alerts: `High = 0`, `Medium = 0`
- Business FAIL-rule hits: `0`
- FAIL rules configured:
  - `40012` Reflected XSS
  - `40014` Persistent XSS
  - `40018` SQL Injection
  - `40019` SQL Injection (MySQL)
  - `40020` SQL Injection (Hypersonic SQL)
  - `40021` SQL Injection (Oracle)

### SonarQube thresholds

Source: `scripts/phase4/run-thesis-suite.ps1`, live Sonar API

- Thesis suite gate: Sonar quality gate status must be `OK`
- Active gate in environment: `Sonar way` (default), with new-code conditions:
  - `new_violations > 0` fails
  - `new_coverage < 80` fails
  - `new_duplicated_lines_density > 3` fails
  - `new_security_hotspots_reviewed < 100` fails

## Latest Results

### JMeter summary

Sources:
- `Document/performance/report-20260219-164143-p50/statistics.json`
- `Document/performance/report-20260219-164143-p100/statistics.json`
- `Document/performance/report-20260219-164143-p500/statistics.json`
- `Document/performance/report-20260219-164143-soak/statistics.json`
- `Document/performance/report-20260219-164143-spike/statistics.json`
- `Document/performance/jmeter-20260219-164143-soak.jtl`
- `Document/performance/jmeter-20260219-164143-spike.jtl`

| Scenario | Error % | Error Gate | p95 (ms) | p95 Gate | Throughput (tx/s) |
| --- | ---: | --- | ---: | --- | ---: |
| p50 | 0.00 | PASS | 5.00 | PASS | 55.04 |
| p100 | 25.53 | FAIL | 7.00 | PASS | 60.21 |
| p500 | 25.00 | FAIL | 12.00 | PASS | 63.83 |
| soak | 20.66 | FAIL | 9.95 | N/A | 256.69 |
| spike | 25.81 | FAIL | 312.00 | N/A | 608.31 |

Drift checks:
- Soak drift: `-57.89%` (PASS, threshold <= 20%)
- Spike recovery drift: `1262.50%` (FAIL, threshold <= 20%)

JMeter benchmark status: **FAIL**

### ZAP summary

Sources:
- `Document/security/zap-baseline-20260219-163915.json`
- `Document/security/zap-api-20260219-164143.json`

| Scan | High | Medium | Low | Info | Business High | Business Medium | Business FAIL hits |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| baseline | 0 | 2 | 6 | 4 | 0 | 0 | None |
| api | 0 | 0 | 3 | 5 | 0 | 0 | None |

ZAP benchmark status (business API gate): **PASS**

### SonarQube summary

Source:
- Sonar API (`http://localhost:9000`) for project `financial-accounting`

Quality gate:
- `QualityGate = OK` -> **PASS**

Key measures snapshot:
- `coverage = 0.0`
- `bugs = 1`
- `vulnerabilities = 0`
- `code_smells = 18`
- `reliability_rating = 3.0`
- `security_rating = 1.0`
- `sqale_rating = 1.0`
- `duplicated_lines_density = 0.0`
- `complexity = 820`
- `ncloc = 3049`

## Overall

| Tool | Benchmark Status |
| --- | --- |
| JMeter | FAIL |
| ZAP | PASS |
| SonarQube | PASS |

Overall benchmark outcome: **FAIL** (driven by JMeter performance/reliability gate failures).
