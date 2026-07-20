# GPT-5.4 vs GPT-5.5 Complex API Retest Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Retest GPT-5.4 and GPT-5.5 on identical, blinded SonarQube, OWASP ZAP, and Apache JMeter challenge sources derived from the new accounting-period close, journal-import, and bank-reconciliation APIs.

**Architecture:** First freeze the current clean API implementation as a hidden reference. Derive three independent, behavior-preserving challenge sources: a verified SonarQube static-analysis challenge, a workflow-aware ZAP security challenge, and a workflow-aware JMeter performance challenge. Export each challenge as a root commit with no reference history, run both models with identical per-tool prompts and attempt limits, then score only from controller-owned evidence after both model branches are frozen.

**Tech Stack:** GPT-5.4 and GPT-5.5 in Codex, Git, PowerShell, ASP.NET Core 8, EF Core 8, SQL Server, SQLite integration tests, SonarQube Community, OWASP ZAP, Apache JMeter 5.5, Docker Desktop.

## Global Constraints

- Do not predict either model's score, ranking, or likely winner.
- The clean reference must be reviewed and committed before any challenge source is created.
- The clean reference, mutation manifest, hidden tests, previous GPT-5.4/GPT-5.5 reports, and the other model's patch must be unavailable to each model task.
- Each tool has its own challenge source commit; do not combine Sonar, ZAP, and JMeter challenge mutations.
- GPT-5.4 and GPT-5.5 must start from the same root commit for a given tool.
- Use the same per-tool prompt, Codex reasoning setting, attempt limit, tool feedback format, database snapshot, Docker image IDs, and controller verification for both models.
- Permit one initial remediation attempt and at most two finding-driven correction attempts per model and tool.
- Human activity is limited to experiment setup, environment recovery, supplying raw tool feedback, rejecting unsafe actions, and recording evidence. Human-authored remediation code invalidates that model/tool run.
- Challenge branches must preserve routes, DTO JSON shapes, authorization, accounting invariants, audit semantics, database consistency, and benchmark workloads.
- Challenge branches must never be deployed, merged into `main`, or presented as production-ready code.
- No `NOSONAR`, `SuppressMessage`, analyzer/profile changes, source exclusions, disabled tests, weakened assertions, reduced JMeter load, relaxed ZAP rules, or feature deletion.
- Run dynamic and performance measurements from the same restored SQL Server snapshot.
- Run JMeter three times per frozen candidate and compare medians plus dispersion; do not select the best run.
- Treat SonarQube's quality-gate label as supporting evidence only. Exact verified issues and direct measures are the primary Sonar evidence.
- Report each tool independently. Do not publish a single overall winner when any tool track fails its validity gates.
- Preserve all earlier comparison reports. Every v2 report and artifact uses a new path.

---

## Chosen Design and Rejected Alternatives

### Chosen: three controlled challenge tracks

All tracks originate from the same clean reference code, but each receives only
the mutations or workload changes needed for its tool. This isolates what each
model is being asked to improve and makes failed validity gates local to one
track.

### Rejected: scan only the clean reference

This is useful as a pilot, but it is not the comparison experiment. The earlier
Sonar track saturated when both models removed the same small finding set. A
clean scan may again be too easy and cannot be assumed to be discriminative.

### Rejected: one combined challenge branch

A static-analysis mutation can change runtime security or latency, while a
performance mutation can change Sonar complexity. A combined source would make
attribution ambiguous and could give the second tool an unintended advantage.

---

## Branch and Artifact Map

### Reference and controller branches

- `codex/sonar-challenge-api-reference`: clean, known-good implementation.
- `codex/gpt-model-retest-v2-controller`: controller-only manifests, hidden tests, checksums, prompts, and scoring scripts.

### Sanitized challenge source branches

- `codex/benchmark-sonar-v2-source`
- `codex/benchmark-zap-v2-source`
- `codex/benchmark-jmeter-v2-source`

Each source branch must contain one root commit and no parent that exposes the
clean implementation.

### Model result branches

- `codex/gpt-5.4-sonar-v2`
- `codex/gpt-5.5-sonar-v2`
- `codex/gpt-5.4-zap-v2`
- `codex/gpt-5.5-zap-v2`
- `codex/gpt-5.4-jmeter-v2`
- `codex/gpt-5.5-jmeter-v2`
- `codex/gpt-5.4-vs-gpt-5.5-v2`

### New experiment files

- `Document/experiments/gpt-5.4-vs-gpt-5.5-v2/protocol.md`
- `Document/experiments/gpt-5.4-vs-gpt-5.5-v2/environment.json`
- `Document/experiments/gpt-5.4-vs-gpt-5.5-v2/branch-map.json`
- `Document/experiments/gpt-5.4-vs-gpt-5.5-v2/run-order.json`
- `Document/experiments/gpt-5.4-vs-gpt-5.5-v2/prompts/sonar.txt`
- `Document/experiments/gpt-5.4-vs-gpt-5.5-v2/prompts/zap.txt`
- `Document/experiments/gpt-5.4-vs-gpt-5.5-v2/prompts/jmeter.txt`
- `Document/experiments/gpt-5.4-vs-gpt-5.5-v2/controller/sonar-mutations.json`
- `Document/experiments/gpt-5.4-vs-gpt-5.5-v2/controller/hidden-tests/`
- `Document/experiments/gpt-5.4-vs-gpt-5.5-v2/baseline/{sonar,zap,jmeter}/`
- `Document/experiments/gpt-5.4-vs-gpt-5.5-v2/results/{gpt-5.4,gpt-5.5}/`
- `Document/experiments/gpt-5.4-vs-gpt-5.5-v2/comparison.json`
- `Document/experiments/gpt-5.4-vs-gpt-5.5-v2/comparison.md`
- `Document/outputs/gpt-5.4-vs-gpt-5.5-v2.html`

### New benchmark infrastructure

- `scripts/benchmark-v2/export-sanitized-challenge.ps1`
- `scripts/benchmark-v2/export-sonar-evidence.ps1`
- `scripts/benchmark-v2/score-sonar-challenge.ps1`
- `scripts/benchmark-v2/run-hidden-tests.ps1`
- `scripts/benchmark-v2/run-zap-workflows.ps1`
- `scripts/benchmark-v2/run-jmeter-workflows.ps1`
- `scripts/benchmark-v2/restore-benchmark-database.ps1`
- `Document/performance/jmeter/v2-period-close.jmx`
- `Document/performance/jmeter/v2-journal-import.jmx`
- `Document/performance/jmeter/v2-reconciliation.jmx`

---

### Task 1: Freeze the clean reference implementation

**Files:**

- Modify: `Document/experiments/sonar-challenge-v2/reference-manifest.md`
- Verify: all current API, BAL, MODEL, schema, and test changes

**Interfaces:**

- Consumes: `codex/sonar-challenge-api-reference` based on `11f8cfd664e09f1c6831dd1e8f7f05a5c40bfc08`
- Produces: a tagged clean code commit and a separate manifest commit

- [ ] **Step 1: Confirm the branch and inspect every pending path**

```powershell
git branch --show-current
git status --short
git diff --check
```

Expected: branch is `codex/sonar-challenge-api-reference`; only the reference
implementation, tests, SQL schema, design, plans, and manifest are pending.

- [ ] **Step 2: Run the final clean-reference verification**

```powershell
dotnet test .\API\API.sln -c Debug --nologo
dotnet build .\API\API.sln -c Release --nologo
```

Expected: 9 unit tests and 134 integration tests pass; Release build reports
zero warnings and zero errors. If counts legitimately change during review,
record the fresh counts instead of copying these values.

- [ ] **Step 3: Commit the reference code without the controller manifest**

```powershell
git add API BAL MODEL tests `
  Document/sql/financial_accounting_schema.sql `
  docs/superpowers/specs/2026-07-20-sonar-challenge-complex-api-reference-design.md `
  docs/superpowers/plans/2026-07-20-sonar-challenge-complex-api-reference.md
git diff --cached --check
git commit -m "feat: add complex accounting benchmark reference APIs"
$referenceCodeCommit = (git rev-parse HEAD).Trim()
git tag benchmark-v2-reference-code $referenceCodeCommit
```

Expected: `$referenceCodeCommit` identifies the exact known-good code tree.

- [ ] **Step 4: Record the code commit in the reference manifest**

Replace the current “not assigned” status with:

```markdown
- Reference code commit: use the full SHA printed in Step 3
- Reference tag: `benchmark-v2-reference-code`
- Reference manifest commit: recorded by Git history; not embedded recursively
```

Then commit the manifest and this retest plan:

```powershell
git add `
  Document/experiments/sonar-challenge-v2/reference-manifest.md `
  docs/superpowers/plans/2026-07-20-gpt-5-4-vs-gpt-5-5-complex-api-retest.md
git diff --cached --check
git commit -m "docs: define GPT-5.4 and GPT-5.5 complex API retest"
```

- [ ] **Step 5: Push only after the user authorizes publication**

```powershell
git push -u origin codex/sonar-challenge-api-reference
git push origin benchmark-v2-reference-code
```

Expected: the branch and tag resolve to the locally verified commits.

---

### Task 2: Create the controller protocol and frozen environment

**Files:**

- Create: `Document/experiments/gpt-5.4-vs-gpt-5.5-v2/protocol.md`
- Create: `Document/experiments/gpt-5.4-vs-gpt-5.5-v2/environment.json`
- Create: `Document/experiments/gpt-5.4-vs-gpt-5.5-v2/branch-map.json`
- Create: `Document/experiments/gpt-5.4-vs-gpt-5.5-v2/run-order.json`
- Create: `scripts/benchmark-v2/restore-benchmark-database.ps1`

**Interfaces:**

- Consumes: the clean reference tag, Docker Desktop, SQL Server, and the existing phase-4 scripts
- Produces: controller-owned experiment identity, image checksums, database restore command, and pre-registered run order

- [ ] **Step 1: Create the controller branch**

```powershell
git switch -c codex/gpt-model-retest-v2-controller
$experimentRoot = "Document/experiments/gpt-5.4-vs-gpt-5.5-v2"
New-Item -ItemType Directory -Force `
  "$experimentRoot/prompts", `
  "$experimentRoot/controller/hidden-tests", `
  "$experimentRoot/baseline", `
  "$experimentRoot/results" | Out-Null
```

- [ ] **Step 2: Create one deterministic SQL Server snapshot**

Seed sufficient data for all new workflows:

- At least 24 accounting periods, with separate open periods for warm-up and measurement.
- At least 200 active accounts.
- At least 50,000 posted journal entries.
- At least 5,000 reconciliation candidates containing exact, ambiguous, and unmatched cases.
- CSV fixtures containing 10, 100, 1,000, and 10,000 rows.

Back up the database as `financial-benchmark-v2-clean.bak`, compute SHA-256,
and make `restore-benchmark-database.ps1` verify the hash before every restore.

- [ ] **Step 3: Record immutable environment values**

After the backup exists, create `environment.json` from live commands:

```powershell
$backupHash = (Get-FileHash $benchmarkBackup -Algorithm SHA256).Hash
$environment = [ordered]@{
    referenceTag = "benchmark-v2-reference-code"
    referenceCodeCommit = (git rev-list -n 1 benchmark-v2-reference-code).Trim()
    dotnetSdk = (& dotnet --version).Trim()
    operatingSystem = (Get-CimInstance Win32_OperatingSystem |
        Select-Object Caption, Version, OSArchitecture)
    cpu = (Get-CimInstance Win32_Processor |
        Select-Object Name, NumberOfCores, NumberOfLogicalProcessors)
    memoryBytes = (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory
    dockerServerVersion = (& docker version --format "{{.Server.Version}}").Trim()
    sonarImageId = (& docker image inspect sonarqube:community --format "{{.Id}}").Trim()
    zapImageId = (& docker image inspect ghcr.io/zaproxy/zaproxy:stable --format "{{.Id}}").Trim()
    jmeterImageId = (& docker image inspect justb4/jmeter:5.5 --format "{{.Id}}").Trim()
    sonarScannerVersion = ((& dotnet-sonarscanner --version) | Select-Object -Last 1).Trim()
    jmeterVersion = "5.5"
    databaseBackupSha256 = $backupHash
    capturedAtUtc = (Get-Date).ToUniversalTime().ToString("o")
}
$environment | ConvertTo-Json -Depth 8 |
    Set-Content "$experimentRoot/environment.json" -Encoding UTF8
```

Reject blank identifiers before committing the environment file.

- [ ] **Step 4: Pre-register a counterbalanced run order**

Use this fixed order:

```json
{
  "sonar": ["GPT-5.4", "GPT-5.5"],
  "zap": ["GPT-5.5", "GPT-5.4"],
  "jmeter": ["GPT-5.4", "GPT-5.5"]
}
```

This alternates which model runs first across the dynamic tracks. Do not alter
the order after inspecting any result.

- [ ] **Step 5: Write the protocol validity rules**

`protocol.md` must state that a tool/model result is invalid when:

- The source SHA differs within a model pair.
- A Docker image ID or database hash differs.
- A model sees the reference patch, mutation manifest, hidden tests, previous comparison, or other model patch.
- The model changes scanners, rules, exclusions, workloads, thresholds, or evidence scripts.
- Human-authored remediation code is present.
- Public or hidden behavior tests are deleted or weakened.
- The controller cannot reproduce the final result from the frozen commit.
- Filesystem isolation is procedural rather than OS-enforced; record this as a
  threat to validity even when the sanitized lab and no-remote checks pass.

- [ ] **Step 6: Commit the controller protocol before challenge construction**

```powershell
git add Document/experiments/gpt-5.4-vs-gpt-5.5-v2 scripts/benchmark-v2
git diff --cached --check
git commit -m "test: pre-register GPT model retest protocol"
```

---

### Task 3: Build the hidden behavioral verification suite

**Files:**

- Create: `Document/experiments/gpt-5.4-vs-gpt-5.5-v2/controller/hidden-tests/FinancialAccounting.BenchmarkHiddenTests.csproj`
- Create: `Document/experiments/gpt-5.4-vs-gpt-5.5-v2/controller/hidden-tests/PeriodCloseHiddenTests.cs`
- Create: `Document/experiments/gpt-5.4-vs-gpt-5.5-v2/controller/hidden-tests/JournalImportHiddenTests.cs`
- Create: `Document/experiments/gpt-5.4-vs-gpt-5.5-v2/controller/hidden-tests/ReconciliationHiddenTests.cs`
- Create: `Document/experiments/gpt-5.4-vs-gpt-5.5-v2/controller/hidden-tests/ContractAndSchemaHiddenTests.cs`
- Create: `scripts/benchmark-v2/run-hidden-tests.ps1`

**Interfaces:**

- Consumes: `-CandidateRoot <absolute candidate checkout>`
- Produces: TRX, console output, and JSON pass/fail summary without modifying candidate source

- [ ] **Step 1: Make the hidden project accept the candidate root**

Use an MSBuild property named `CandidateRoot` and reference:

```xml
<ProjectReference Include="$(CandidateRoot)\API\API.csproj" />
<ProjectReference Include="$(CandidateRoot)\BAL\BAL.csproj" />
<ProjectReference Include="$(CandidateRoot)\MODEL\MODEL.csproj" />
<ProjectReference Include="$(CandidateRoot)\tests\FinancialAccounting.IntegrationTests\FinancialAccounting.IntegrationTests.csproj" />
```

`run-hidden-tests.ps1` must reject a missing or dirty candidate and run:

```powershell
dotnet test $hiddenProject `
  -p:CandidateRoot="$CandidateRoot" `
  --logger "trx;LogFileName=hidden-$RunTag.trx" `
  --results-directory $ResultsDir `
  --nologo
```

- [ ] **Step 2: Cover behavior that unsafe “easy fixes” could break**

The hidden tests must include:

- Period-close rollback, version conflict, same-request replay, different-request conflict, and ledger refresh.
- CSV quoted-field parsing, 10,000-row boundary, duplicate references, invalid atomic-batch rejection, actor isolation, commit replay, and rollback.
- Reconciliation contested candidates, deterministic tie handling, manual uniqueness, finalization concurrency, replay, and exception listing.
- Route, JSON, authorization, Swagger generation, EF concurrency, unique indexes, and decimal precision.

- [ ] **Step 3: Prove the clean reference passes**

```powershell
.\scripts\benchmark-v2\run-hidden-tests.ps1 `
  -CandidateRoot (git rev-parse --show-toplevel) `
  -RunTag "reference" `
  -ResultsDir "$experimentRoot/controller/hidden-test-results/reference"
```

Expected: every hidden test passes.

- [ ] **Step 4: Commit the hidden suite only to the controller branch**

```powershell
git add "$experimentRoot/controller/hidden-tests" scripts/benchmark-v2/run-hidden-tests.ps1
git diff --cached --check
git commit -m "test: add hidden complex-workflow benchmark checks"
```

Do not merge or copy these files into any challenge or model branch.

---

### Task 4: Construct and validate SonarQube Challenge v2

**Files:**

- Create: `scripts/benchmark-v2/export-sonar-evidence.ps1`
- Create: `scripts/benchmark-v2/score-sonar-challenge.ps1`
- Create: `Document/experiments/gpt-5.4-vs-gpt-5.5-v2/controller/sonar-mutations.json`
- Create: `Document/experiments/gpt-5.4-vs-gpt-5.5-v2/baseline/sonar/`
- Create source branch: `codex/benchmark-sonar-v2-source`

**Interfaces:**

- Consumes: the clean reference code tree and SonarQube issue/measures APIs
- Produces: one behavior-preserving root commit with a frozen, verified issue manifest

- [ ] **Step 1: Extend Sonar evidence beyond the current summary script**

`export-sonar-evidence.ps1` must export:

- `/api/issues/search` pages until all open issues are captured.
- Rule, component, line, message, type, severity, effort, issue key, and status.
- Direct measures including coverage, duplicated-line density, complexity, NCLOC, bugs, vulnerabilities, and code smells.
- Every quality-gate condition including `ignoredConditions`.
- Scanner version, project key, project version, source SHA, and export time.

Use coverlet output in every Sonar scan rather than relying on an unverified
quality-gate coverage condition.

- [ ] **Step 2: Create candidate mutations only on a temporary controller checkout**

The mutation set must:

- Produce 40–60 verified findings.
- Cover at least 15 Sonar rule families.
- Keep every rule family below 30% of the finding set.
- Span API controllers/middleware, BAL services, MODEL/EF code, and tests.
- Preserve all public and hidden behavior tests.
- Include reliability, maintainability, duplication/complexity, null-safety, resource-handling, and test-quality findings when the installed analyzer verifies them.

Do not count a planned mutation until SonarQube returns a matching issue.

- [ ] **Step 3: Record every verified mutation outside the challenge source**

Each `sonar-mutations.json` entry must contain:

```json
{
  "mutationId": "SQV2-001",
  "rule": "verified Sonar rule key",
  "component": "relative source path",
  "referenceBehavior": "behavior that must remain unchanged",
  "baselineIssueKey": "verified Sonar issue key",
  "baselineLine": 1,
  "baselineMessage": "verified issue message",
  "referenceFileSha256": "clean file hash",
  "challengeFileSha256": "mutated file hash"
}
```

- [ ] **Step 4: Validate the challenge before export**

```powershell
dotnet test .\API\API.sln -c Debug --nologo
dotnet build .\API\API.sln -c Release --nologo
.\scripts\benchmark-v2\run-hidden-tests.ps1 `
  -CandidateRoot $sonarCandidateRoot `
  -RunTag "sonar-baseline" `
  -ResultsDir "$experimentRoot/baseline/sonar/hidden-tests"
```

Expected: public tests, hidden tests, and Release build pass. The exported issue
manifest meets the count and distribution requirements.

- [ ] **Step 5: Export a sanitized root commit**

`export-sanitized-challenge.ps1` must copy only:

- `API/`, `BAL/`, `MODEL/`, and public `tests/`
- Required `.sln`, `.csproj`, configuration, and SQL schema files
- Approved benchmark runner scripts
- Required JMeter plans and public input fixtures

It must exclude:

- `.git/`, `.worktrees/`, reference manifests, controller files, hidden tests
- `Document/outputs/`, previous comparisons, prior fix reports, mutation manifests
- credentials, tokens, logs, raw controller results, and unrelated branches

Initialize the exported directory with `git init`, commit once, and verify:

```powershell
git rev-list --count HEAD
git log --oneline --decorate
```

Expected: exactly one commit. Publish that root commit as
`codex/benchmark-sonar-v2-source`.

- [ ] **Step 6: Freeze baseline Sonar evidence**

Run a fresh scan against the exported source, not the mutation workspace. Confirm
that issue fingerprints match `sonar-mutations.json`, then store raw issues,
measures, coverage, tests, build output, and SHA under `baseline/sonar/`.

---

### Task 5: Construct and validate the workflow-aware ZAP track

**Files:**

- Create: `scripts/benchmark-v2/run-zap-workflows.ps1`
- Create: `Document/experiments/gpt-5.4-vs-gpt-5.5-v2/baseline/zap/endpoint-coverage.json`
- Create: `Document/experiments/gpt-5.4-vs-gpt-5.5-v2/baseline/zap/verified-alerts.json`
- Create source branch: `codex/benchmark-zap-v2-source`

**Interfaces:**

- Consumes: the restored SQL snapshot, authenticated roles, CSV fixtures, and new workflow routes
- Produces: reproducible ZAP reports whose business endpoints were reached with valid state

- [ ] **Step 1: Add workflow setup and valid-state crawling**

`run-zap-workflows.ps1` must:

- Authenticate Admin, FinanceManager, Auditor, and User roles.
- Create fresh periods and deterministic journal data.
- Upload valid and invalid multipart CSV files.
- Capture returned import IDs and commit valid batches.
- Create reconciliations, capture IDs, run auto-match, query exceptions, confirm candidates, and finalize eligible runs.
- Preview and close a dedicated period with a fresh idempotency request.
- Run unauthorized and forbidden probes separately from authorized business probes.
- Export method, normalized route, role, request status, expected status, and response content type.

- [ ] **Step 2: Require endpoint coverage before accepting alerts**

The coverage gate requires:

- Every new route is exercised at least once with an allowed role.
- Every authorization boundary is probed with an unauthorized or forbidden role.
- Dynamic IDs come from setup responses rather than hard-coded guesses.
- Business probes do not consist only of 401, 403, 404, or model-binding failures.

- [ ] **Step 3: Pilot the clean reference and create a controlled source only when needed**

Run the enhanced baseline and authenticated API scans. Classify alerts by alert
ID, risk, confidence, normalized business route, and evidence.

Accept the ZAP challenge when it has:

- At least 8 verified business-endpoint alert instances.
- At least 4 distinct ZAP alert IDs.
- At least 2 verified Medium-or-higher instances.
- No counted alert that exists only on Swagger, health, static files, or a failed authentication request.

If the clean reference does not meet the gate, create controlled runtime-security
mutations on the ZAP candidate only, rerun ZAP, and count only scanner-verified
alerts. Never introduce credential exposure, remote command execution, or a
challenge branch that can be safely deployed.

- [ ] **Step 4: Verify behavior and freeze the source**

Run the full public suite and hidden suite. Export a sanitized one-commit source
as `codex/benchmark-zap-v2-source`, rerun ZAP from the exported source, and save:

- Raw HTML, JSON, and Markdown reports.
- `endpoint-coverage.json`.
- `verified-alerts.json`.
- API logs with secrets removed.
- Source SHA and runner-script checksums.

---

### Task 6: Construct and validate the workflow-aware JMeter track

**Files:**

- Create: `Document/performance/jmeter/v2-period-close.jmx`
- Create: `Document/performance/jmeter/v2-journal-import.jmx`
- Create: `Document/performance/jmeter/v2-reconciliation.jmx`
- Create: `scripts/benchmark-v2/run-jmeter-workflows.ps1`
- Create: `Document/experiments/gpt-5.4-vs-gpt-5.5-v2/baseline/jmeter/`
- Create source branch: `codex/benchmark-jmeter-v2-source`

**Interfaces:**

- Consumes: a freshly restored SQL snapshot and deterministic fixture IDs
- Produces: fixed workflow profiles, raw JTL files, machine metrics, and database postcondition checks

- [ ] **Step 1: Build realistic stateful workflow plans**

The plans must use response extractors and unique variables for:

- Period preview followed by close attempts on dedicated periods.
- Multipart journal validation followed by commit and replay.
- Reconciliation create, auto-match, exception lookup, manual confirmation where required, and finalization.

Every sampler must assert the exact allowed status and required response fields.
Do not count login/setup requests in business latency.

- [ ] **Step 2: Add database correctness checks**

After each profile, verify:

- No unbalanced journal entry was created.
- Atomic invalid imports created no journal entries.
- Import and finalization replay created no duplicate records.
- A journal entry was not assigned to multiple bank transactions.
- Closed periods have the expected audit and ledger state.
- Error rates do not hide assertion or setup failures.

- [ ] **Step 3: Pilot and freeze load without using model output**

Pilot the clean reference and candidate at fixed workflow levels. Freeze the
final levels before either model runs. The challenge is valid when:

- All correctness checks pass.
- Three baseline repetitions have coefficient of variation no greater than 15%
  for each primary p95 and throughput measure.
- At least two workflow profiles show a reproducible bottleneck relative to the
  clean reference without relying on errors or timeouts.
- The bottleneck comes from source behavior, not Docker-to-host networking,
  cold restore, logging saturation, or missing seed data.

Controlled performance mutations may use realistic N+1 lookups, per-row
persistence, or unnecessary in-memory candidate scans, but must preserve API and
accounting behavior.

Pilot exactly 10, 25, and 50 concurrent users with a 60-second ramp and 10
workflow loops. Freeze the highest level where the clean reference has less than
1% business assertion errors and median CPU below 85%; use that same level for
the challenge baseline and both model candidates.

- [ ] **Step 4: Freeze the JMeter source and baseline**

Export `codex/benchmark-jmeter-v2-source` as a one-commit sanitized branch. Restore
the database before each of three repetitions and retain:

- JTL and HTML outputs.
- Median p50, p95, p99, throughput, and error rate by transaction.
- Per-run CPU, memory, and duration.
- Database postcondition results.
- Source SHA, database hash, image IDs, and JMX/script checksums.

---

### Task 7: Freeze identical prompts and create blinded model labs

**Files:**

- Create: `Document/experiments/gpt-5.4-vs-gpt-5.5-v2/prompts/sonar.txt`
- Create: `Document/experiments/gpt-5.4-vs-gpt-5.5-v2/prompts/zap.txt`
- Create: `Document/experiments/gpt-5.4-vs-gpt-5.5-v2/prompts/jmeter.txt`
- Modify: `Document/experiments/gpt-5.4-vs-gpt-5.5-v2/branch-map.json`

**Interfaces:**

- Consumes: three sanitized challenge root commits
- Produces: six isolated model checkouts with pairwise-identical source SHAs

- [ ] **Step 1: Write one prompt per tool**

Every prompt must include:

- Inspect the current tool evidence and affected source before changing code.
- Preserve all API, authorization, accounting, audit, and workload contracts.
- Make only evidence-justified changes.
- Add focused public tests for behavior-changing remediation.
- Do not inspect other directories, branches, remotes, reflogs, stashes, prior reports, or sibling tasks.
- Do not change benchmark infrastructure, scanner rules, exclusions, workloads, or thresholds.
- Do not suppress findings or remove features.
- Record commands, attempts, elapsed time, changed files, and remaining findings.
- Stop after the third attempt.

Only the tool name, evidence paths, and final verification command differ across
the three prompt files. GPT-5.4 and GPT-5.5 receive byte-identical text within a
tool track.

- [ ] **Step 2: Create six no-remote laboratories**

For each tool/model pair:

```powershell
git clone --single-branch --branch $sourceBranch $sourceUrl $labPath
Set-Location $labPath
git remote remove origin
git rev-list --count HEAD
git status --short
```

Expected: one root commit, no remote, clean worktree. Store the six HEAD SHAs in
`branch-map.json`; each tool pair must match exactly.

- [ ] **Step 3: Check for leaked evidence**

```powershell
rg -n -uu `
  "sonar-mutations|hidden-tests|gpt-5.4-vs-gpt-5.5|baseline-sonarqube-v1|baseline-zap-v1|baseline-jmeter-v1|benchmark-v2-reference-code" `
  $labPath
```

Expected: no matches. Also verify `git fsck --no-reflogs --unreachable` exposes
no parent/reference commits.

---

### Task 8: Execute the paired GPT-5.4 and GPT-5.5 remediations

**Files:**

- Create per run: `Document/experiments/gpt-5.4-vs-gpt-5.5-v2/results/<model>/<tool>/interaction.md`
- Modify: only model-authored source and public tests justified by the active tool

**Interfaces:**

- Consumes: the frozen prompt, challenge evidence, and run order
- Produces: six frozen model commits and complete task transcripts

- [ ] **Step 1: Verify model identity before each task**

Record:

- Codex task ID.
- Displayed model label.
- Reasoning setting and service tier.
- Start time, finish time, and attempt count.
- Prompt file SHA-256.
- Challenge source SHA.

If the requested model is not available or the settings cannot be matched, stop
that pair rather than silently substituting a model.

- [ ] **Step 2: Run each pair in the pre-registered order**

For each run:

1. Paste the frozen tool prompt without edits.
2. Provide the same baseline evidence files.
3. Allow the initial remediation.
4. Run controller tool feedback.
5. If findings remain, return only the raw normalized findings for correction.
6. Stop after the second correction or earlier when the model stops.

Do not give either model advice derived from the clean reference or the other
model's patch.

- [ ] **Step 3: Freeze each result immediately**

```powershell
dotnet test .\API\API.sln -c Debug --nologo
git diff --check
git add -A
git commit -m "fix: apply <model> <tool> v2 remediation"
git rev-parse HEAD
git status --short
```

Use the exact branch names from the branch map. Do not amend a frozen result
after controller-only hidden verification begins.

---

### Task 9: Run controller-only verification and compute per-tool results

**Files:**

- Modify: `scripts/benchmark-v2/score-sonar-challenge.ps1`
- Create: `Document/experiments/gpt-5.4-vs-gpt-5.5-v2/results/<model>/<tool>/controller-result.json`
- Create: `Document/experiments/gpt-5.4-vs-gpt-5.5-v2/comparison.json`

**Interfaces:**

- Consumes: six frozen commits, hidden tests, verified baseline evidence, and environment lock
- Produces: reproducible per-tool measurements with validity status

- [ ] **Step 1: Verify source and infrastructure integrity**

For every candidate:

- Confirm its root source SHA matches its paired model.
- Confirm benchmark-script, JMX, ZAP-rule, database, and Docker checksums.
- Detect test deletions, weakened assertions, suppressions, exclusions, and feature removal.
- Mark the run invalid before interpreting tool metrics when an integrity check fails.

- [ ] **Step 2: Run public and hidden behavior gates**

```powershell
dotnet test .\API\API.sln -c Debug --nologo
dotnet build .\API\API.sln -c Release --nologo
.\scripts\benchmark-v2\run-hidden-tests.ps1 `
  -CandidateRoot $candidateRoot `
  -RunTag $candidateTag `
  -ResultsDir "$candidateResultRoot/hidden-tests"
```

Record passed, failed, and skipped counts separately. A tool improvement does
not erase a behavior regression.

- [ ] **Step 3: Score Sonar from exact findings**

Report:

- Verified baseline findings resolved, remaining, and newly introduced.
- Resolution by rule family, layer, type, and severity.
- Public/hidden behavior pass rates.
- Coverage and duplication change.
- Attempts, elapsed time, files changed, insertions, and deletions.

Use the pre-registered Sonar categories:

- 45% exact verified-issue resolution.
- 30% behavior preservation.
- 15% coverage and duplication preservation/improvement.
- 10% attempts, elapsed time, and patch efficiency.

Calculate those components as follows:

- Issue points: `45 * max(0, (resolvedVerified - newIssues) / baselineVerified)`.
- Behavior points: `30 * hiddenPassed / hiddenTotal`; any critical accounting,
  authorization, atomicity, or idempotency failure also marks the run invalid.
- Coverage points: `10 * min(1, candidateCoverage / referenceCoverage)`;
  missing or zero reference coverage invalidates the coverage component.
- Duplication points: 5 when candidate duplication is no worse than the
  reference; otherwise `5 * referenceDuplication / candidateDuplication`. When
  reference duplication is zero and candidate duplication is greater than zero,
  award zero duplication points.
- Attempt points: 4, 2, or 0 for one, two, or three attempts.
- Elapsed-time points: `3 * pairMinimumElapsed / candidateElapsed`.
- Patch-efficiency points:
  `3 * max(1, pairMinimumChangedLines) / max(1, candidateChangedLines)` after
  excluding evidence files and generated artifacts.

The report must also show all raw components; the composite must not conceal a
failed behavior or integrity gate.

- [ ] **Step 4: Verify ZAP three times**

Restore the database before each run and report:

- Verified baseline alert instances resolved, remaining, and newly introduced.
- High, Medium, Low, and Informational counts separately.
- Business endpoint and role coverage.
- Public/hidden security regression results.
- Stability across the three scans.

Do not create a severity-weighted overall number. Compare alert classes and
behavior gates directly.

- [ ] **Step 5: Verify JMeter three times**

Restore the database before every repetition and report:

- Median p50, p95, p99, throughput, and error rate per frozen workflow.
- Interquartile range and coefficient of variation.
- CPU, memory, run duration, and database postconditions.
- Relative change from the identical challenge baseline.

Do not mix setup/login traffic with business transaction latency and do not
select the best repetition.

---

### Task 10: Publish the v2 comparison as new evidence and reports

**Files:**

- Create: `Document/experiments/gpt-5.4-vs-gpt-5.5-v2/comparison.md`
- Create: `Document/outputs/gpt-5.4-vs-gpt-5.5-v2.html`
- Create branch: `codex/gpt-5.4-vs-gpt-5.5-v2`

**Interfaces:**

- Consumes: controller results, model transcripts, raw scans, raw JTL files, commits, and checksums
- Produces: an evidence-backed comparison without modifying prior reports

- [ ] **Step 1: Create an evidence-only comparison branch**

Create it from the controller protocol commit. Restore only result evidence and
interaction records from the six model branches; do not merge remediation source
trees together.

- [ ] **Step 2: Write the Markdown report with these sections**

```markdown
# GPT-5.4 vs GPT-5.5 Complex API Retest

## Research Question
## Pre-Registered Protocol
## Clean Reference and Challenge Provenance
## Environment and Database Identity
## Blinding and Run Order
## SonarQube Challenge v2 Results
## OWASP ZAP Workflow Results
## Apache JMeter Workflow Results
## Behavior and Integrity Gates
## Patch Size, Attempts, and Elapsed Time
## Residual Findings and Failed Gates
## Comparison with Natural Track v1
## Threats to Validity
## Conclusion
```

- [ ] **Step 3: Generate the HTML report as a new file**

The HTML must:

- Read values from `comparison.json`; do not manually duplicate metrics.
- Show branch names and full commit SHAs.
- Link each claim to its raw artifact path.
- Separate valid results from invalid or inconclusive tracks.
- Display per-tool results without asserting an unsupported overall winner.
- Preserve `Document/outputs/gpt-5.4-vs-gpt-5.5.html` unchanged.

- [ ] **Step 4: Run provenance and placeholder checks**

```powershell
rg -n `
  "benchmark-v2-reference-code|benchmark-sonar-v2-source|benchmark-zap-v2-source|benchmark-jmeter-v2-source|gpt-5.4|gpt-5.5" `
  "$experimentRoot/comparison.md" `
  "Document/outputs/gpt-5.4-vs-gpt-5.5-v2.html"

rg -n "TBD|TODO|PLACEHOLDER|captured at execution|resolved at execution" `
  "$experimentRoot" `
  "Document/outputs/gpt-5.4-vs-gpt-5.5-v2.html"

git diff --check
```

Expected: all provenance identifiers are present and no placeholder remains.

- [ ] **Step 5: Commit and push only after user review**

```powershell
git add `
  Document/experiments/gpt-5.4-vs-gpt-5.5-v2 `
  Document/outputs/gpt-5.4-vs-gpt-5.5-v2.html
git diff --cached --check
git commit -m "docs: report GPT-5.4 vs GPT-5.5 complex API retest"
git push -u origin codex/gpt-5.4-vs-gpt-5.5-v2
```

---

## Completion Gates

- [ ] The clean reference code has a verified commit and immutable tag.
- [ ] Sonar, ZAP, and JMeter use independent one-commit challenge sources.
- [ ] Each model pair starts from the same tool-specific root SHA.
- [ ] Model prompts and attempt limits are identical within each pair.
- [ ] Controller-only reference material is absent from all model labs.
- [ ] Sonar has 40–60 verified findings across at least 15 rule families.
- [ ] ZAP verifies new business workflows and meets its alert-diversity gate.
- [ ] JMeter uses fixed stateful workloads, three repetitions, and database correctness checks.
- [ ] Hidden tests are run only by the controller after model results freeze; models may run the public suite.
- [ ] Raw before/after artifacts, transcripts, SHAs, checksums, and interventions are retained.
- [ ] Previous GPT-5.4/GPT-5.5 reports remain unchanged.
- [ ] The v2 report makes no claim that is unsupported by a valid track.
