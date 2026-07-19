# GPT-5.4 vs GPT-5.5: Financial Accounting API Remediation Benchmark

## Experimental Controls

This benchmark compares GPT-5.4 and GPT-5.5 remediation branches against the same Financial Accounting API pre-fix source lineage.

- Common pre-fix source commit: `7a0469d9401a3061941b44fcd46b3beca1bc6f994b`
- GPT-5.5 committed baseline evidence commit: `ec034038c284e77efa4ed2310b13fc9662259286`
- Clean SQL Server restore point: `financial-gpt55-clean.bak`
- Normalized rerun date: `2026-07-19`
- Runtime host: Windows 11, .NET `9.0.308`, Docker `29.2.0`
- JMeter version: Docker image `justb4/jmeter:5.5`

GPT-5.5 remediation was blinded from GPT-5.4 branches, commits, reflogs, and reports until all GPT-5.5 fix branches were committed and pushed.

## Source and Branch Provenance

| Track | Branch / source | Commit |
| --- | --- | --- |
| Common pre-fix code | historical pre-fix parent | `7a0469d9401a3061941b44fcd46b3beca1bc6f994b` |
| GPT-5.5 baseline evidence | `codex/gpt-5.5-baseline` | `ec034038c284e77efa4ed2310b13fc9662259286` |
| GPT-5.5 SonarQube | `codex/gpt-5.5-sonarqube-v1` | `19763f15cbc8412eb74ff5b9d706be69456e62ff` |
| GPT-5.5 OWASP ZAP | `codex/gpt-5.5-zap-v1` | `aa1a9bd7cefe4f3a07c3bd10d0bde7d5409e3f4b` |
| GPT-5.5 JMeter | `codex/gpt-5.5-jmeter-v1` | `8d0be3b918008f1cf38a7c61669f8d7609df0963` |
| GPT-5.4 SonarQube normalized code | detached worktree | `a2279bcbdc20751529335cf72f8baac1bc6f994b` |
| GPT-5.4 OWASP ZAP normalized code | detached worktree | `5f3bd3ccd9e0d460f52cac6a8a0d5fdceff1ce3d` |
| GPT-5.4 JMeter normalized code | detached worktree | `78b08b62570dcf6fe436354e8e6b770ab2074445` |

The local historical branch `baseline-jmeter-v1` currently points at later documentation commit `3c9392d`, so the normalized JMeter rerun intentionally used the exact code commit `78b08b6` specified by the benchmark plan.

## Environment and Tool Image Identity

Docker image IDs matched `Document/experiments/gpt-5.5/environment.json` before normalized GPT-5.4 reruns.

| Tool | Frozen image identity |
| --- | --- |
| SonarQube | `sha256:160bd2f6a3485bd09b655ef22dd63c02bd1fa7ba82aa5d9973fd010b8bcca0b3` / `sonarqube@sha256:160bd2f6a3485bd09b655ef22dd63c02bd1fa7ba82aa5d9973fd010b8bcca0b3` |
| OWASP ZAP | `sha256:8d387b1a63e3425beef4846e39719f5af2a787753af2d8b6558c6257d7a577a2` / `ghcr.io/zaproxy/zaproxy@sha256:8d387b1a63e3425beef4846e39719f5af2a787753af2d8b6558c6257d7a577a2` |
| JMeter | `sha256:088ac52b759a198a5afa5ae13d0a6306e9f2017d71ad140ff57427f6930406f7` / `justb4/jmeter@sha256:088ac52b759a198a5afa5ae13d0a6306e9f2017d71ad140ff57427f6930406f7` |

## SonarQube Outcome Comparison

Both models reduced SonarQube code smells from `21` to `0` and kept quality gate `OK`.

| Model | Quality gate | Coverage | Code smells | Bugs | Vulnerabilities | NCLOC |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| Before fixes | OK | 74.4 | 21 | 0 | 0 | 3211 |
| GPT-5.4 normalized | OK | 74.3 | 0 | 0 | 0 | 3198 |
| GPT-5.5 final | OK | 74.3 | 0 | 0 | 0 | 3199 |

| Model | Code smell reduction | Gate result |
| --- | ---: | --- |
| GPT-5.4 | 21 to 0, 100% reduction | Pass |
| GPT-5.5 | 21 to 0, 100% reduction | Pass |

Interpretation: SonarQube outcome is effectively tied. GPT-5.5 reached the same gate with a smaller net source patch.

## OWASP ZAP Outcome Comparison

ZAP was run in two modes: unauthenticated baseline scan and authenticated OpenAPI/API scan. Counts below include all alert categories, including informational alerts. Pass/fail is judged separately from raw category count because ZAP warning reports can still be generated when `-IgnoreWarnings` is used.

| Scan | Before fixes | GPT-5.4 normalized | GPT-5.5 final |
| --- | ---: | ---: | ---: |
| Baseline alert categories | 11 | 2 | 5 |
| Baseline alert instances | 35 | 5 | 12 |
| API alert categories | 9 | 4 | 7 |
| API alert instances | 332 | 110 | 330 |

| Scan | GPT-5.4 residual alerts | GPT-5.5 residual alerts |
| --- | --- | --- |
| Baseline | 2 informational categories: Non-Storable Content, Storable and Cacheable Content | 1 medium Swagger vulnerable JS library, 1 low timestamp disclosure, 3 informational categories |
| API | 1 medium HTTP-only local transport alert, 3 informational categories | 1 medium HTTP-only local transport alert, 1 low unexpected content type, 5 informational categories |

| Model | Security gate result |
| --- | --- |
| GPT-5.4 | Pass for no high/medium business-endpoint findings in normalized rerun; local HTTP transport warning remains |
| GPT-5.5 | Pass for no high/medium business-endpoint findings in final rerun; Swagger JS and local HTTP transport warnings remain |

Interpretation: GPT-5.4 produced the cleaner normalized ZAP output. GPT-5.5 fixed the major security-header issues with a smaller patch, but left more non-business residual alerts.

## Apache JMeter Outcome Comparison

The JMeter gate uses p95/error thresholds for p50, p100, and p500 profiles; soak and spike also use first-20%-vs-last-20% p95 drift from `run-thesis-suite.ps1`.

### Aggregate performance

| Profile | Metric | Before fixes | GPT-5.4 normalized | GPT-5.5 final |
| --- | --- | ---: | ---: | ---: |
| p50 | p95 ms | 24 | 229 | 23 |
| p50 | p99 ms | 62 | 1086 | 48 |
| p50 | throughput/s | 53.34 | 53.95 | 55.02 |
| p100 | p95 ms | 114 | 51 | 52 |
| p100 | p99 ms | 585 | 127 | 141 |
| p100 | throughput/s | 59.42 | 61.02 | 59.84 |
| p500 | p95 ms | 88 | 40 | 40 |
| p500 | p99 ms | 170 | 92 | 99 |
| p500 | throughput/s | 62.97 | 63.03 | 63.68 |
| soak | p95 ms | 409 | 117 | 143 |
| soak | p99 ms | 892 | 284 | 287 |
| soak | throughput/s | 162.35 | 216.57 | 222.18 |
| spike | p95 ms | 4509 | 2594 | 2482 |
| spike | p99 ms | 6431 | 4932 | 4226 |
| spike | throughput/s | 149.83 | 259.18 | 265.04 |

All three runs had `0.00%` JMeter error rate in all five profiles.

### Drift gates

| Run | Soak first p95 | Soak last p95 | Soak drift | Spike first p95 | Spike last p95 | Spike drift | Gate result |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| Before fixes | 478 ms | 409 ms | -14.44% | 3005 ms | 4332 ms | 44.16% | Fail: spike recovery drift |
| GPT-5.4 normalized | 337 ms | 118 ms | -64.99% | 2272 ms | 2295 ms | 1.01% | Pass |
| GPT-5.5 final | 202 ms | 142 ms | -29.70% | 2672 ms | 2039 ms | -23.69% | Pass |

### Model-specific performance read

GPT-5.4 is slightly faster than GPT-5.5 in p100/p500/soak p99, but regresses p50 tail latency badly: p50 p99 rises from `62 ms` before fixes to `1086 ms`. GPT-5.5 is more balanced: it improves every p99 profile relative to baseline and has better spike p99/throughput than GPT-5.4.

## Patch Size and Files Changed

Source/test-only diff statistics exclude `Document/**` generated evidence.

| Track | Source/test patch size | Main touched areas |
| --- | --- | --- |
| GPT-5.4 SonarQube | 13 files, 148 insertions, 160 deletions | controllers, services, DTOs, data context, RBAC/token tests |
| GPT-5.5 SonarQube | 13 files, 86 insertions, 99 deletions | same main areas, smaller net patch |
| GPT-5.4 ZAP | 7 files, 104 insertions, 24 deletions | new security-header middleware, Program/appsettings, security-header tests |
| GPT-5.5 ZAP | 4 files, 38 insertions, 6 deletions | middleware ordering/config additions, security-header tests |
| GPT-5.4 JMeter | 13 files, 783 insertions, 56 deletions | ledger cache abstraction, SQL Server performance index startup, report/controller changes, tests |
| GPT-5.5 JMeter | 8 files, 316 insertions, 79 deletions | versioned read cache, service-level invalidation, report/account/period tests |

## Tests Added and Regression Results

| Track | Tests added/changed | Verified result |
| --- | --- | --- |
| GPT-5.4 SonarQube | RBAC/token-related tests changed | Normalized Sonar run executed tests: 2 unit, 96 integration, all passed |
| GPT-5.5 SonarQube | RBAC/token-related tests changed | Worker/controller log: 2 unit, 96 integration, all passed; final Sonar gate OK |
| GPT-5.4 ZAP | Security header tests | Normalized rerun: 2 unit, 103 integration, all passed |
| GPT-5.5 ZAP | Security header tests | Focused security-header tests passed 3/3 in both attempts; final ZAP reports generated |
| GPT-5.4 JMeter | Account ledger cache/model tests and report tests | Normalized rerun: 6 unit, 100 integration, all passed |
| GPT-5.5 JMeter | Report persistence and account cache invalidation tests | Worker/controller log: 2 unit, 98 integration, all passed; focused tests 9/9 |

## Attempts, Elapsed Time, and Human Intervention

| Track | GPT-5.4 process metadata | GPT-5.5 process metadata |
| --- | --- | --- |
| SonarQube | Historical prompt/attempt timing is incomplete; normalized scan rerun only | Codex task `019f7a35-a25e-7d40-8bf6-c2039f70972e`, 2 attempts, no code-level human intervention |
| OWASP ZAP | Historical prompt/attempt timing is incomplete; normalized scan rerun only | Codex task `019f7a46-601e-7752-9e5a-778de76c1760`, 2 attempts, no third attempt; controller reran final scans |
| JMeter | Historical prompt/attempt timing is incomplete; normalized matrix rerun only | Codex task `019f7a66-f631-7493-b2e3-7437e04c86a8`, 2 matrix attempts by worker; first was invalid infrastructure binding, second valid; controller reran final matrix |

GPT-5.5 worker code changes were not manually corrected after generation. Controller actions were limited to environment setup, clean DB restore, final reruns, evidence capture, and metadata/report writing.

## Residual Findings and Failed Gates

| Area | GPT-5.4 residual | GPT-5.5 residual |
| --- | --- | --- |
| SonarQube | No code smells, no bugs, no vulnerabilities | No code smells, no bugs, no vulnerabilities |
| ZAP baseline | Informational only | Medium Swagger vulnerable JS library remains; low timestamp disclosure remains; informational alerts remain |
| ZAP API | Medium HTTP-only local transport warning remains; informational alerts remain | Medium HTTP-only local transport warning remains; low unexpected content type remains; informational alerts remain |
| JMeter | Passes documented p95/error/drift gates, but p50 p99 is much worse than baseline | Passes documented p95/error/drift gates, with residual high account-ledger spike tail |

No normalized run failed its final tool execution. The common pre-fix baseline failed the spike recovery drift gate.

## Historical 2026-03 Results vs Normalized Reruns

Historical GPT-5.4 fix branches and report artifacts were produced in the earlier 2026-03 workflow. That historical process metadata is incomplete: exact prompt text, elapsed task timings, and number of model attempts are not fully recoverable from the branch state alone.

For that reason, this report uses normalized 2026-07-19 reruns for GPT-5.4 tool outcomes. Historical branch SHAs are used only to identify the GPT-5.4 code that was retested. The normalized reruns use the same Docker image identities, database backup, scripts, and local machine state as the GPT-5.5 experiment.

## Threats to Validity

- The experiment ran on one local Windows machine; CPU, memory, SQL Server, Docker, and background OS noise can affect JMeter latency.
- GPT-5.4 was evaluated from historical commits, while GPT-5.5 was evaluated live in Codex with fresh interaction logs.
- GPT-5.4 historical prompt counts and elapsed model timings are incomplete, so process-efficiency comparisons are weaker than output comparisons.
- ZAP findings include local HTTP transport and Swagger/static asset alerts; these are not always direct business-endpoint vulnerabilities.
- The GPT-5.5 JMeter fix uses in-process caching. It is valid for the single-instance benchmark, but a multi-instance deployment would need shared/distributed invalidation.
- The GPT-5.4 JMeter fix appears more invasive, including SQL Server startup indexing. That may be a stronger production optimization, but also expands operational risk.

## Conclusion

SonarQube is a tie on final quality: both models reached `0` code smells with gate `OK`; GPT-5.5 did it with a smaller source patch.

OWASP ZAP favors GPT-5.4 on normalized output cleanliness: fewer residual categories and instances. GPT-5.5 used a smaller patch and removed the main header findings, but left more non-business residual alerts.

Apache JMeter is mixed. GPT-5.4 is slightly better on p100/p500/soak p99, but introduces a large p50 tail-latency regression. GPT-5.5 is more balanced and wins spike p99/throughput with a smaller patch. If the priority is stable performance under all profiles with lower implementation risk, GPT-5.5 is the stronger JMeter result. If the priority is peak/soak p99 alone and the p50 regression is accepted, GPT-5.4 is competitive.

Overall: GPT-5.5 matched Sonar quality with less code, was weaker than GPT-5.4 on ZAP cleanliness, and produced the more balanced JMeter remediation.
