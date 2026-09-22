# Thesis Reproducibility and Appendix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce a pushed, clean, examiner-runnable GPT-5.4 thesis repository with preserved experiment refs, reproducible application/tool workflows, traceable dashboard evidence, and appendix-ready Markdown/JSON artifacts.

**Architecture:** Preserve the historical baseline and three remediation branches as measurement evidence, while building clean-clone orchestration on a separate canonical integrated branch. Existing `scripts/phase4` files remain the measurement engines; focused `scripts/thesis` wrappers add safety, lifecycle management, manifests, and explicit statuses. Playwright captures SonarQube, ZAP, and JMeter dashboards, and every figure is tied to machine-readable evidence from the same ref and run.

**Tech Stack:** Git worktrees, Windows PowerShell 5.1-compatible scripts, Pester 3.4-compatible tests, .NET SDK 9.0.308, ASP.NET Core, SQL Server/sqlcmd, Docker Desktop, SonarQube, OWASP ZAP, Apache JMeter 5.5, Node.js 22, React/Vite, Playwright.

**Spec:** `docs/superpowers/specs/2026-09-22-thesis-reproducibility-and-appendix-design.md`

## Global Constraints

- Thesis model identity is GPT-5.4. Do not invoke or attribute a different model as thesis remediation evidence.
- Builds, tests, scanners, dashboard capture, and appendix generation are deterministic tooling and require no LLM call.
- Do not edit either thesis DOCX/PDF during this plan.
- Preserve `origin/baseline-v0.1`, `origin/baseline-sonarqube-v1`, `origin/baseline-zap-v1`, and `origin/baseline-jmeter-v1`.
- Never rewrite historical measurements or label a fresh rerun as historical.
- Never print or commit tokens, passwords, authorization headers, full connection strings, or browser profiles.
- Reject non-local database targets unless the operator supplies the explicit opt-in switch.
- Never switch a dirty checkout in place during multi-branch verification.
- Do not use `git reset --hard`, `git clean`, force-push, or broad recursive deletion.
- Remove worktrees only after their commits are recoverable from a verified remote branch or tag.
- Use PowerShell syntax compatible with Windows PowerShell 5.1 and installed Pester 3.4.

## Review Focus

- Dirty or detached checkout: preserve every reachable and uncommitted thesis artifact before cleanup; tests and pre-cleanup manifests must prove recoverability.
- Non-local SQL connection: fail before schema or seed execution unless `-AllowNonLocalDatabase` is supplied; test local, named-instance, and remote-host inputs.
- Missing Docker/Sonar credentials: return `ENVIRONMENT_BLOCKED` or `SKIPPED`, never a false pass; test each missing prerequisite independently.
- Occupied API/frontend/tool port: report the owning PID and refuse to kill an unrelated process; test owned and unowned process cases.
- Dashboard/source mismatch or sensitive text: reject the capture when displayed metrics differ from JSON/JTL/API evidence or redaction patterns match; test both conditions.

---

## File Structure

| Path | Responsibility |
|---|---|
| `scripts/thesis/Thesis.Common.psm1` | Repository-root, provenance, local-target, redaction, status, hashing, and JSON helpers |
| `scripts/thesis/Test-ThesisEnvironment.ps1` | Read-only prerequisite and port audit |
| `scripts/thesis/Initialize-ThesisDatabase.ps1` | Safe schema application and deterministic seed orchestration |
| `scripts/thesis/Invoke-ThesisDemo.ps1` | API/frontend process ownership, readiness, smoke checks, cleanup |
| `scripts/thesis/Invoke-ThesisVerification.ps1` | Fast build/test verification and run-record generation |
| `scripts/thesis/Invoke-ResearchVerification.ps1` | Branch/ref-aware SonarQube, ZAP, and JMeter orchestration |
| `scripts/thesis/New-ThesisAppendix.ps1` | Deterministic Markdown generation from manifests |
| `scripts/thesis/tests/*.Tests.ps1` | Pester tests for every safety and orchestration boundary |
| `WEB/playwright.appendix.config.ts` | Isolated dashboard-capture configuration |
| `WEB/tests/e2e/thesis-dashboard-capture.spec.ts` | SonarQube/ZAP/JMeter screenshot and redaction checks |
| `docs/appendix/thesis-evidence-manifest.json` | Primary claim/ref/artifact registry |
| `docs/appendix/dashboard-capture-manifest.json` | Dashboard source, run, metric, image, and hash registry |
| `docs/appendix/thesis-branch-register.md` | Human-readable branch/tag purpose and status |
| `docs/appendix/thesis-appendix-source-code-and-results.md` | Later DOCX insertion source |
| `docs/appendix/dashboards/**` | Versioned, redacted dashboard/result images |
| `README.md` | Examiner quick start and links to appendix evidence |

### Task 1: Preserve Existing Detached and Dirty Work

**Files:**
- Verify: primary checkout, detached defense worktree, design worktree
- Create: remote branch `codex/final-thesis-defense`
- Create: remote branch `codex/thesis-report-working-20260922`

**Interfaces:**
- Consumes: current worktree states identified in the approved spec
- Produces: remote recovery refs for every currently uncommitted thesis artifact

- [ ] **Step 1: Refresh and record immutable starting state**

Run from the repository root:

```powershell
git fetch --prune origin
git worktree list --porcelain
git status --porcelain=v2 --branch --untracked-files=all
git -C C:\Users\Asus\.codex\worktrees\final-thesis-defense\financial-accounting status --porcelain=v2 --branch --untracked-files=all
git fsck --no-reflogs --unreachable --no-progress
```

Expected: the primary remains dirty; the defense worktree remains detached with 13 modified tracked files; no command changes files.

- [ ] **Step 2: Verify the defense package before checkpointing**

Run in the detached defense worktree:

```powershell
python -m unittest discover -s scripts/defense/tests -p "test_*.py"
python scripts/defense/validate_defense_package.py
git diff --check
```

Expected: tests and package validation pass. If they fail, stop and diagnose; do not checkpoint a claimed-final package.

- [ ] **Step 3: Rescue and push the defense lineage**

```powershell
git switch -c codex/final-thesis-defense
git add -- Document/outputs/final-defense Document/outputs/final-report-gpt55-comparison.docx Document/outputs/final-report-gpt55-comparison.pdf scripts/defense
git diff --cached --check
git commit -m "docs: finalize thesis defense evidence package"
git push -u origin codex/final-thesis-defense
git rev-parse HEAD
git ls-remote --heads origin codex/final-thesis-defense
```

Expected: local HEAD and remote SHA match exactly.

- [ ] **Step 4: Classify the primary checkout files**

Create three explicit lists from `git status --short --untracked-files=all`:

```text
checkpoint: the nine tracked report/script/figure changes, six dataset figures, and three report scripts
exclude-duplicate: Document/outputs/final-defense/**
exclude-current-paper: Document/outputs/camera-ready-manuscript-V2 (1).docx
defer-supplemental: Document/experiments/**
```

Expected: no file is staged yet, and every dirty path belongs to exactly one list.

- [ ] **Step 5: Create a recoverable report-work branch with narrow staging**

```powershell
git switch -c codex/thesis-report-working-20260922
git add -- Document/outputs/final-report-gpt55-comparison.docx Document/outputs/final-report-gpt55-comparison.pdf Document/outputs/final-report.docx Document/outputs/final-report.pdf
git add -- Document/paper/figures/workflow-phase1.png Document/paper/figures/workflow-phase2.png Document/paper/figures/workflow-split-preview.png
git add -- Document/paper/figures/dataset-accounts.png Document/paper/figures/dataset-audit-logs.png Document/paper/figures/dataset-journal-lines.png Document/paper/figures/dataset-periods.png Document/paper/figures/dataset-trial-balance.png Document/paper/figures/dataset-users-roles.png
git add -- scripts/create_gpt55_comparison_deliverables.py scripts/generate-ieee-workflow-panels.py scripts/format_final_report_docx.py scripts/generate-dataset-evidence.py scripts/replace_endpoint_boxes.py
git diff --cached --check
git commit -m "chore: checkpoint thesis report working artifacts"
git push -u origin codex/thesis-report-working-20260922
```

Expected: duplicate defense outputs, the camera-ready copy, and raw experiment directories remain unstaged; remote SHA matches local SHA.

- [ ] **Step 6: Cut the implementation branch from the approved plan lineage**

Run in the design worktree:

```powershell
git switch -c codex/thesis-reproducibility-v1
git status --short --branch
```

Expected: clean working tree on the canonical implementation branch.

### Task 2: Create the Evidence and Branch Registries

**Files:**
- Create: `docs/appendix/thesis-evidence-manifest.json`
- Create: `docs/appendix/dashboard-capture-manifest.json`
- Create: `docs/appendix/thesis-branch-register.md`
- Create: `scripts/thesis/tests/EvidenceManifest.Tests.ps1`

**Interfaces:**
- Consumes: exact refs and result claims from the approved spec
- Produces: JSON arrays `claims` and `captures` consumed by Tasks 8 and 9

- [ ] **Step 1: Write the failing manifest tests**

```powershell
Describe "Thesis evidence manifests" {
    It "pins the four primary evidence refs to 40-character commits" {
        $m = Get-Content "$PSScriptRoot/../../../docs/appendix/thesis-evidence-manifest.json" -Raw | ConvertFrom-Json
        @($m.evidenceRefs).Count | Should Be 4
        @($m.evidenceRefs | Where-Object { $_.commit -notmatch '^[0-9a-f]{40}$' }).Count | Should Be 0
    }
    It "labels the thesis model as GPT-5.4" {
        $m = Get-Content "$PSScriptRoot/../../../docs/appendix/thesis-evidence-manifest.json" -Raw | ConvertFrom-Json
        $m.thesisModel | Should Be "gpt-5.4"
    }
    It "does not classify supplemental experiments as current-paper evidence" {
        $m = Get-Content "$PSScriptRoot/../../../docs/appendix/thesis-evidence-manifest.json" -Raw | ConvertFrom-Json
        @($m.claims | Where-Object { $_.scope -ne 'current-paper' }).Count | Should Be 0
    }
}
```

- [ ] **Step 2: Run the tests and confirm RED**

Run: `powershell -NoProfile -Command "Invoke-Pester -Script scripts/thesis/tests/EvidenceManifest.Tests.ps1"`

Expected: FAIL because the manifest files do not exist.

- [ ] **Step 3: Add exact evidence data**

Use this root shape and exact primary refs:

```json
{
  "schemaVersion": 1,
  "thesisModel": "gpt-5.4",
  "evidenceRefs": [
    {"role":"baseline","ref":"origin/baseline-v0.1","commit":"7a0469d9401a3061941b44fcd46b3beca1c9c729"},
    {"role":"sonarqube-remediation","ref":"origin/baseline-sonarqube-v1","commit":"a2279bcbdc20751529335cf72f8baac1bc6f994b"},
    {"role":"zap-remediation","ref":"origin/baseline-zap-v1","commit":"5f3bd3ccd9e0d460f52cac6a8a0d5fdceff1ce3d"},
    {"role":"jmeter-remediation","ref":"origin/baseline-jmeter-v1","commit":"3c9392d8dcecf986da5438962e20c5d862e8be08","testedCodeCommit":"78b08b62570dcf6fe436354e8e6b770ab2074445"}
  ],
  "claims": []
}
```

Add these six claim records; each record also carries its source paths and historical artifact paths:

```json
[
  {"claimId":"sonarqube-primary","paperLocation":"4.2 / Table 4.2","scope":"current-paper","baselineRole":"baseline","afterRole":"sonarqube-remediation","historicalResult":"28 retained findings to 0; Quality Gate OK; coverage 74.3%; duplication 0.0%"},
  {"claimId":"zap-primary","paperLocation":"4.3","scope":"current-paper","baselineRole":"baseline","afterRole":"zap-remediation","historicalResult":"gated High, Medium, and Low business-endpoint alerts cleared"},
  {"claimId":"jmeter-primary","paperLocation":"4.4 / Table 4.4","scope":"current-paper","baselineRole":"baseline","afterRole":"jmeter-remediation","historicalResult":"p50, p100, and p500 p95 improved; soak/spike improved with drift caveat"},
  {"claimId":"deterministic-data","paperLocation":"3.2 / Tables 3.7-3.8","scope":"current-paper","baselineRole":"baseline","afterRole":"integrated-demo","historicalResult":"120 accounts, 30000 journal entries, at least 5000 posted entries"},
  {"claimId":"automated-regression","paperLocation":"3.1.1 and 3.5","scope":"current-paper","baselineRole":"baseline","afterRole":"integrated-demo","historicalResult":"unit, integration, RBAC, and coverage checks support non-regression"},
  {"claimId":"working-application","paperLocation":"4.6 / Figures 4.1-4.7","scope":"current-paper","baselineRole":null,"afterRole":"integrated-demo","historicalResult":"React/Vite client demonstrates current role-aware API workflows"}
]
```

Set `sourceFiles` and `historicalArtifacts` explicitly for each record: Sonar uses `Document/sonarqube-fixes.md`; ZAP uses the matching versioned `Document/security/*.json` and `.html`; JMeter uses `Document/baseline-comparison-report.md`, `Document/performance/thesis-evidence-20260222-231435.*`, and the JMX plans; data uses `Document/sql/financial_accounting_schema.sql` and `scripts/phase4/seed-test-data.ps1`; automated regression uses both test projects and the TRX/coverage evidence; the working application uses `WEB/**` and `Document/outputs/web-app-evidence/**`. Initialize the dashboard manifest as `{"schemaVersion":1,"captures":[]}`.

- [ ] **Step 4: Run tests and commit**

```powershell
powershell -NoProfile -Command "Invoke-Pester -Script scripts/thesis/tests/EvidenceManifest.Tests.ps1"
git add docs/appendix scripts/thesis/tests/EvidenceManifest.Tests.ps1
git commit -m "docs: register thesis evidence refs"
```

Expected: all manifest tests pass.

### Task 3: Build Shared Safety Helpers and Environment Audit

**Files:**
- Create: `scripts/thesis/Thesis.Common.psm1`
- Create: `scripts/thesis/Test-ThesisEnvironment.ps1`
- Create: `scripts/thesis/tests/Thesis.Common.Tests.ps1`
- Create: `scripts/thesis/tests/Test-ThesisEnvironment.Tests.ps1`

**Interfaces:**
- Produces: `Get-ThesisRepositoryRoot`, `Get-GitProvenance`, `Test-LocalSqlTarget`, `Protect-LogText`, `Get-PortOwner`, `Invoke-ThesisCommand`, `Write-ThesisJson`
- Produces environment object: `{ Status, Git, DotNet, Node, Docker, SqlServer, SqlCmd, Ports, Files, SonarTokenPresent }`

- [ ] **Step 1: Write failing helper tests**

```powershell
Describe "Thesis.Common" {
    It "accepts local SQL targets and rejects remote targets" {
        Test-LocalSqlTarget "Server=localhost;Database=Financial;Trusted_Connection=True" | Should Be $true
        Test-LocalSqlTarget "Server=.\SQLEXPRESS;Database=Financial;Trusted_Connection=True" | Should Be $true
        Test-LocalSqlTarget "Server=db.example.com;Database=Financial;User Id=x;Password=y" | Should Be $false
    }
    It "redacts credential-shaped values" {
        Protect-LogText "Password=secret; sonar.token=abc123" | Should Be "Password=[REDACTED]; sonar.token=[REDACTED]"
    }
}
```

- [ ] **Step 2: Verify RED**

Run: `powershell -NoProfile -Command "Invoke-Pester -Script scripts/thesis/tests/Thesis.Common.Tests.ps1"`

Expected: FAIL because the module does not exist.

- [ ] **Step 3: Implement the minimal helper contracts**

```powershell
function Test-LocalSqlTarget {
    param([Parameter(Mandatory=$true)][string]$ConnectionString)
    $builder = New-Object System.Data.SqlClient.SqlConnectionStringBuilder $ConnectionString
    $server = $builder.DataSource.ToLowerInvariant()
    return $server -eq "." -or $server -eq "localhost" -or $server -eq "(local)" -or
        $server.StartsWith(".\") -or $server.StartsWith("localhost\") -or $server.StartsWith("(localdb)\")
}

function Protect-LogText {
    param([string]$Text)
    $Text = [regex]::Replace($Text, '(?i)(Password\s*=\s*)[^;\s]+', '$1[REDACTED]')
    return [regex]::Replace($Text, '(?i)(sonar\.token\s*=\s*)[^;\s]+', '$1[REDACTED]')
}
```

Export only the declared functions.

- [ ] **Step 4: Write the failing environment tests**

Test that missing Docker produces `ENVIRONMENT_BLOCKED` only for Full mode, that a missing Sonar token is `SKIPPED`, that required files are enumerated, and that an occupied unowned port returns the owning PID without stopping it.

- [ ] **Step 5: Implement and verify the environment audit**

The script accepts `-Mode Fast|Demo|Full` and `-OutputPath`; it performs read-only checks and emits JSON through `Write-ThesisJson`.

```powershell
$requiredFiles = @('API/API.csproj','WEB/package.json','Document/sql/financial_accounting_schema.sql')
$status = if ($Mode -eq 'Full' -and -not $docker.ServerAvailable) { 'ENVIRONMENT_BLOCKED' } else { 'PASS' }
```

Run both test files and then:

```powershell
& scripts/thesis/Test-ThesisEnvironment.ps1 -Mode Fast -OutputPath docs/appendix/verification-runs/environment-fast.json
```

- [ ] **Step 6: Commit**

```powershell
git add scripts/thesis docs/appendix/verification-runs/environment-fast.json
git commit -m "feat: add thesis environment audit"
```

### Task 4: Add Safe Database Initialization

**Files:**
- Create: `scripts/thesis/Initialize-ThesisDatabase.ps1`
- Create: `scripts/thesis/tests/Initialize-ThesisDatabase.Tests.ps1`

**Interfaces:**
- Consumes: `Test-LocalSqlTarget`, `Document/sql/financial_accounting_schema.sql`, `scripts/phase4/seed-test-data.ps1`
- Produces: `{ Status, Server, Database, SchemaApplied, SeedSummary, RunId }`

- [ ] **Step 1: Write failing safety tests**

```powershell
Describe "Initialize-ThesisDatabase" {
    It "rejects a remote SQL target before invoking sqlcmd" {
        { & $script -ConnectionString "Server=prod.example.com;Database=Financial;User Id=x;Password=y" -WhatIf } | Should Throw
        Assert-MockCalled sqlcmd 0
    }
    It "allows a remote target only with the explicit opt-in" {
        { & $script -ConnectionString "Server=prod.example.com;Database=Financial;User Id=x;Password=y" -AllowNonLocalDatabase -WhatIf } | Should Not Throw
    }
}
```

- [ ] **Step 2: Verify RED**

Run the Pester file; expect missing-script failures.

- [ ] **Step 3: Implement schema and seed orchestration**

Use `SupportsShouldProcess`, validate the target before `sqlcmd`, invoke the checked-in schema, then call the existing seed script. Never echo the connection string.

```powershell
[CmdletBinding(SupportsShouldProcess=$true)]
param([string]$ConnectionString, [switch]$AllowNonLocalDatabase, [switch]$SkipSeed)
if (-not (Test-LocalSqlTarget $ConnectionString) -and -not $AllowNonLocalDatabase) {
    throw "Refusing non-local SQL target without -AllowNonLocalDatabase."
}
```

- [ ] **Step 4: Run unit tests, dry-run, and local smoke**

```powershell
Invoke-Pester -Script scripts/thesis/tests/Initialize-ThesisDatabase.Tests.ps1
& scripts/thesis/Initialize-ThesisDatabase.ps1 -WhatIf
& scripts/thesis/Initialize-ThesisDatabase.ps1
```

Expected: local schema/seed succeeds and reports 120 accounts, 30,000 journal entries, at least 5,000 posted entries, and the four demo roles/users without printing passwords.

- [ ] **Step 5: Commit**

```powershell
git add scripts/thesis/Initialize-ThesisDatabase.ps1 scripts/thesis/tests/Initialize-ThesisDatabase.Tests.ps1
git commit -m "feat: add safe thesis database setup"
```

### Task 5: Add the Integrated Demo Lifecycle Runner

**Files:**
- Create: `scripts/thesis/Invoke-ThesisDemo.ps1`
- Create: `scripts/thesis/tests/Invoke-ThesisDemo.Tests.ps1`

**Interfaces:**
- Consumes: environment audit and database initializer
- Produces: `{ Status, ApiPid, WebPid, ApiUrl, WebUrl, Health, Smoke, OwnedPids }`

- [ ] **Step 1: Write failing lifecycle tests**

Add five named tests: `rejects occupied unowned port`, `stops owned children after failure`, `never stops unrelated PID`, `returns FAIL on readiness timeout`, and `returns owned PIDs with KeepRunning`.

```powershell
It "does not stop an unrelated port owner" {
    Mock Get-PortOwner { [pscustomobject]@{ Port=5296; Pid=777; Owned=$false } }
    Mock Stop-Process {}
    { & $script -SkipDatabase -WhatIf } | Should Throw
    Assert-MockCalled Stop-Process 0
}
It "stops only owned children after readiness failure" {
    Mock Start-Process { [pscustomobject]@{ Id=901 } }
    Mock Wait-ThesisUrl { $false }
    Mock Stop-Process {}
    $result = & $script -SkipDatabase
    $result.Status | Should Be "FAIL"
    Assert-MockCalled Stop-Process 1 -ParameterFilter { $Id -eq 901 }
}
It "returns owned PIDs when KeepRunning is selected" {
    Mock Start-Process { [pscustomobject]@{ Id=902 } }
    Mock Wait-ThesisUrl { $true }
    $result = & $script -SkipDatabase -KeepRunning
    @($result.OwnedPids) | Should Contain 902
}
```

- [ ] **Step 2: Verify RED**

Run the Pester file; expect missing-script failures.

- [ ] **Step 3: Implement API/frontend lifecycle**

Start processes with explicit working directories and redirected logs, poll `/health/live`, `/health/ready`, and the Vite root, and track only returned process IDs.

```powershell
$api = Start-Process dotnet -ArgumentList @('run','--project','API/API.csproj','--urls',$ApiUrl,'--environment','Development') -PassThru -WindowStyle Hidden
$ownedPids.Add($api.Id)
```

Use `try/finally` to stop owned children unless `-KeepRunning` is set.

- [ ] **Step 4: Run tests and a live demo smoke**

```powershell
Invoke-Pester -Script scripts/thesis/tests/Invoke-ThesisDemo.Tests.ps1
& scripts/thesis/Invoke-ThesisDemo.ps1 -KeepRunning -OutputPath docs/appendix/verification-runs/demo-live.json
```

Verify both health endpoints and `http://localhost:5173`, then stop only the reported owned PIDs.

- [ ] **Step 5: Commit**

```powershell
git add scripts/thesis/Invoke-ThesisDemo.ps1 scripts/thesis/tests/Invoke-ThesisDemo.Tests.ps1 docs/appendix/verification-runs/demo-live.json
git commit -m "feat: add examiner demo runner"
```

### Task 6: Add Fast Verification and Run Records

**Files:**
- Create: `scripts/thesis/Invoke-ThesisVerification.ps1`
- Create: `scripts/thesis/tests/Invoke-ThesisVerification.Tests.ps1`
- Modify: `README.md`

**Interfaces:**
- Consumes: common helpers, environment audit
- Produces: timestamped JSON/Markdown with command, exit code, duration, ref, commit, and status

- [ ] **Step 1: Write failing status-classification tests**

```powershell
It "fails when a required command exits non-zero" {
    Mock Invoke-ThesisCommand { [pscustomobject]@{ ExitCode=1; DurationMs=10 } }
    $result = & $script -Mode Fast -OutputDirectory $TestDrive
    $result.Status | Should Be "FAIL"
}
It "records but does not fail an explicitly optional browser check" {
    # browser result must be SKIPPED while required build/test steps remain PASS
}
```

- [ ] **Step 2: Verify RED**

Run the Pester file and confirm missing implementation failures.

- [ ] **Step 3: Implement the exact fast command list**

```powershell
$commands = @(
    @{ Name='dotnet-build'; Required=$true; File='dotnet'; Args=@('build','API/API.sln','-c','Release','--nologo') },
    @{ Name='dotnet-unit'; Required=$true; File='dotnet'; Args=@('test','tests/FinancialAccounting.UnitTests/FinancialAccounting.UnitTests.csproj','-c','Release','--nologo') },
    @{ Name='dotnet-integration'; Required=$true; File='dotnet'; Args=@('test','tests/FinancialAccounting.IntegrationTests/FinancialAccounting.IntegrationTests.csproj','-c','Release','--nologo') },
    @{ Name='web-install'; Required=$true; File='npm'; Args=@('ci','--prefix','WEB') },
    @{ Name='web-test'; Required=$true; File='npm'; Args=@('test','--prefix','WEB') },
    @{ Name='web-build'; Required=$true; File='npm'; Args=@('run','build','--prefix','WEB') }
)
```

- [ ] **Step 4: Run tests and fresh fast verification**

```powershell
Invoke-Pester -Script scripts/thesis/tests/Invoke-ThesisVerification.Tests.ps1
& scripts/thesis/Invoke-ThesisVerification.ps1 -Mode Fast -OutputDirectory docs/appendix/verification-runs
```

Expected: all required commands pass; no claim about Docker-based tools is made.

- [ ] **Step 5: Add README quick start and commit**

Document environment audit, database init, demo runner, Fast/Full distinction, appendix path, GPT-5.4 identity, and secret handling.

```powershell
git add README.md scripts/thesis/Invoke-ThesisVerification.ps1 scripts/thesis/tests/Invoke-ThesisVerification.Tests.ps1 docs/appendix/verification-runs
git commit -m "feat: add reproducible fast verification"
```

### Task 7: Add Full Research-Tool Orchestration

**Files:**
- Create: `scripts/thesis/Invoke-ResearchVerification.ps1`
- Create: `scripts/thesis/tests/Invoke-ResearchVerification.Tests.ps1`
- Modify: `scripts/phase4/run-thesis-suite.ps1`

**Interfaces:**
- Consumes: evidence ref role, `-WorkingDirectory`, phase-4 tool scripts from that worktree, running API, secure Sonar token
- Produces: result object with `Sonar`, `ZapBaseline`, `ZapApi`, `JMeter`, `Status`, and artifact paths

- [ ] **Step 1: Write failing orchestration tests**

Cover exact-ref mismatch, distinct Sonar project keys, missing Docker, missing Sonar token, phase-4 failure propagation, and historical/fresh classification.

```powershell
It "uses different Sonar project keys for baseline and remediation" {
    (Get-SonarProjectKey -Role baseline) | Should Be "financial-accounting-thesis-baseline-v01"
    (Get-SonarProjectKey -Role sonarqube-remediation) | Should Be "financial-accounting-thesis-sonarqube-v1"
}
```

- [ ] **Step 2: Verify RED**

Run the Pester file and confirm missing-function failures.

- [ ] **Step 3: Implement branch/ref guard and tool calls**

```powershell
$actualCommit = (git -C $WorkingDirectory rev-parse HEAD).Trim()
if ($actualCommit -ne $ExpectedCommit) { throw "Expected $ExpectedCommit but found $actualCommit." }
if (-not $env:SONAR_TOKEN) { $sonarStatus = 'SKIPPED' }
```

Resolve all phase-4 script paths under `-WorkingDirectory`. Call that worktree's `run-sonarqube-scan.ps1` and `get-sonar-summary.ps1` with the role-specific key; call its ZAP scripts with timestamped output prefixes; call its `run-jmeter-thesis-matrix.ps1` with a run tag containing role and commit prefix. Modify canonical `run-thesis-suite.ps1` only to accept/pass an explicit Sonar project key and evidence classification; do not duplicate scanner logic.

- [ ] **Step 4: Run unit tests and dry-run each role**

```powershell
Invoke-Pester -Script scripts/thesis/tests/Invoke-ResearchVerification.Tests.ps1
& scripts/thesis/Invoke-ResearchVerification.ps1 -Role baseline -WorkingDirectory .worktrees/verify-baseline -ExpectedCommit 7a0469d9401a3061941b44fcd46b3beca1c9c729 -DryRun
& scripts/thesis/Invoke-ResearchVerification.ps1 -Role sonarqube-remediation -WorkingDirectory .worktrees/verify-sonar -ExpectedCommit a2279bcbdc20751529335cf72f8baac1bc6f994b -DryRun
```

- [ ] **Step 5: Commit**

```powershell
git add scripts/thesis/Invoke-ResearchVerification.ps1 scripts/thesis/tests/Invoke-ResearchVerification.Tests.ps1 scripts/phase4/run-thesis-suite.ps1
git commit -m "feat: orchestrate thesis research verification"
```

### Task 8: Capture and Validate Tool Dashboards

**Files:**
- Create: `WEB/playwright.appendix.config.ts`
- Create: `WEB/tests/e2e/thesis-dashboard-capture.spec.ts`
- Modify: `WEB/package.json`
- Create: `scripts/thesis/tests/DashboardManifest.Tests.ps1`
- Modify: `docs/appendix/dashboard-capture-manifest.json`

**Interfaces:**
- Consumes: `THESIS_DASHBOARD_CASES`, optional Sonar credentials, completed HTML/API artifacts
- Produces: PNG captures and manifest fields required by the spec

- [ ] **Step 1: Write failing manifest and Playwright tests**

The Pester file always validates manifest schema. When `THESIS_REQUIRE_COMPLETE_DASHBOARDS=1`, it additionally requires all 18 stable filenames, 40-character commits, source artifacts, SHA-256 hashes, dimensions, and evidence classifications. This lets capture-tooling tests pass before the expensive scans while making the final evidence gate strict. The Playwright test rejects page text matching `Password=`, `sonar.token=`, `Authorization: Bearer`, or local user-profile paths.

```typescript
const forbidden = [/Password\s*=/i, /sonar\.token\s*=/i, /Authorization:\s*Bearer/i, /C:\\Users\\[^\\]+/i];
for (const pattern of forbidden) expect(await page.locator('body').innerText()).not.toMatch(pattern);
```

- [ ] **Step 2: Verify RED**

```powershell
Invoke-Pester -Script scripts/thesis/tests/DashboardManifest.Tests.ps1
npm ci --prefix WEB
npm run capture:appendix --prefix WEB
```

Expected: schema test initially fails because the manifest contract is not implemented; capture command fails or skips because cases are not supplied.

- [ ] **Step 3: Implement isolated capture configuration**

Add package script:

```json
"capture:appendix": "playwright test tests/e2e/thesis-dashboard-capture.spec.ts --config playwright.appendix.config.ts"
```

The test reads a JSON case array, opens each `sourceUrl`, waits for `readySelector`, writes a full-page PNG to `outputPath`, records dimensions/hash/source metadata, and never writes credentials.

- [ ] **Step 4: Validate metric/source agreement**

For each capture, parse the corresponding Sonar API JSON, ZAP JSON, or JMeter statistics JSON and compare declared metrics before appending the manifest entry. A mismatch throws with the tool/view name and both values.

- [ ] **Step 5: Capture ZAP historical reports and prepare live cases**

Render versioned ZAP HTML reports as `rendered-historical`. Define live Sonar and JMeter cases only after their scans/runs complete. Captures must use the filenames specified in the design.

- [ ] **Step 6: Run tests and commit capture tooling**

```powershell
Invoke-Pester -Script scripts/thesis/tests/DashboardManifest.Tests.ps1
npm test --prefix WEB
npm run build --prefix WEB
git add WEB/package.json WEB/package-lock.json WEB/playwright.appendix.config.ts WEB/tests/e2e/thesis-dashboard-capture.spec.ts scripts/thesis/tests/DashboardManifest.Tests.ps1 docs/appendix
git commit -m "feat: capture thesis tool dashboards"
```

### Task 9: Generate the Appendix Source

**Files:**
- Create: `scripts/thesis/New-ThesisAppendix.ps1`
- Create: `scripts/thesis/tests/New-ThesisAppendix.Tests.ps1`
- Create: `docs/appendix/thesis-appendix-source-code-and-results.md`

**Interfaces:**
- Consumes: evidence manifest, dashboard manifest, verification run records
- Produces: deterministic Appendix A-H Markdown defined by the spec

- [ ] **Step 1: Write failing appendix tests**

```powershell
It "renders all three tool dashboard sections" {
    & $script -EvidenceManifest $evidence -DashboardManifest $dashboards -OutputPath $output
    $text = Get-Content $output -Raw
    $text | Should Match "SonarQube Dashboards"
    $text | Should Match "OWASP ZAP Dashboards"
    $text | Should Match "Apache JMeter Dashboards"
}
It "keeps historical and fresh results in separately labeled columns" {
    (Get-Content $output -Raw) | Should Match "Historical result.*Fresh reproduction result"
}
```

- [ ] **Step 2: Verify RED**

Run the Pester file; expect missing-script failures.

- [ ] **Step 3: Implement deterministic rendering**

Render repository/environment, provenance, source evidence, commands, result traceability, dashboards, working application, and limitations. Use repository-relative Markdown links and captions containing role, commit prefix, run ID, and evidence classification.

- [ ] **Step 4: Generate, lint, and commit**

```powershell
& scripts/thesis/New-ThesisAppendix.ps1
Invoke-Pester -Script scripts/thesis/tests/New-ThesisAppendix.Tests.ps1
git diff --check
git add scripts/thesis/New-ThesisAppendix.ps1 scripts/thesis/tests/New-ThesisAppendix.Tests.ps1 docs/appendix/thesis-appendix-source-code-and-results.md
git commit -m "docs: generate thesis reproducibility appendix"
```

### Task 10: Execute Branch-Isolated Verification and Capture Results

**Files:**
- Create/update: `docs/appendix/verification-runs/**`
- Create/update: `docs/appendix/dashboards/**`
- Modify: evidence and dashboard manifests

**Interfaces:**
- Consumes: Tasks 2-9 and exact evidence refs
- Produces: fresh, labeled verification evidence for every primary thesis branch

- [ ] **Step 1: Create clean evidence worktrees**

```powershell
git worktree add .worktrees/verify-baseline --detach 7a0469d9401a3061941b44fcd46b3beca1c9c729
git worktree add .worktrees/verify-sonar --detach a2279bcbdc20751529335cf72f8baac1bc6f994b
git worktree add .worktrees/verify-zap --detach 5f3bd3ccd9e0d460f52cac6a8a0d5fdceff1ce3d
git worktree add .worktrees/verify-jmeter --detach 78b08b62570dcf6fe436354e8e6b770ab2074445
```

Verify every worktree is clean and its HEAD equals the requested commit.

- [ ] **Step 2: Run focused build/tests on all four refs**

Run Release build plus available unit/integration tests in each worktree. Record exact counts and failures separately; do not let one branch's result overwrite another's run record.

- [ ] **Step 3: Start Docker and verify tool versions**

Start Docker Desktop if needed, run the phase-4 installer, and record exact SonarQube, ZAP image, and JMeter image versions. If Docker remains unavailable, mark Full runs `ENVIRONMENT_BLOCKED` and stop before claiming dashboard completion.

- [ ] **Step 4: Run SonarQube baseline and remediation scans**

Use separate project keys and a securely supplied `SONAR_TOKEN`. Capture overview and Issues views only after the Compute Engine task succeeds and API summaries match displayed metrics.

- [ ] **Step 5: Run ZAP baseline/API before and after**

Use the baseline worktree for before results and the ZAP remediation worktree for after results. Preserve HTML, JSON, Markdown, tool version, branch, commit, and run ID. Capture the four required summary views and alert breakdown.

- [ ] **Step 6: Run all ten JMeter dashboards**

Run p50, p100, p500, soak, and spike on the baseline ref and again on the JMeter remediation ref using the same seed parameters. Preserve JTL/statistics sources and capture all baseline/remediation overview dashboards.

- [ ] **Step 7: Rebuild manifests and appendix**

```powershell
npm run capture:appendix --prefix WEB
& scripts/thesis/New-ThesisAppendix.ps1
$env:THESIS_REQUIRE_COMPLETE_DASHBOARDS='1'
Invoke-Pester -Script scripts/thesis/tests
Remove-Item Env:THESIS_REQUIRE_COMPLETE_DASHBOARDS
git diff --check
```

Expected: each required dashboard has a source artifact, full commit, run ID, version, dimensions, hash, and correct classification.

- [ ] **Step 8: Commit fresh evidence**

Stage only appendix-selected images, manifests, compact run records, and necessary machine-readable summaries. Do not stage complete transient container data, browser profiles, credentials, or unbounded HTML directories.

```powershell
git add docs/appendix
git commit -m "test: record thesis reproduction evidence"
```

### Task 11: Final Review, Tagging, Push, and Cleanup

**Files:**
- Modify: `docs/appendix/thesis-branch-register.md`
- Modify: `README.md`

**Interfaces:**
- Consumes: completed canonical branch and verification evidence
- Produces: pushed canonical branch, verified evidence tags, safe local cleanup record

- [ ] **Step 1: Run final focused verification**

```powershell
Invoke-Pester -Script scripts/thesis/tests
& scripts/thesis/Invoke-ThesisVerification.ps1 -Mode Fast -OutputDirectory docs/appendix/verification-runs
npm test --prefix WEB
npm run build --prefix WEB
dotnet build API/API.sln -c Release --nologo
git diff --check
git status --short --branch
```

Expected: all required checks pass and only intentionally regenerated run records differ.

- [ ] **Step 2: Perform source and secret review**

Search staged text for token/password/connection-string patterns, verify screenshot redaction, and confirm the appendix labels every image `historical`, `rendered-historical`, or `fresh-reproduction`.

- [ ] **Step 3: Create annotated evidence tags**

```powershell
git tag -a thesis-evidence/baseline-v0.1 7a0469d9401a3061941b44fcd46b3beca1c9c729 -m "GPT-5.4 thesis common pre-fix baseline"
git tag -a thesis-evidence/sonarqube-v1 a2279bcbdc20751529335cf72f8baac1bc6f994b -m "GPT-5.4 thesis SonarQube remediation evidence"
git tag -a thesis-evidence/zap-v1 5f3bd3ccd9e0d460f52cac6a8a0d5fdceff1ce3d -m "GPT-5.4 thesis OWASP ZAP remediation evidence"
git tag -a thesis-evidence/jmeter-v1 3c9392d8dcecf986da5438962e20c5d862e8be08 -m "GPT-5.4 thesis JMeter remediation evidence"
```

Before creating each tag, verify it does not already exist or already points to the same object.

- [ ] **Step 4: Push and verify remote identities**

```powershell
git push -u origin codex/thesis-reproducibility-v1
git push origin thesis-evidence/baseline-v0.1 thesis-evidence/sonarqube-v1 thesis-evidence/zap-v1 thesis-evidence/jmeter-v1
git ls-remote --heads origin codex/thesis-reproducibility-v1 codex/final-thesis-defense codex/thesis-report-working-20260922
git ls-remote origin "refs/tags/thesis-evidence/*^{}"
```

Record local/remote branch SHA equality and compare evidence commits to dereferenced annotated-tag lines ending in `^{}` in the branch register.

- [ ] **Step 5: Remove only clean verification worktrees**

For each `.worktrees/verify-*` path: resolve its absolute path, prove it lies under this repository's `.worktrees` directory, prove `git status --porcelain` is empty, then run `git worktree remove <exact-path>`. Keep all evidence branches and tags.

- [ ] **Step 6: Final repository audit and commit**

Update the branch register with retained refs, removed worktrees, remote SHAs, and remaining intentionally untracked supplemental artifacts.

```powershell
git add README.md docs/appendix/thesis-branch-register.md
git commit -m "docs: finalize thesis reproducibility handoff"
git push
git status --short --branch
git worktree list --porcelain
```

Expected: canonical branch is clean and synchronized; primary evidence refs remain remotely accessible; no dirty or detached thesis work exists without a recorded recovery branch.
