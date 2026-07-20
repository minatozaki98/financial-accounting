# GPT-5.5 Complex API v2 Freeze

Date: 2026-07-20

Branch: `codex/gpt-5.5-v2-freeze`

## Decision

This branch freezes the GPT-5.5 side of the Complex API v2 benchmark as a future benchmark track. It is not part of the current GPT-5.4 vs GPT-5.5 report. The current report continues to use the previously normalized v1 evidence from 2026-07-19.

## Scope

Complex API v2 is retained for a later GPT-5.5 vs GPT-5.6 comparison. Because fresh GPT-5.4 access is not currently available, v2 must not be described as a GPT-5.4 vs GPT-5.5 comparison.

This branch is an evidence and provenance branch. It does not merge SonarQube, OWASP ZAP, and Apache JMeter challenge sources into one code tree. The v2 protocol keeps those challenge sources separate so each tool result remains attributable to its own frozen source and workload.

## Frozen v2 challenge sources

| Track | Source branch | Source commit | Baseline status |
| --- | --- | --- | --- |
| SonarQube | `codex/benchmark-sonar-v2-source` | `072c35b9339aceb11c0c06efd5782374eb73acb4` | valid baseline frozen |
| OWASP ZAP | `codex/benchmark-zap-v2-source` | `bb3fd3c1105d40ad63509d3f4aa57853872c6739` | valid baseline frozen |
| Apache JMeter | `codex/benchmark-jmeter-v2-source` | `3eb8f26b633701f9aa6caad424f6c387e25de37e` | valid baseline frozen |

## GPT-5.5 frozen candidates

| Track | Lab branch | Start commit | Frozen GPT-5.5 commit | Public verification | Hidden verification |
| --- | --- | --- | --- | --- | --- |
| SonarQube | `codex/gpt-5.5-sonar-v2` | `072c35b9339aceb11c0c06efd5782374eb73acb4` | `59e2e3d73172fd4aef8814573bde8af96c7d1f74` | 9 unit + 139 integration; Release build 0 warnings/errors | 14/14 passed |
| OWASP ZAP | `codex/gpt-5.5-zap-v2` | `bb3fd3c1105d40ad63509d3f4aa57853872c6739` | `169278763962a966ec37bda4209624fb7763946f` | 9 unit + 142 integration; Release build 0 warnings/errors | 14/14 passed |
| Apache JMeter | `codex/gpt-5.5-jmeter-v2` | `3eb8f26b633701f9aa6caad424f6c387e25de37e` | `12d8d6e9a18ed79a773635c4a98fe580e9fd27a9` | 9 unit + 134 integration; Release build 0 warnings/errors | 14/14 passed |

## Candidate patch summary

| Track | Files changed | Insertions | Deletions | Notes |
| --- | ---: | ---: | ---: | --- |
| SonarQube | 11 | 311 | 307 | Refactored issue-supported challenge helpers plus small service/test analyzer fixes. |
| OWASP ZAP | 2 | 33 | 21 | Removed information-leak/misconfigured CORS headers and extended safe API header tests. |
| Apache JMeter | 3 | 96 | 40 | Pushed period filtering into SQL and batched journal-import/reconciliation lookup work. |

## Baseline evidence summary

### SonarQube

- Project key: `financial-accounting-sonar-v2-source`
- Source commit: `072c35b9339aceb11c0c06efd5782374eb73acb4`
- Verified issues: 60
- Rule families: 15
- Largest rule-family share: 20%
- Quality gate: ERROR
- Coverage: 73.0%
- Duplicated lines density: 0.0%
- Public verification: 9 unit tests and 139 integration tests passed; Release build had 0 warnings and 0 errors
- Hidden verification: 14/14 passed

### OWASP ZAP

- Source commit: `bb3fd3c1105d40ad63509d3f4aa57853872c6739`
- Imported URLs: 38
- Endpoint coverage: valid
- Verified business alert instances: 36
- Distinct alert IDs: 8
- Medium-or-higher instances: 5
- Public verification: 9 unit tests and 134 integration tests passed; Release build had 0 warnings and 0 errors
- Hidden verification: 14/14 passed

### Apache JMeter

- Source commit: `3eb8f26b633701f9aa6caad424f6c387e25de37e`
- Frozen load: 10 users, 60-second ramp, 10 loops, 3 repetitions
- Validity gate: all business samples successful, all postconditions passed, coefficient of variation within 15%
- Period-close median p95: 5574 ms
- Journal-import valid median p95: 921 ms
- Journal-import invalid median p95: 475 ms
- Reconciliation median p95: 4872 ms
- Public verification: 9 unit tests and 134 integration tests passed; Release build had 0 warnings and 0 errors
- Hidden verification: 14/14 passed

## Reporting rule

For the current manuscript/report, use the normalized v1 GPT-5.4 vs GPT-5.5 results only.

For future work, this branch can serve as the v2 GPT-5.5 side when paired against a GPT-5.6 run on the same three frozen challenge sources. Any future v2 report must state that v2 is GPT-5.5 vs GPT-5.6, not GPT-5.4 vs GPT-5.5.

## Remaining controller work before a future v2 comparison

The frozen candidates passed public behavior/build gates and controller hidden tests. Full post-remediation SonarQube, OWASP ZAP, and Apache JMeter measurements are intentionally not converted into a GPT-5.4-vs-GPT-5.5 comparison here. When the future GPT-5.6 side is run, the controller should execute the same post-remediation tool measurements for GPT-5.5 and GPT-5.6 under one environment lock.
