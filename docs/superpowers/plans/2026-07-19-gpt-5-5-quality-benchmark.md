# GPT-5.5 Quality Benchmark Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Measure GPT-5.5 on the same pre-fix financial-accounting source used for GPT-5.4, apply its SonarQube, OWASP ZAP, and Apache JMeter remediations on isolated branches, retest them, and publish a controlled GPT-5.4-versus-GPT-5.5 report.

**Architecture:** Run the experiment from a blinded single-branch clone of commit `7a0469d9401a3061941b44fcd46b3beca1c9c729`, which is the common pre-fix parent of the three GPT-5.4 remediation branches. Capture one common baseline, branch independently for each tool, freeze the GPT-5.5 branches before exposing the model or experiment workspace to GPT-5.4 fixes, then rerun the GPT-5.4 fix commits under the same environment for a fair comparison.

**Tech Stack:** GPT-5.5 in Codex, Git/GitHub, PowerShell, ASP.NET Core 8, SQL Server, SonarQube Community, OWASP ZAP, Apache JMeter 5.5, Docker Desktop.

## Global Constraints

- Pre-fix source is immutable: `7a0469d9401a3061941b44fcd46b3beca1c9c729`.
- The GPT-5.5 model must not inspect `baseline-sonarqube-v1`, `baseline-zap-v1`, `baseline-jmeter-v1`, `baseline-v0.2`, their commits, or their reports until all GPT-5.5 fix branches are frozen and pushed.
- Use exactly one initial remediation attempt plus at most two finding-driven correction attempts per tool.
- Human work is limited to environment setup, running commands, supplying tool output, rejecting unsafe changes, and recording evidence. Human-authored remediation code invalidates that tool’s model comparison.
- Each tool gets an independent branch from the same committed baseline evidence state.
- Restore the same SQL Server backup before every JMeter or ZAP measurement.
- Do not pull mutable Docker tags between baseline, GPT-5.5 after-runs, and normalized GPT-5.4 reruns.
- Record image IDs and repository digests; an image mismatch blocks comparison.
- A failed gate is a result. Do not continue changing code after the third model attempt merely to obtain a passing report.
- Keep raw outputs, prompt transcripts, commit SHAs, timings, and human interventions.
- The primary comparison uses freshly rerun GPT-5.4 and GPT-5.5 outputs from the same environment. Historical March 2026 figures are contextual only.

---

## File and Branch Map

### Branches

- `codex/gpt-5.5-baseline`: immutable source plus baseline evidence.
- `codex/gpt-5.5-sonarqube-v1`: GPT-5.5 SonarQube remediation and after evidence.
- `codex/gpt-5.5-zap-v1`: GPT-5.5 ZAP remediation and after evidence.
- `codex/gpt-5.5-jmeter-v1`: GPT-5.5 JMeter remediation and after evidence.
- `codex/gpt-5.5-comparison`: evidence-only aggregation and GPT-5.4-versus-GPT-5.5 report.

### Experiment files

- Create: `Document/experiments/gpt-5.5/manifest.md`
- Create: `Document/experiments/gpt-5.5/environment.json`
- Create: `Document/experiments/gpt-5.5/baseline/sonarqube-summary.json`
- Create: `Document/experiments/gpt-5.5/baseline/security/`
- Create: `Document/experiments/gpt-5.5/baseline/performance/`
- Create: `Document/experiments/gpt-5.5/interactions/sonarqube.md`
- Create: `Document/experiments/gpt-5.5/interactions/zap.md`
- Create: `Document/experiments/gpt-5.5/interactions/jmeter.md`
- Create: `Document/experiments/gpt-5.5/after/sonarqube/`
- Create: `Document/experiments/gpt-5.5/after/zap/`
- Create: `Document/experiments/gpt-5.5/after/jmeter/`
- Create: `Document/experiments/gpt-5.5/gpt-5.4-normalized/`
- Create: `Document/experiments/gpt-5.5/gpt-5.4-vs-gpt-5.5.md`

### Existing harness used unchanged

- `scripts/phase4/install-tools.ps1`
- `scripts/phase4/setup-sonarqube.ps1`
- `scripts/phase4/run-sonarqube-scan.ps1`
- `scripts/phase4/get-sonar-summary.ps1`
- `scripts/phase4/run-zap-baseline.ps1`
- `scripts/phase4/run-zap-api.ps1`
- `scripts/phase4/run-jmeter-thesis-matrix.ps1`
- `scripts/phase4/seed-test-data.ps1`
- `Document/performance/jmeter/financial-api-load-test.jmx`
- `Document/performance/jmeter/financial-api-soak-test.jmx`
- `Document/performance/jmeter/financial-api-spike-test.jmx`

---

### Task 1: Create a blinded GPT-5.5 experiment repository

**Files:**

- Create locally: `.worktrees/gpt-5.5-lab/`
- Verify: repository HEAD and refs

**Interfaces:**

- Consumes: remote branch `origin/baseline-v0.1`
- Produces: isolated branch `codex/gpt-5.5-baseline` at the exact pre-fix SHA

- [ ] **Step 1: Clone only the pre-fix branch**

Run from the main repository:

```powershell
$repoRoot = (git rev-parse --show-toplevel).Trim()
$labPath = Join-Path $repoRoot ".worktrees\gpt-5.5-lab"
git clone --no-local --single-branch --branch baseline-v0.1 `
  https://github.com/minatozaki98/financial-accounting.git $labPath
Set-Location $labPath
```

Expected: only `baseline-v0.1` and its ancestors are fetched.

- [ ] **Step 2: Verify and pin the starting commit**

```powershell
$expectedBase = "7a0469d9401a3061941b44fcd46b3beca1c9c729"
$actualBase = (git rev-parse HEAD).Trim()
if ($actualBase -ne $expectedBase) {
    throw "Wrong experiment base. Expected $expectedBase, got $actualBase"
}
git branch -m codex/gpt-5.5-baseline
git remote remove origin
git show-ref
```

Expected: `HEAD` is `7a0469d...`; no remote remains; no GPT-5.4 fix branch is present.

- [ ] **Step 3: Confirm the worktree is clean**

```powershell
git status --short
git fsck --no-reflogs --unreachable
```

Expected: no worktree changes. Unreachable child fix commits must not be present.

---

### Task 2: Freeze the test environment and database

**Files:**

- Create: `Document/experiments/gpt-5.5/environment.json`
- Create: `Document/experiments/gpt-5.5/manifest.md`

**Interfaces:**

- Consumes: local Docker, .NET, SQL Server, and pre-fix repository
- Produces: immutable environment identifiers and a restorable database baseline

- [ ] **Step 1: Install/start the exact repository toolchain once**

```powershell
./scripts/phase4/install-tools.ps1
docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"
```

Expected: SonarQube, ZAP, and JMeter images exist locally. Do not run this installation command again during the experiment.

- [ ] **Step 2: Capture tool, OS, and source identifiers**

```powershell
$experimentRoot = "Document/experiments/gpt-5.5"
New-Item -ItemType Directory -Force -Path $experimentRoot | Out-Null
$environment = [ordered]@{
    capturedAtUtc = (Get-Date).ToUniversalTime().ToString("o")
    modelLabel = "GPT-5.5"
    baseCommit = (git rev-parse HEAD).Trim()
    dotnet = (& dotnet --version).Trim()
    os = (Get-CimInstance Win32_OperatingSystem | Select-Object Caption, Version, OSArchitecture)
    cpu = (Get-CimInstance Win32_Processor | Select-Object Name, NumberOfCores, NumberOfLogicalProcessors)
    memoryBytes = (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory
    dockerVersion = (& docker version --format "{{.Server.Version}}").Trim()
    sonarImage = (& docker image inspect sonarqube:community --format "{{.Id}}|{{join .RepoDigests \",\"}}").Trim()
    zapImage = (& docker image inspect ghcr.io/zaproxy/zaproxy:stable --format "{{.Id}}|{{join .RepoDigests \",\"}}").Trim()
    jmeterImage = (& docker image inspect justb4/jmeter:5.5 --format "{{.Id}}|{{join .RepoDigests \",\"}}").Trim()
}
$environment | ConvertTo-Json -Depth 8 | Set-Content "$experimentRoot/environment.json" -Encoding UTF8
```

Expected: all image fields contain an image ID; no field is blank.

- [ ] **Step 3: Start the API and create deterministic seed data**

```powershell
$apiLog = Join-Path (Resolve-Path $experimentRoot) "baseline-api.log"
$apiErr = Join-Path (Resolve-Path $experimentRoot) "baseline-api.err.log"
$api = Start-Process dotnet `
  -ArgumentList @("run","--project","API/API.csproj","--urls","http://0.0.0.0:5296","--environment","Development") `
  -RedirectStandardOutput $apiLog `
  -RedirectStandardError $apiErr `
  -WindowStyle Hidden `
  -PassThru

$ready = $false
for ($attempt = 1; $attempt -le 60; $attempt++) {
    try {
        $response = Invoke-WebRequest "http://localhost:5296/health/ready" -UseBasicParsing -TimeoutSec 2
        if ($response.StatusCode -eq 200) { $ready = $true; break }
    } catch {}
    Start-Sleep -Seconds 2
}
if (-not $ready) { throw "API did not become ready. See $apiErr" }

./scripts/phase4/seed-test-data.ps1 `
  -AdminUsername "admin" `
  -AdminPassword "Admin@123" `
  -PeriodId 202601 `
  -AccountCount 120 `
  -JournalEntryCount 30000 `
  -MinimumPostedEntries 5000
Stop-Process -Id $api.Id
```

Expected: 120 or more accounts, 30,000 or more journal entries, and at least 5,000 posted entries are reported.

- [ ] **Step 4: Back up the seeded database**

```powershell
$backupDir = (& sqlcmd -S localhost -E -h -1 -W -Q `
  "SET NOCOUNT ON; SELECT CAST(SERVERPROPERTY('InstanceDefaultBackupPath') AS nvarchar(4000));").Trim()
if ([string]::IsNullOrWhiteSpace($backupDir)) { throw "SQL Server default backup path was not returned." }
$benchmarkBackup = Join-Path $backupDir "financial-gpt55-clean.bak"
sqlcmd -S localhost -E -b -Q `
  "BACKUP DATABASE [Financial] TO DISK=N'$benchmarkBackup' WITH INIT, COPY_ONLY, CHECKSUM"
if ($LASTEXITCODE -ne 0) { throw "Database backup failed." }
```

Expected: SQL Server reports that the backup completed successfully.

- [ ] **Step 5: Write the experiment manifest**

Create `Document/experiments/gpt-5.5/manifest.md` containing:

```markdown
# GPT-5.5 Experiment Manifest

- Model label selected in Codex: GPT-5.5
- Pre-fix commit: 7a0469d9401a3061941b44fcd46b3beca1c9c729
- Baseline branch: codex/gpt-5.5-baseline
- SonarQube branch: codex/gpt-5.5-sonarqube-v1
- OWASP ZAP branch: codex/gpt-5.5-zap-v1
- Apache JMeter branch: codex/gpt-5.5-jmeter-v1
- Maximum model attempts per tool: 3
- Human-authored remediation code allowed: No
- GPT-5.4 fixes visible before GPT-5.5 branches freeze: No
- Database restore point: financial-gpt55-clean.bak
- Environment record: environment.json
```

- [ ] **Step 6: Commit the environment lock**

```powershell
git add Document/experiments/gpt-5.5
git diff --cached --check
git commit -m "test: lock GPT-5.5 benchmark environment"
```

Expected: one commit containing only manifest/environment evidence.

---

### Task 3: Capture the common pre-fix baseline

**Files:**

- Create: `Document/experiments/gpt-5.5/baseline/sonarqube-summary.json`
- Create: `Document/experiments/gpt-5.5/baseline/security/*`
- Create: `Document/experiments/gpt-5.5/baseline/performance/*`

**Interfaces:**

- Consumes: pre-fix application and frozen environment
- Produces: the before-state used by all three GPT-5.5 fix branches

- [ ] **Step 1: Require the Sonar token without writing it to disk**

```powershell
if ([string]::IsNullOrWhiteSpace($env:SONAR_TOKEN)) {
    throw "Set SONAR_TOKEN in the current PowerShell process before continuing."
}
```

- [ ] **Step 2: Restore the clean database**

```powershell
sqlcmd -S localhost -E -b -Q `
  "ALTER DATABASE [Financial] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; RESTORE DATABASE [Financial] FROM DISK=N'$benchmarkBackup' WITH REPLACE, CHECKSUM; ALTER DATABASE [Financial] SET MULTI_USER;"
if ($LASTEXITCODE -ne 0) { throw "Database restore failed." }
```

- [ ] **Step 3: Start and health-check the baseline API**

```powershell
$baselineDir = "Document/experiments/gpt-5.5/baseline"
New-Item -ItemType Directory -Force $baselineDir | Out-Null
$apiLog = Join-Path (Resolve-Path $baselineDir) "api.log"
$apiErr = Join-Path (Resolve-Path $baselineDir) "api.err.log"
$api = Start-Process dotnet `
  -ArgumentList @("run","--project","API/API.csproj","--urls","http://0.0.0.0:5296","--environment","Development") `
  -RedirectStandardOutput $apiLog `
  -RedirectStandardError $apiErr `
  -WindowStyle Hidden `
  -PassThru
$ready = $false
for ($attempt = 1; $attempt -le 60; $attempt++) {
    try {
        $response = Invoke-WebRequest "http://localhost:5296/health/ready" -UseBasicParsing -TimeoutSec 2
        if ($response.StatusCode -eq 200) { $ready = $true; break }
    } catch {}
    Start-Sleep -Seconds 2
}
if (-not $ready) { throw "API did not become ready. See $apiErr" }
```

Expected: `/health/ready` returns HTTP 200.

- [ ] **Step 4: Run and export SonarQube baseline results**

```powershell
$sonarProject = "financial-accounting-gpt55-baseline"
./scripts/phase4/setup-sonarqube.ps1 `
  -AdminToken $env:SONAR_TOKEN `
  -ProjectKey $sonarProject `
  -ProjectName "Financial Accounting GPT-5.5 Baseline"

./scripts/phase4/run-sonarqube-scan.ps1 `
  -SonarToken $env:SONAR_TOKEN `
  -ProjectKey $sonarProject `
  -ProjectName "Financial Accounting GPT-5.5 Baseline" `
  -ProjectVersion "gpt55-baseline-1" `
  -SolutionPath "API/API.sln"

./scripts/phase4/get-sonar-summary.ps1 `
  -SonarToken $env:SONAR_TOKEN `
  -ProjectKey $sonarProject |
  ConvertTo-Json -Depth 20 |
  Set-Content "Document/experiments/gpt-5.5/baseline/sonarqube-summary.json" -Encoding UTF8
```

Expected: the JSON contains a project key, quality gate, and measures.

- [ ] **Step 5: Run the baseline ZAP scans**

```powershell
$securityDir = "Document/experiments/gpt-5.5/baseline/security"
./scripts/phase4/run-zap-baseline.ps1 `
  -TargetUrl "http://localhost:5296" `
  -ReportDir $securityDir `
  -OutputPrefix "zap-baseline-gpt55-before" `
  -IgnoreWarnings

./scripts/phase4/run-zap-api.ps1 `
  -OpenApiUrl "http://localhost:5296/swagger/v1/swagger.json" `
  -BaseUrl "http://localhost:5296" `
  -Username "admin" `
  -Password "Admin@123" `
  -ApiVersion "1.0" `
  -ReportDir $securityDir `
  -OutputPrefix "zap-api-gpt55-before" `
  -IgnoreWarnings
```

Expected: HTML, JSON, and Markdown outputs exist for both scans.

- [ ] **Step 6: Restore the database again and run the JMeter matrix**

Stop the API, restore `financial-gpt55-clean.bak`, restart the API, then run:

```powershell
./scripts/phase4/run-jmeter-thesis-matrix.ps1 `
  -BaseUrl "http://localhost:5296" `
  -Username "admin" `
  -Password "Admin@123" `
  -ApiVersion "1.0" `
  -PeriodId 202601 `
  -AccountId 1 `
  -ResultsDir "Document/experiments/gpt-5.5/baseline/performance" `
  -RunTag "gpt55-before"
```

Expected: JTL and HTML statistics exist for p50, p100, p500, soak, and spike.

- [ ] **Step 7: Commit the baseline evidence**

```powershell
git add Document/experiments/gpt-5.5/baseline
git diff --cached --check
git commit -m "test: capture GPT-5.5 pre-fix baseline"
$gpt55BaselineCommit = (git rev-parse HEAD).Trim()
```

Expected: this commit is the parent used by every GPT-5.5 fix branch.

---

### Task 4: Run the blinded GPT-5.5 SonarQube remediation

**Files:**

- Create: `Document/experiments/gpt-5.5/interactions/sonarqube.md`
- Create: `Document/experiments/gpt-5.5/after/sonarqube/sonarqube-summary.json`
- Modify: only source/test files justified by current SonarQube findings

**Interfaces:**

- Consumes: `$gpt55BaselineCommit` and baseline SonarQube output
- Produces: `codex/gpt-5.5-sonarqube-v1`

- [ ] **Step 1: Create the independent branch**

```powershell
git switch -c codex/gpt-5.5-sonarqube-v1 $gpt55BaselineCommit
```

- [ ] **Step 2: Start a new Codex task with model GPT-5.5 and paste this exact prompt**

```text
You are fixing only the SonarQube findings measured in this checkout.

Constraints:
- Do not inspect other Git branches, remotes, reflogs, stashes, prior fix reports, or commits outside the current branch.
- Read the current SonarQube output and affected source files first.
- Preserve API routes, DTO JSON shape, authorization behavior, database semantics, and public service contracts unless a finding cannot be fixed otherwise.
- Make the smallest justified changes.
- Add or update focused tests for behavior-changing fixes.
- Run the smallest relevant tests and rerun SonarQube.
- You have one initial attempt and at most two finding-driven correction attempts.
- Stop after the third attempt even if findings remain.
- Record every changed file, Sonar rule, verification command, result, elapsed time, and any human intervention in Document/experiments/gpt-5.5/interactions/sonarqube.md.

Goal:
Resolve as many current SonarQube findings as safely possible and produce the after-scan evidence under Document/experiments/gpt-5.5/after/sonarqube.
```

- [ ] **Step 3: Verify model identity and transcript**

Record the Codex task ID, displayed model label `GPT-5.5`, start/end timestamps, attempt count, and full prompts/tool feedback in `interactions/sonarqube.md`.

- [ ] **Step 4: Run the final Sonar scan**

```powershell
$sonarAfterProject = "financial-accounting-gpt55-sonar-after"
./scripts/phase4/setup-sonarqube.ps1 `
  -AdminToken $env:SONAR_TOKEN `
  -ProjectKey $sonarAfterProject `
  -ProjectName "Financial Accounting GPT-5.5 Sonar After"

./scripts/phase4/run-sonarqube-scan.ps1 `
  -SonarToken $env:SONAR_TOKEN `
  -ProjectKey $sonarAfterProject `
  -ProjectName "Financial Accounting GPT-5.5 Sonar After" `
  -ProjectVersion "gpt55-sonar-after-1" `
  -SolutionPath "API/API.sln"

New-Item -ItemType Directory -Force "Document/experiments/gpt-5.5/after/sonarqube" | Out-Null
./scripts/phase4/get-sonar-summary.ps1 `
  -SonarToken $env:SONAR_TOKEN `
  -ProjectKey $sonarAfterProject |
  ConvertTo-Json -Depth 20 |
  Set-Content "Document/experiments/gpt-5.5/after/sonarqube/sonarqube-summary.json" -Encoding UTF8
```

- [ ] **Step 5: Commit the frozen Sonar result**

```powershell
git add -A
git diff --cached --check
git commit -m "fix: apply GPT-5.5 SonarQube remediation"
```

---

### Task 5: Run the blinded GPT-5.5 OWASP ZAP remediation

**Files:**

- Create: `Document/experiments/gpt-5.5/interactions/zap.md`
- Create: `Document/experiments/gpt-5.5/after/zap/*`
- Modify: only source/test/dependency files justified by current ZAP alerts

**Interfaces:**

- Consumes: `$gpt55BaselineCommit` and baseline ZAP JSON/Markdown
- Produces: `codex/gpt-5.5-zap-v1`

- [ ] **Step 1: Create the independent branch**

```powershell
git switch codex/gpt-5.5-baseline
git switch -c codex/gpt-5.5-zap-v1 $gpt55BaselineCommit
```

- [ ] **Step 2: Start a new Codex task with model GPT-5.5 and paste this exact prompt**

```text
You are fixing only the OWASP ZAP findings measured in this checkout.

Constraints:
- Do not inspect other Git branches, remotes, reflogs, stashes, prior fix reports, or commits outside the current branch.
- Read the baseline and authenticated API ZAP JSON/Markdown reports before changing code.
- Separate business-endpoint findings from Swagger/development-only findings.
- Preserve API behavior, authorization, OpenAPI availability, and response compatibility.
- Make the smallest justified changes and add focused security regression tests.
- Rerun both the baseline and authenticated API scans after each attempt.
- You have one initial attempt and at most two finding-driven correction attempts.
- Stop after the third attempt even if alerts remain.
- Record every changed file, alert ID, CWE, affected endpoint, verification command, result, elapsed time, and any human intervention in Document/experiments/gpt-5.5/interactions/zap.md.

Goal:
Resolve as many High, Medium, and Low business-endpoint alerts as safely possible and save the final reports under Document/experiments/gpt-5.5/after/zap.
```

- [ ] **Step 3: Restore the clean database before the final scans**

Stop the API, restore `financial-gpt55-clean.bak`, restart the API, and verify `/health/ready`.

- [ ] **Step 4: Run the final ZAP scans**

```powershell
$zapAfterDir = "Document/experiments/gpt-5.5/after/zap"
./scripts/phase4/run-zap-baseline.ps1 `
  -TargetUrl "http://localhost:5296" `
  -ReportDir $zapAfterDir `
  -OutputPrefix "zap-baseline-gpt55-after" `
  -IgnoreWarnings

./scripts/phase4/run-zap-api.ps1 `
  -OpenApiUrl "http://localhost:5296/swagger/v1/swagger.json" `
  -BaseUrl "http://localhost:5296" `
  -Username "admin" `
  -Password "Admin@123" `
  -ApiVersion "1.0" `
  -ReportDir $zapAfterDir `
  -OutputPrefix "zap-api-gpt55-after" `
  -IgnoreWarnings
```

- [ ] **Step 5: Freeze and commit the ZAP result**

Record model/task/timing/attempt metadata in `interactions/zap.md`, then:

```powershell
git add -A
git diff --cached --check
git commit -m "fix: apply GPT-5.5 OWASP ZAP remediation"
```

---

### Task 6: Run the blinded GPT-5.5 Apache JMeter remediation

**Files:**

- Create: `Document/experiments/gpt-5.5/interactions/jmeter.md`
- Create: `Document/experiments/gpt-5.5/after/jmeter/*`
- Modify: only source/test/schema-startup files justified by measured hotspots

**Interfaces:**

- Consumes: `$gpt55BaselineCommit`, baseline JTL/statistics, and endpoint metrics
- Produces: `codex/gpt-5.5-jmeter-v1`

- [ ] **Step 1: Create the independent branch**

```powershell
git switch codex/gpt-5.5-baseline
git switch -c codex/gpt-5.5-jmeter-v1 $gpt55BaselineCommit
```

- [ ] **Step 2: Start a new Codex task with model GPT-5.5 and paste this exact prompt**

```text
You are fixing only the Apache JMeter performance problems measured in this checkout.

Constraints:
- Do not inspect other Git branches, remotes, reflogs, stashes, prior fix reports, or commits outside the current branch.
- Analyze total and endpoint-level p95, p99, throughput, error rate, soak drift, and spike recovery before changing code.
- Preserve accounting correctness, authorization, audit requirements, API routes, response JSON, and database consistency.
- Do not weaken the workload, remove assertions, reduce users/loops, or loosen benchmark thresholds.
- Make the smallest evidence-backed changes and add focused correctness/performance regression tests.
- Restore the clean database before every full JMeter matrix.
- You have one initial attempt and at most two finding-driven correction attempts.
- Stop after the third attempt even if gates remain red.
- Record every changed file, bottleneck hypothesis, verification command, result, elapsed time, and any human intervention in Document/experiments/gpt-5.5/interactions/jmeter.md.

Goal:
Improve the measured p50, p100, p500, soak, and spike results without changing the workload or correctness contract, and save final outputs under Document/experiments/gpt-5.5/after/jmeter.
```

- [ ] **Step 3: Restore the clean database and run the final matrix**

Stop the API, restore `financial-gpt55-clean.bak`, restart the API, verify `/health/ready`, then:

```powershell
./scripts/phase4/run-jmeter-thesis-matrix.ps1 `
  -BaseUrl "http://localhost:5296" `
  -Username "admin" `
  -Password "Admin@123" `
  -ApiVersion "1.0" `
  -PeriodId 202601 `
  -AccountId 1 `
  -ResultsDir "Document/experiments/gpt-5.5/after/jmeter" `
  -RunTag "gpt55-after"
```

- [ ] **Step 4: Freeze and commit the JMeter result**

Record model/task/timing/attempt metadata in `interactions/jmeter.md`, then:

```powershell
git add -A
git diff --cached --check
git commit -m "perf: apply GPT-5.5 JMeter remediation"
```

---

### Task 7: Push and freeze all GPT-5.5 branches

**Files:**

- Verify: branch SHAs and clean worktree

**Interfaces:**

- Consumes: four local GPT-5.5 branches
- Produces: immutable remote references before GPT-5.4 is revealed

- [ ] **Step 1: Restore the GitHub remote**

```powershell
git remote add origin https://github.com/minatozaki98/financial-accounting.git
gh auth switch --hostname github.com --user minatozaki98
gh auth setup-git
```

- [ ] **Step 2: Push all frozen branches**

```powershell
git push -u origin codex/gpt-5.5-baseline
git push -u origin codex/gpt-5.5-sonarqube-v1
git push -u origin codex/gpt-5.5-zap-v1
git push -u origin codex/gpt-5.5-jmeter-v1
```

- [ ] **Step 3: Record the immutable branch SHAs**

```powershell
git for-each-ref `
  --format="%(refname:short) %(objectname)" `
  "refs/heads/codex/gpt-5.5-*"
git status --short
```

Expected: four branch/SHA pairs and a clean worktree. GPT-5.5 remediation is now frozen.

---

### Task 8: Normalize GPT-5.4 results under the GPT-5.5 environment

**Files:**

- Create: `Document/experiments/gpt-5.5/gpt-5.4-normalized/sonarqube/`
- Create: `Document/experiments/gpt-5.5/gpt-5.4-normalized/zap/`
- Create: `Document/experiments/gpt-5.5/gpt-5.4-normalized/jmeter/`

**Interfaces:**

- Consumes: frozen GPT-5.4 commits and the exact GPT-5.5 environment/database snapshot
- Produces: current-environment GPT-5.4 outcome metrics

- [ ] **Step 1: Fetch the historical fix branches only after GPT-5.5 freezes**

```powershell
git fetch origin baseline-sonarqube-v1 baseline-zap-v1 baseline-jmeter-v1
```

- [ ] **Step 2: Create detached worktrees at the exact GPT-5.4 code commits**

Run from the main repository:

```powershell
git worktree add --detach .worktrees/gpt55-compare-gpt54-sonar a2279bcbdc20751529335cf72f8baac1bc6f994b
git worktree add --detach .worktrees/gpt55-compare-gpt54-zap 5f3bd3ccd9e0d460f52cac6a8a0d5fdceff1ce3d
git worktree add --detach .worktrees/gpt55-compare-gpt54-jmeter 78b08b62570dcf6fe436354e8e6b770ab2074445
```

- [ ] **Step 3: Verify Docker image IDs still match `environment.json`**

Capture the same three `docker image inspect` values used in Task 2 and compare them byte-for-byte with `environment.json`.

Expected: all three IDs match. If any differ, stop; do not label the results normalized.

- [ ] **Step 4: Rerun the GPT-5.4 Sonar branch**

From `.worktrees/gpt55-compare-gpt54-sonar`:

```powershell
if ([string]::IsNullOrWhiteSpace($env:SONAR_TOKEN)) {
    throw "Set SONAR_TOKEN before the normalized GPT-5.4 Sonar run."
}
$sonarProject = "financial-accounting-gpt54-normalized-sonar"
./scripts/phase4/setup-sonarqube.ps1 `
  -AdminToken $env:SONAR_TOKEN `
  -ProjectKey $sonarProject `
  -ProjectName "Financial Accounting GPT-5.4 Normalized Sonar"
./scripts/phase4/run-sonarqube-scan.ps1 `
  -SonarToken $env:SONAR_TOKEN `
  -ProjectKey $sonarProject `
  -ProjectName "Financial Accounting GPT-5.4 Normalized Sonar" `
  -ProjectVersion "gpt54-normalized-sonar-1" `
  -SolutionPath "API/API.sln"
$sonarOutputDir = "Document/experiments/gpt-5.5/gpt-5.4-normalized/sonarqube"
New-Item -ItemType Directory -Force $sonarOutputDir | Out-Null
./scripts/phase4/get-sonar-summary.ps1 `
  -SonarToken $env:SONAR_TOKEN `
  -ProjectKey $sonarProject |
  ConvertTo-Json -Depth 20 |
  Set-Content "$sonarOutputDir/sonarqube-summary.json" -Encoding UTF8
```

Export `sonarqube-summary.json` under `gpt-5.4-normalized/sonarqube/`.

- [ ] **Step 5: Rerun the GPT-5.4 ZAP branch**

From `.worktrees/gpt55-compare-gpt54-zap`:

```powershell
$backupDir = (& sqlcmd -S localhost -E -h -1 -W -Q `
  "SET NOCOUNT ON; SELECT CAST(SERVERPROPERTY('InstanceDefaultBackupPath') AS nvarchar(4000));").Trim()
$benchmarkBackup = Join-Path $backupDir "financial-gpt55-clean.bak"
sqlcmd -S localhost -E -b -Q `
  "ALTER DATABASE [Financial] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; RESTORE DATABASE [Financial] FROM DISK=N'$benchmarkBackup' WITH REPLACE, CHECKSUM; ALTER DATABASE [Financial] SET MULTI_USER;"

$api = Start-Process dotnet `
  -ArgumentList @("run","--project","API/API.csproj","--urls","http://0.0.0.0:5296","--environment","Development") `
  -RedirectStandardOutput "gpt54-zap-api.log" `
  -RedirectStandardError "gpt54-zap-api.err.log" `
  -WindowStyle Hidden `
  -PassThru

$ready = $false
for ($attempt = 1; $attempt -le 60; $attempt++) {
    try {
        $response = Invoke-WebRequest "http://localhost:5296/health/ready" -UseBasicParsing -TimeoutSec 2
        if ($response.StatusCode -eq 200) { $ready = $true; break }
    } catch {}
    Start-Sleep -Seconds 2
}
if (-not $ready) { throw "GPT-5.4 ZAP API did not become ready." }

$normalizedZapDir = "Document/experiments/gpt-5.5/gpt-5.4-normalized/zap"
./scripts/phase4/run-zap-baseline.ps1 `
  -TargetUrl "http://localhost:5296" `
  -ReportDir $normalizedZapDir `
  -OutputPrefix "zap-baseline-gpt54-normalized" `
  -IgnoreWarnings
./scripts/phase4/run-zap-api.ps1 `
  -OpenApiUrl "http://localhost:5296/swagger/v1/swagger.json" `
  -BaseUrl "http://localhost:5296" `
  -Username "admin" `
  -Password "Admin@123" `
  -ApiVersion "1.0" `
  -ReportDir $normalizedZapDir `
  -OutputPrefix "zap-api-gpt54-normalized" `
  -IgnoreWarnings
Stop-Process -Id $api.Id
```

- [ ] **Step 6: Rerun the GPT-5.4 JMeter branch**

From `.worktrees/gpt55-compare-gpt54-jmeter`:

```powershell
$backupDir = (& sqlcmd -S localhost -E -h -1 -W -Q `
  "SET NOCOUNT ON; SELECT CAST(SERVERPROPERTY('InstanceDefaultBackupPath') AS nvarchar(4000));").Trim()
$benchmarkBackup = Join-Path $backupDir "financial-gpt55-clean.bak"
sqlcmd -S localhost -E -b -Q `
  "ALTER DATABASE [Financial] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; RESTORE DATABASE [Financial] FROM DISK=N'$benchmarkBackup' WITH REPLACE, CHECKSUM; ALTER DATABASE [Financial] SET MULTI_USER;"

$api = Start-Process dotnet `
  -ArgumentList @("run","--project","API/API.csproj","--urls","http://0.0.0.0:5296","--environment","Development") `
  -RedirectStandardOutput "gpt54-jmeter-api.log" `
  -RedirectStandardError "gpt54-jmeter-api.err.log" `
  -WindowStyle Hidden `
  -PassThru

$ready = $false
for ($attempt = 1; $attempt -le 60; $attempt++) {
    try {
        $response = Invoke-WebRequest "http://localhost:5296/health/ready" -UseBasicParsing -TimeoutSec 2
        if ($response.StatusCode -eq 200) { $ready = $true; break }
    } catch {}
    Start-Sleep -Seconds 2
}
if (-not $ready) { throw "GPT-5.4 JMeter API did not become ready." }

./scripts/phase4/run-jmeter-thesis-matrix.ps1 `
  -BaseUrl "http://localhost:5296" `
  -Username "admin" `
  -Password "Admin@123" `
  -ApiVersion "1.0" `
  -PeriodId 202601 `
  -AccountId 1 `
  -ResultsDir "Document/experiments/gpt-5.5/gpt-5.4-normalized/jmeter" `
  -RunTag "gpt54-normalized"
Stop-Process -Id $api.Id
```

- [ ] **Step 7: Keep the detached worktrees until evidence aggregation**

Do not remove the three detached worktrees yet. Task 9 copies their normalized outputs into the comparison branch before cleanup.

---

### Task 9: Write the GPT-5.4-versus-GPT-5.5 report

**Files:**

- Create: `Document/experiments/gpt-5.5/gpt-5.4-vs-gpt-5.5.md`

**Interfaces:**

- Consumes: normalized GPT-5.4 outputs, frozen GPT-5.5 outputs, interactions, commits
- Produces: evidence-backed model comparison without mixing historical and current environments

- [ ] **Step 1: Create the evidence-only comparison branch**

```powershell
git switch codex/gpt-5.5-baseline
git switch -c codex/gpt-5.5-comparison
```

- [ ] **Step 2: Bring only GPT-5.5 evidence from each fix branch**

```powershell
git restore --source codex/gpt-5.5-sonarqube-v1 -- `
  Document/experiments/gpt-5.5/interactions/sonarqube.md `
  Document/experiments/gpt-5.5/after/sonarqube
git restore --source codex/gpt-5.5-zap-v1 -- `
  Document/experiments/gpt-5.5/interactions/zap.md `
  Document/experiments/gpt-5.5/after/zap
git restore --source codex/gpt-5.5-jmeter-v1 -- `
  Document/experiments/gpt-5.5/interactions/jmeter.md `
  Document/experiments/gpt-5.5/after/jmeter
```

Expected: no GPT-5.5 remediation source code is merged into the comparison branch.

- [ ] **Step 3: Copy the normalized GPT-5.4 outputs**

```powershell
$repoRoot = (git rev-parse --show-toplevel).Trim()
$normalizedRoot = Join-Path $repoRoot "Document\experiments\gpt-5.5\gpt-5.4-normalized"
New-Item -ItemType Directory -Force $normalizedRoot | Out-Null
Copy-Item `
  "$repoRoot\.worktrees\gpt55-compare-gpt54-sonar\Document\experiments\gpt-5.5\gpt-5.4-normalized\sonarqube" `
  $normalizedRoot -Recurse -Force
Copy-Item `
  "$repoRoot\.worktrees\gpt55-compare-gpt54-zap\Document\experiments\gpt-5.5\gpt-5.4-normalized\zap" `
  $normalizedRoot -Recurse -Force
Copy-Item `
  "$repoRoot\.worktrees\gpt55-compare-gpt54-jmeter\Document\experiments\gpt-5.5\gpt-5.4-normalized\jmeter" `
  $normalizedRoot -Recurse -Force
```

- [ ] **Step 4: Write the report with these exact sections**

```markdown
# GPT-5.4 vs GPT-5.5: Financial Accounting API Remediation Benchmark

## Experimental Controls
## Source and Branch Provenance
## Environment and Tool Image Identity
## SonarQube Outcome Comparison
## OWASP ZAP Outcome Comparison
## Apache JMeter Outcome Comparison
## Patch Size and Files Changed
## Tests Added and Regression Results
## Attempts, Elapsed Time, and Human Intervention
## Residual Findings and Failed Gates
## Historical 2026-03 Results vs Normalized Reruns
## Threats to Validity
## Conclusion
```

For each tool, include:

- Before and after metrics for both models.
- Absolute change and percentage change.
- Pass/fail against the existing thesis thresholds.
- Fix-branch SHA and source diff statistics.
- Number of model attempts.
- Number of human interventions.
- Tests added/changed and final test counts.
- Remaining findings or alerts.
- Correctness/security/performance tradeoffs.

The report must explicitly state that historical GPT-5.4 process metadata may be incomplete; do not invent missing prompt counts or elapsed times.

- [ ] **Step 5: Validate report provenance**

```powershell
rg -n "7a0469d|a2279bc|5f3bd3c|78b08b6|codex/gpt-5.5" `
  Document/experiments/gpt-5.5/gpt-5.4-vs-gpt-5.5.md
rg -n "TBD|TODO|PLACEHOLDER" `
  Document/experiments/gpt-5.5/gpt-5.4-vs-gpt-5.5.md
```

Expected: provenance identifiers are present and no placeholders remain.

- [ ] **Step 6: Commit and push the comparison**

```powershell
git add Document/experiments/gpt-5.5
git diff --cached --check
git commit -m "docs: compare GPT-5.4 and GPT-5.5 remediation results"
git push -u origin codex/gpt-5.5-comparison
```

- [ ] **Step 7: Remove the detached GPT-5.4 comparison worktrees**

Run from the main repository after the comparison commit is pushed:

```powershell
git worktree remove .worktrees/gpt55-compare-gpt54-sonar
git worktree remove .worktrees/gpt55-compare-gpt54-zap
git worktree remove .worktrees/gpt55-compare-gpt54-jmeter
```

---

## Completion Gates

- [ ] All five GPT-5.5 branches exist remotely.
- [ ] Every branch descends from the committed GPT-5.5 baseline evidence state.
- [ ] GPT-5.5 was blinded from GPT-5.4 fixes until its branches were frozen.
- [ ] SonarQube, ZAP, and JMeter before/after raw outputs are retained.
- [ ] Database and Docker-image identity are controlled across reruns.
- [ ] GPT-5.4 outcomes are freshly rerun under the same environment.
- [ ] The final report separates outcome evidence from incomplete historical process evidence.
- [ ] No failing gate or residual issue is hidden.
