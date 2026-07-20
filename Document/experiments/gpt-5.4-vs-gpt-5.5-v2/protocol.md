# GPT-5.4 vs GPT-5.5 Complex API Retest Protocol

## Research Question

Given identical, blinded challenge sources derived from the complex accounting
API reference, how do GPT-5.4 and GPT-5.5 compare on SonarQube static-analysis
remediation, OWASP ZAP workflow-security remediation, and Apache JMeter 5.5
workflow-performance remediation?

## Fixed Inputs

- Reference tag: `benchmark-v2-reference-code`
- Reference code commit: `703a33ddcc7e62ee45d263e34084ff4244526c68`
- Controller branch: `codex/gpt-model-retest-v2-controller`
- Database: `FinancialBenchmarkV2`
- Backup: `C:\Temp\financial-accounting-benchmark-v2\financial-benchmark-v2-clean.bak`
- Backup SHA-256: `E192FD597529F741229042422EB66A96CC48446220D880D4E17B2E70FA58D722`

## Challenge Construction

The controller creates three independent challenge sources:

- SonarQube: `codex/benchmark-sonar-v2-source`
- OWASP ZAP: `codex/benchmark-zap-v2-source`
- Apache JMeter: `codex/benchmark-jmeter-v2-source`

Each challenge source must be exported as a one-commit sanitized repository
without clean-reference history, controller files, hidden tests, prior reports,
mutation manifests, raw controller results, credentials, logs, or sibling model
work.

## Model Controls

For a given tool pair, GPT-5.4 and GPT-5.5 receive byte-identical prompts,
the same challenge source SHA, the same evidence format, the same attempt limit,
and the same verification commands.

Each model/tool run permits one initial remediation attempt and at most two
finding-driven correction attempts. The task stops after the third attempt even
if findings remain.

The model identity must be recorded before every run:

- Codex task ID
- Displayed model label
- Reasoning setting
- Service tier, when visible
- Prompt SHA-256
- Challenge source SHA
- Start and finish time
- Attempt count

If GPT-5.4 or GPT-5.5 cannot be selected, that pair stops. No substitute model
may be used silently.

## Blinding Rules

Model labs must not contain or inspect:

- the clean reference patch or clean-reference branch history
- `benchmark-v2-reference-code`
- controller files or hidden tests
- `sonar-mutations.json`
- previous GPT-5.4/GPT-5.5 comparison reports
- baseline v1 branches or reports
- the other model's patch or transcript
- remotes, reflogs, stashes, sibling worktrees, or unrelated branches

Filesystem blinding is procedural rather than OS-enforced in this local setup.
This must be recorded as a threat to validity even when sanitized labs and
no-remote checks pass.

## Invalid Result Rules

A tool/model result is invalid when:

- the source SHA differs within a model pair
- a Docker image ID, database backup hash, benchmark script checksum, JMX
  checksum, ZAP rule checksum, or scanner identity differs
- the model sees the reference patch, mutation manifest, hidden tests, previous
  comparison, or other model patch
- the model changes scanner rules, exclusions, workloads, thresholds, evidence
  scripts, or database snapshot identity
- human-authored remediation code is present in the model branch
- public or hidden behavior tests are deleted, skipped, or weakened
- API routes, DTO JSON shapes, authorization boundaries, accounting invariants,
  audit semantics, database consistency, or benchmark workloads are broken
- the controller cannot reproduce the final result from the frozen candidate
  commit
- suppressions such as `NOSONAR`, `SuppressMessage`, source exclusions, analyzer
  profile changes, feature deletion, or workload reduction are used

## Tool-Specific Scoring

SonarQube is scored from exact verified issue resolution and direct measures.
The quality-gate label is supporting evidence only because gate conditions may
be ignored by the scanner/server configuration.

SonarQube component weights are fixed:

- 45 percent exact verified issue resolution
- 30 percent behavior preservation
- 15 percent coverage and duplication preservation or improvement
- 10 percent attempt count, elapsed time, and patch efficiency

OWASP ZAP is reported by verified alert class, risk, confidence, business
endpoint coverage, role coverage, and behavior gates. No severity-weighted
overall number is created.

Apache JMeter is reported from three restored-database repetitions per candidate
using median p50, p95, p99, throughput, error rate, dispersion, CPU, memory,
duration, and database postconditions. Setup and login traffic are excluded from
business transaction latency.

## Reporting Rules

Each tool is reported independently. No single overall winner is published when
any track fails its validity gates. Raw artifacts, full SHAs, checksums, run
order, prompts, model identity records, controller results, and interventions
must be retained under `Document/experiments/gpt-5.4-vs-gpt-5.5-v2/`.
