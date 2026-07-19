# GPT-5.6-sol Quality Benchmark Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Provide a ready-to-run contingency protocol for evaluating GPT-5.6-sol on the same financial-accounting SonarQube, OWASP ZAP, and Apache JMeter remediation benchmark without committing to run it now.

**Architecture:** Start from a blinded single-branch clone of the immutable pre-fix commit, capture a fresh baseline under pinned images and a restorable database, create one isolated fix branch per tool, and freeze all GPT-5.6-sol outputs before revealing earlier model fixes. If executed, compare normalized GPT-5.4, GPT-5.5, and GPT-5.6-sol outcomes under one environment.

**Tech Stack:** GPT-5.6-sol in Codex, Git/GitHub, PowerShell, ASP.NET Core 8, SQL Server, SonarQube Community, OWASP ZAP, Apache JMeter 5.5, Docker Desktop.

## Global Constraints

- This document is planning-only until the user explicitly authorizes the GPT-5.6-sol experiment.
- Pre-fix source is immutable: `7a0469d9401a3061941b44fcd46b3beca1c9c729`.
- GPT-5.6-sol must not inspect GPT-5.4 or GPT-5.5 branches, commits, reports, prompts, or patches before its own branches freeze.
- Use one initial remediation attempt plus at most two finding-driven correction attempts per tool.
- No human-authored remediation code.
- Restore the same SQL Server backup before every ZAP or JMeter run.
- Pin Docker image IDs/digests. Do not use newly pulled mutable tags during a comparison series.
- Do not weaken tool rules, user counts, loops, assertions, or benchmark thresholds.
- Preserve failures and residual findings as experimental results.
- Record displayed model label, Codex task ID, prompts, tool feedback, elapsed time, attempts, changed files, commit SHAs, and human interventions.

---

## File and Branch Map

### Branches

- `codex/gpt-5.6-sol-baseline`
- `codex/gpt-5.6-sol-sonarqube-v1`
- `codex/gpt-5.6-sol-zap-v1`
- `codex/gpt-5.6-sol-jmeter-v1`
- `codex/gpt-5.6-sol-comparison`

### Files

- Create: `Document/experiments/gpt-5.6-sol/manifest.md`
- Create: `Document/experiments/gpt-5.6-sol/environment.json`
- Create: `Document/experiments/gpt-5.6-sol/baseline/`
- Create: `Document/experiments/gpt-5.6-sol/interactions/sonarqube.md`
- Create: `Document/experiments/gpt-5.6-sol/interactions/zap.md`
- Create: `Document/experiments/gpt-5.6-sol/interactions/jmeter.md`
- Create: `Document/experiments/gpt-5.6-sol/after/sonarqube/`
- Create: `Document/experiments/gpt-5.6-sol/after/zap/`
- Create: `Document/experiments/gpt-5.6-sol/after/jmeter/`
- Create: `Document/experiments/gpt-5.6-sol/gpt-5.4-gpt-5.5-gpt-5.6-sol.md`

---

### Task 1: Decide the comparison mode before running

**Files:**

- Record decision in: `Document/experiments/gpt-5.6-sol/manifest.md`

**Interfaces:**

- Consumes: whether the GPT-5.5 experiment has completed
- Produces: one valid environment strategy

- [ ] **Step 1: Confirm the selected strategy**

This plan uses a new GPT-5.6-sol environment snapshot named `financial-gpt56sol-clean.bak`. After GPT-5.6-sol freezes, it freshly reruns the frozen GPT-5.4 and GPT-5.5 outputs under that environment. This is slower than reusing an older snapshot, but it avoids relying on an environment that may have drifted or been deleted.

Never compare a new GPT-5.6-sol performance run directly against historical March 2026 metrics without normalized reruns.

---

### Task 2: Create a blinded GPT-5.6-sol repository

**Files:**

- Create locally: `.worktrees/gpt-5.6-sol-lab/`

**Interfaces:**

- Consumes: `origin/baseline-v0.1`
- Produces: isolated `codex/gpt-5.6-sol-baseline`

- [ ] **Step 1: Clone only the baseline branch**

```powershell
$repoRoot = (git rev-parse --show-toplevel).Trim()
$labPath = Join-Path $repoRoot ".worktrees\gpt-5.6-sol-lab"
git clone --no-local --single-branch --branch baseline-v0.1 `
  https://github.com/minatozaki98/financial-accounting.git $labPath
Set-Location $labPath
```

- [ ] **Step 2: Verify, rename, and blind the clone**

```powershell
$expectedBase = "7a0469d9401a3061941b44fcd46b3beca1c9c729"
if ((git rev-parse HEAD).Trim() -ne $expectedBase) {
    throw "GPT-5.6-sol experiment is not on the required pre-fix commit."
}
git branch -m codex/gpt-5.6-sol-baseline
git remote remove origin
git show-ref
```

Expected: no GPT-5.4 or GPT-5.5 fix ref is present.

---

### Task 3: Pin the environment and capture the pre-fix baseline

**Files:**

- Create: `Document/experiments/gpt-5.6-sol/environment.json`
- Create: `Document/experiments/gpt-5.6-sol/manifest.md`
- Create: `Document/experiments/gpt-5.6-sol/baseline/*`

**Interfaces:**

- Consumes: chosen environment strategy
- Produces: one baseline evidence commit shared by all GPT-5.6-sol branches

- [ ] **Step 1: Record source, model, machine, and image identity**

Run `./scripts/phase4/install-tools.ps1` exactly once, then run:

```powershell
$experimentRoot = "Document/experiments/gpt-5.6-sol"
New-Item -ItemType Directory -Force -Path $experimentRoot | Out-Null
$environment = [ordered]@{
    capturedAtUtc = (Get-Date).ToUniversalTime().ToString("o")
    modelLabel = "GPT-5.6-sol"
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

- [ ] **Step 2: Create the clean database restore point**

```powershell
./scripts/phase4/seed-test-data.ps1 `
  -AdminUsername "admin" `
  -AdminPassword "Admin@123" `
  -PeriodId 202601 `
  -AccountCount 120 `
  -JournalEntryCount 30000 `
  -MinimumPostedEntries 5000

$backupDir = (& sqlcmd -S localhost -E -h -1 -W -Q `
  "SET NOCOUNT ON; SELECT CAST(SERVERPROPERTY('InstanceDefaultBackupPath') AS nvarchar(4000));").Trim()
$benchmarkBackup = Join-Path $backupDir "financial-gpt56sol-clean.bak"
sqlcmd -S localhost -E -b -Q `
  "BACKUP DATABASE [Financial] TO DISK=N'$benchmarkBackup' WITH INIT, COPY_ONLY, CHECKSUM"
```

- [ ] **Step 3: Capture SonarQube baseline**

```powershell
if ([string]::IsNullOrWhiteSpace($env:SONAR_TOKEN)) {
    throw "Set SONAR_TOKEN before continuing."
}
$sonarProject = "financial-accounting-gpt56sol-baseline"
$baselineRoot = "Document/experiments/gpt-5.6-sol/baseline"
New-Item -ItemType Directory -Force $baselineRoot | Out-Null
./scripts/phase4/setup-sonarqube.ps1 `
  -AdminToken $env:SONAR_TOKEN `
  -ProjectKey $sonarProject `
  -ProjectName "Financial Accounting GPT-5.6-sol Baseline"
./scripts/phase4/run-sonarqube-scan.ps1 `
  -SonarToken $env:SONAR_TOKEN `
  -ProjectKey $sonarProject `
  -ProjectName "Financial Accounting GPT-5.6-sol Baseline" `
  -ProjectVersion "gpt56sol-baseline-1" `
  -SolutionPath "API/API.sln"
./scripts/phase4/get-sonar-summary.ps1 `
  -SonarToken $env:SONAR_TOKEN `
  -ProjectKey $sonarProject |
  ConvertTo-Json -Depth 20 |
  Set-Content "$baselineRoot/sonarqube-summary.json" -Encoding UTF8
```

- [ ] **Step 4: Restore the database and start the API**

If using the new GPT-5.6-sol backup:

```powershell
$backupDir = (& sqlcmd -S localhost -E -h -1 -W -Q `
  "SET NOCOUNT ON; SELECT CAST(SERVERPROPERTY('InstanceDefaultBackupPath') AS nvarchar(4000));").Trim()
$benchmarkBackup = Join-Path $backupDir "financial-gpt56sol-clean.bak"
sqlcmd -S localhost -E -b -Q `
  "ALTER DATABASE [Financial] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; RESTORE DATABASE [Financial] FROM DISK=N'$benchmarkBackup' WITH REPLACE, CHECKSUM; ALTER DATABASE [Financial] SET MULTI_USER;"

$api = Start-Process dotnet `
  -ArgumentList @("run","--project","API/API.csproj","--urls","http://0.0.0.0:5296","--environment","Development") `
  -RedirectStandardOutput "$baselineRoot/api.log" `
  -RedirectStandardError "$baselineRoot/api.err.log" `
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
if (-not $ready) { throw "GPT-5.6-sol baseline API did not become ready." }
```

- [ ] **Step 5: Capture ZAP baseline and API scans**

```powershell
$securityDir = "$baselineRoot/security"
./scripts/phase4/run-zap-baseline.ps1 `
  -TargetUrl "http://localhost:5296" `
  -ReportDir $securityDir `
  -OutputPrefix "zap-baseline-gpt56sol-before" `
  -IgnoreWarnings
./scripts/phase4/run-zap-api.ps1 `
  -OpenApiUrl "http://localhost:5296/swagger/v1/swagger.json" `
  -BaseUrl "http://localhost:5296" `
  -Username "admin" `
  -Password "Admin@123" `
  -ApiVersion "1.0" `
  -ReportDir $securityDir `
  -OutputPrefix "zap-api-gpt56sol-before" `
  -IgnoreWarnings
```

- [ ] **Step 6: Restore the database and capture JMeter baseline**

Stop the API and restore the clean database:

```powershell
$backupDir = (& sqlcmd -S localhost -E -h -1 -W -Q `
  "SET NOCOUNT ON; SELECT CAST(SERVERPROPERTY('InstanceDefaultBackupPath') AS nvarchar(4000));").Trim()
$benchmarkBackup = Join-Path $backupDir "financial-gpt56sol-clean.bak"
sqlcmd -S localhost -E -b -Q `
  "ALTER DATABASE [Financial] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; RESTORE DATABASE [Financial] FROM DISK=N'$benchmarkBackup' WITH REPLACE, CHECKSUM; ALTER DATABASE [Financial] SET MULTI_USER;"

$api = Start-Process dotnet `
  -ArgumentList @("run","--project","API/API.csproj","--urls","http://0.0.0.0:5296","--environment","Development") `
  -RedirectStandardOutput "$baselineRoot/jmeter-api.log" `
  -RedirectStandardError "$baselineRoot/jmeter-api.err.log" `
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
if (-not $ready) { throw "GPT-5.6-sol baseline JMeter API did not become ready." }

./scripts/phase4/run-jmeter-thesis-matrix.ps1 `
  -BaseUrl "http://localhost:5296" `
  -Username "admin" `
  -Password "Admin@123" `
  -ApiVersion "1.0" `
  -PeriodId 202601 `
  -AccountId 1 `
  -ResultsDir "$baselineRoot/performance" `
  -RunTag "gpt56sol-before"
```

- [ ] **Step 7: Commit the common baseline**

```powershell
git add Document/experiments/gpt-5.6-sol
git diff --cached --check
git commit -m "test: capture GPT-5.6-sol pre-fix baseline"
$gpt56BaselineCommit = (git rev-parse HEAD).Trim()
```

---

### Task 4: Run GPT-5.6-sol SonarQube remediation

**Files:**

- Create: `Document/experiments/gpt-5.6-sol/interactions/sonarqube.md`
- Create: `Document/experiments/gpt-5.6-sol/after/sonarqube/sonarqube-summary.json`

**Interfaces:**

- Consumes: `$gpt56BaselineCommit`
- Produces: `codex/gpt-5.6-sol-sonarqube-v1`

- [ ] **Step 1: Create the branch**

```powershell
git switch -c codex/gpt-5.6-sol-sonarqube-v1 $gpt56BaselineCommit
```

- [ ] **Step 2: Start a fresh Codex task using the displayed model GPT-5.6-sol**

Use this exact prompt:

```text
Fix only the SonarQube findings measured in this checkout. Do not inspect any other branch, remote, reflog, stash, prior model report, or commit outside this branch. Preserve API routes, DTO JSON, authorization, database behavior, and public contracts. Make the smallest justified changes, add focused tests for behavior changes, and rerun SonarQube. You have one initial attempt and at most two finding-driven correction attempts. Stop after attempt three even if findings remain. Record model label, task ID, prompts, changed files, rules, commands, results, elapsed time, and human intervention in Document/experiments/gpt-5.6-sol/interactions/sonarqube.md. Save final evidence under Document/experiments/gpt-5.6-sol/after/sonarqube.
```

- [ ] **Step 3: Run the final scan and commit**

```powershell
if ([string]::IsNullOrWhiteSpace($env:SONAR_TOKEN)) {
    throw "Set SONAR_TOKEN before the final GPT-5.6-sol Sonar scan."
}
$sonarAfterProject = "financial-accounting-gpt56sol-sonar-after"
./scripts/phase4/setup-sonarqube.ps1 `
  -AdminToken $env:SONAR_TOKEN `
  -ProjectKey $sonarAfterProject `
  -ProjectName "Financial Accounting GPT-5.6-sol Sonar After"
./scripts/phase4/run-sonarqube-scan.ps1 `
  -SonarToken $env:SONAR_TOKEN `
  -ProjectKey $sonarAfterProject `
  -ProjectName "Financial Accounting GPT-5.6-sol Sonar After" `
  -ProjectVersion "gpt56sol-sonar-after-1" `
  -SolutionPath "API/API.sln"
New-Item -ItemType Directory -Force "Document/experiments/gpt-5.6-sol/after/sonarqube" | Out-Null
./scripts/phase4/get-sonar-summary.ps1 `
  -SonarToken $env:SONAR_TOKEN `
  -ProjectKey $sonarAfterProject |
  ConvertTo-Json -Depth 20 |
  Set-Content "Document/experiments/gpt-5.6-sol/after/sonarqube/sonarqube-summary.json" -Encoding UTF8
git add -A
git diff --cached --check
git commit -m "fix: apply GPT-5.6-sol SonarQube remediation"
```

---

### Task 5: Run GPT-5.6-sol OWASP ZAP remediation

**Files:**

- Create: `Document/experiments/gpt-5.6-sol/interactions/zap.md`
- Create: `Document/experiments/gpt-5.6-sol/after/zap/*`

**Interfaces:**

- Consumes: `$gpt56BaselineCommit`
- Produces: `codex/gpt-5.6-sol-zap-v1`

- [ ] **Step 1: Create the branch**

```powershell
git switch codex/gpt-5.6-sol-baseline
git switch -c codex/gpt-5.6-sol-zap-v1 $gpt56BaselineCommit
```

- [ ] **Step 2: Start a fresh Codex task using GPT-5.6-sol**

Use this exact prompt:

```text
Fix only the OWASP ZAP findings measured in this checkout. Do not inspect any other branch, remote, reflog, stash, prior model report, or commit outside this branch. Read both baseline and authenticated API reports, separate business-endpoint findings from development-only findings, preserve API and authorization behavior, make the smallest justified changes, add focused security tests, and rerun both scans. You have one initial attempt and at most two finding-driven correction attempts. Stop after attempt three even if alerts remain. Record model label, task ID, prompts, changed files, alert IDs, CWEs, endpoints, commands, results, elapsed time, and human intervention in Document/experiments/gpt-5.6-sol/interactions/zap.md. Save final evidence under Document/experiments/gpt-5.6-sol/after/zap.
```

- [ ] **Step 3: Restore, retest, and commit**

```powershell
$backupDir = (& sqlcmd -S localhost -E -h -1 -W -Q `
  "SET NOCOUNT ON; SELECT CAST(SERVERPROPERTY('InstanceDefaultBackupPath') AS nvarchar(4000));").Trim()
$benchmarkBackup = Join-Path $backupDir "financial-gpt56sol-clean.bak"
sqlcmd -S localhost -E -b -Q `
  "ALTER DATABASE [Financial] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; RESTORE DATABASE [Financial] FROM DISK=N'$benchmarkBackup' WITH REPLACE, CHECKSUM; ALTER DATABASE [Financial] SET MULTI_USER;"

$api = Start-Process dotnet `
  -ArgumentList @("run","--project","API/API.csproj","--urls","http://0.0.0.0:5296","--environment","Development") `
  -RedirectStandardOutput "Document/experiments/gpt-5.6-sol/after/zap-api.log" `
  -RedirectStandardError "Document/experiments/gpt-5.6-sol/after/zap-api.err.log" `
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
if (-not $ready) { throw "GPT-5.6-sol ZAP API did not become ready." }

$zapAfterDir = "Document/experiments/gpt-5.6-sol/after/zap"
./scripts/phase4/run-zap-baseline.ps1 `
  -TargetUrl "http://localhost:5296" `
  -ReportDir $zapAfterDir `
  -OutputPrefix "zap-baseline-gpt56sol-after" `
  -IgnoreWarnings
./scripts/phase4/run-zap-api.ps1 `
  -OpenApiUrl "http://localhost:5296/swagger/v1/swagger.json" `
  -BaseUrl "http://localhost:5296" `
  -Username "admin" `
  -Password "Admin@123" `
  -ApiVersion "1.0" `
  -ReportDir $zapAfterDir `
  -OutputPrefix "zap-api-gpt56sol-after" `
  -IgnoreWarnings
Stop-Process -Id $api.Id
git add -A
git diff --cached --check
git commit -m "fix: apply GPT-5.6-sol OWASP ZAP remediation"
```

---

### Task 6: Run GPT-5.6-sol Apache JMeter remediation

**Files:**

- Create: `Document/experiments/gpt-5.6-sol/interactions/jmeter.md`
- Create: `Document/experiments/gpt-5.6-sol/after/jmeter/*`

**Interfaces:**

- Consumes: `$gpt56BaselineCommit`
- Produces: `codex/gpt-5.6-sol-jmeter-v1`

- [ ] **Step 1: Create the branch**

```powershell
git switch codex/gpt-5.6-sol-baseline
git switch -c codex/gpt-5.6-sol-jmeter-v1 $gpt56BaselineCommit
```

- [ ] **Step 2: Start a fresh Codex task using GPT-5.6-sol**

Use this exact prompt:

```text
Fix only the Apache JMeter performance problems measured in this checkout. Do not inspect any other branch, remote, reflog, stash, prior model report, or commit outside this branch. Analyze total and endpoint p95, p99, throughput, error rate, soak drift, and spike recovery. Preserve accounting correctness, authorization, audit behavior, routes, JSON responses, and database consistency. Do not weaken workload, assertions, users, loops, or thresholds. Make the smallest evidence-backed changes and add focused regression tests. You have one initial attempt and at most two finding-driven correction attempts. Stop after attempt three even if gates remain red. Record model label, task ID, prompts, changed files, hypotheses, commands, results, elapsed time, and human intervention in Document/experiments/gpt-5.6-sol/interactions/jmeter.md. Save final evidence under Document/experiments/gpt-5.6-sol/after/jmeter.
```

- [ ] **Step 3: Restore, retest, and commit**

```powershell
$backupDir = (& sqlcmd -S localhost -E -h -1 -W -Q `
  "SET NOCOUNT ON; SELECT CAST(SERVERPROPERTY('InstanceDefaultBackupPath') AS nvarchar(4000));").Trim()
$benchmarkBackup = Join-Path $backupDir "financial-gpt56sol-clean.bak"
sqlcmd -S localhost -E -b -Q `
  "ALTER DATABASE [Financial] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; RESTORE DATABASE [Financial] FROM DISK=N'$benchmarkBackup' WITH REPLACE, CHECKSUM; ALTER DATABASE [Financial] SET MULTI_USER;"

$api = Start-Process dotnet `
  -ArgumentList @("run","--project","API/API.csproj","--urls","http://0.0.0.0:5296","--environment","Development") `
  -RedirectStandardOutput "Document/experiments/gpt-5.6-sol/after/jmeter-api.log" `
  -RedirectStandardError "Document/experiments/gpt-5.6-sol/after/jmeter-api.err.log" `
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
if (-not $ready) { throw "GPT-5.6-sol JMeter API did not become ready." }

./scripts/phase4/run-jmeter-thesis-matrix.ps1 `
  -BaseUrl "http://localhost:5296" `
  -Username "admin" `
  -Password "Admin@123" `
  -ApiVersion "1.0" `
  -PeriodId 202601 `
  -AccountId 1 `
  -ResultsDir "Document/experiments/gpt-5.6-sol/after/jmeter" `
  -RunTag "gpt56sol-after"
Stop-Process -Id $api.Id
git add -A
git diff --cached --check
git commit -m "perf: apply GPT-5.6-sol JMeter remediation"
```

---

### Task 7: Freeze branches before model comparison

**Files:**

- Verify: remote branch SHAs

**Interfaces:**

- Consumes: four blinded GPT-5.6-sol branches
- Produces: immutable remote results

- [ ] **Step 1: Restore GitHub and push**

```powershell
git remote add origin https://github.com/minatozaki98/financial-accounting.git
gh auth switch --hostname github.com --user minatozaki98
gh auth setup-git
git push -u origin codex/gpt-5.6-sol-baseline
git push -u origin codex/gpt-5.6-sol-sonarqube-v1
git push -u origin codex/gpt-5.6-sol-zap-v1
git push -u origin codex/gpt-5.6-sol-jmeter-v1
```

- [ ] **Step 2: Record branch SHAs and verify clean state**

```powershell
git for-each-ref --format="%(refname:short) %(objectname)" "refs/heads/codex/gpt-5.6-sol-*"
git status --short
```

Only after this point may the comparison task fetch GPT-5.4 and GPT-5.5 branches.

---

### Task 8: Normalize earlier models and publish the three-model report

**Files:**

- Create: `Document/experiments/gpt-5.6-sol/gpt-5.4-gpt-5.5-gpt-5.6-sol.md`

**Interfaces:**

- Consumes: frozen model branches and one identical runtime environment
- Produces: `codex/gpt-5.6-sol-comparison`

- [ ] **Step 1: Create normalized rerun worktrees for GPT-5.4 and GPT-5.5**

After GPT-5.6-sol freezes and the remote is restored:

```powershell
git fetch origin `
  baseline-sonarqube-v1 `
  baseline-zap-v1 `
  baseline-jmeter-v1 `
  codex/gpt-5.5-sonarqube-v1 `
  codex/gpt-5.5-zap-v1 `
  codex/gpt-5.5-jmeter-v1

git worktree add --detach .worktrees/gpt56-compare-gpt54-sonar a2279bcbdc20751529335cf72f8baac1bc6f994b
git worktree add --detach .worktrees/gpt56-compare-gpt54-zap 5f3bd3ccd9e0d460f52cac6a8a0d5fdceff1ce3d
git worktree add --detach .worktrees/gpt56-compare-gpt54-jmeter 78b08b62570dcf6fe436354e8e6b770ab2074445
git worktree add --detach .worktrees/gpt56-compare-gpt55-sonar origin/codex/gpt-5.5-sonarqube-v1
git worktree add --detach .worktrees/gpt56-compare-gpt55-zap origin/codex/gpt-5.5-zap-v1
git worktree add --detach .worktrees/gpt56-compare-gpt55-jmeter origin/codex/gpt-5.5-jmeter-v1
```

- [ ] **Step 2: Rerun the six earlier-model tool branches**

Use these immutable mappings:

| Worktree | Tool | Project key/tag | Output directory |
|---|---|---|---|
| `gpt56-compare-gpt54-sonar` | SonarQube | `financial-accounting-gpt54-gpt56env` | `Document/experiments/gpt-5.6-sol/normalized/gpt-5.4/sonarqube` |
| `gpt56-compare-gpt54-zap` | ZAP baseline + API | `gpt54-gpt56env` | `Document/experiments/gpt-5.6-sol/normalized/gpt-5.4/zap` |
| `gpt56-compare-gpt54-jmeter` | JMeter matrix | `gpt54-gpt56env` | `Document/experiments/gpt-5.6-sol/normalized/gpt-5.4/jmeter` |
| `gpt56-compare-gpt55-sonar` | SonarQube | `financial-accounting-gpt55-gpt56env` | `Document/experiments/gpt-5.6-sol/normalized/gpt-5.5/sonarqube` |
| `gpt56-compare-gpt55-zap` | ZAP baseline + API | `gpt55-gpt56env` | `Document/experiments/gpt-5.6-sol/normalized/gpt-5.5/zap` |
| `gpt56-compare-gpt55-jmeter` | JMeter matrix | `gpt55-gpt56env` | `Document/experiments/gpt-5.6-sol/normalized/gpt-5.5/jmeter` |

For both Sonar worktrees, run:

```powershell
./scripts/phase4/run-sonarqube-scan.ps1 `
  -SonarToken $env:SONAR_TOKEN `
  -ProjectKey $sonarProjectKey `
  -ProjectName $sonarProjectKey `
  -ProjectVersion "$normalizedTag-1" `
  -SolutionPath "API/API.sln"
./scripts/phase4/get-sonar-summary.ps1 `
  -SonarToken $env:SONAR_TOKEN `
  -ProjectKey $sonarProjectKey |
  ConvertTo-Json -Depth 20 |
  Set-Content "$normalizedOutput/sonarqube-summary.json" -Encoding UTF8
```

Set `$sonarProjectKey`, `$normalizedTag`, and `$normalizedOutput` from the table and the target directory under `Document/experiments/gpt-5.6-sol/normalized/`.

For both ZAP worktrees, restore `financial-gpt56sol-clean.bak`, start and health-check that worktree’s API, then run:

```powershell
./scripts/phase4/run-zap-baseline.ps1 `
  -TargetUrl "http://localhost:5296" `
  -ReportDir $normalizedOutput `
  -OutputPrefix "zap-baseline-$normalizedTag" `
  -IgnoreWarnings
./scripts/phase4/run-zap-api.ps1 `
  -OpenApiUrl "http://localhost:5296/swagger/v1/swagger.json" `
  -BaseUrl "http://localhost:5296" `
  -Username "admin" `
  -Password "Admin@123" `
  -ApiVersion "1.0" `
  -ReportDir $normalizedOutput `
  -OutputPrefix "zap-api-$normalizedTag" `
  -IgnoreWarnings
```

For both JMeter worktrees, restore `financial-gpt56sol-clean.bak`, start and health-check that worktree’s API, then run:

```powershell
./scripts/phase4/run-jmeter-thesis-matrix.ps1 `
  -BaseUrl "http://localhost:5296" `
  -Username "admin" `
  -Password "Admin@123" `
  -ApiVersion "1.0" `
  -PeriodId 202601 `
  -AccountId 1 `
  -ResultsDir $normalizedOutput `
  -RunTag $normalizedTag
```

- [ ] **Step 3: Create the evidence-only comparison branch**

```powershell
git switch codex/gpt-5.6-sol-baseline
git switch -c codex/gpt-5.6-sol-comparison
```

- [ ] **Step 4: Copy normalized evidence into the comparison branch**

```powershell
$repoRoot = (git rev-parse --show-toplevel).Trim()
$destination = Join-Path $repoRoot "Document\experiments\gpt-5.6-sol\normalized"
New-Item -ItemType Directory -Force "$destination\gpt-5.4","$destination\gpt-5.5" | Out-Null
Copy-Item "$repoRoot\.worktrees\gpt56-compare-gpt54-sonar\Document\experiments\gpt-5.6-sol\normalized\gpt-5.4\sonarqube" "$destination\gpt-5.4\sonarqube" -Recurse -Force
Copy-Item "$repoRoot\.worktrees\gpt56-compare-gpt54-zap\Document\experiments\gpt-5.6-sol\normalized\gpt-5.4\zap" "$destination\gpt-5.4\zap" -Recurse -Force
Copy-Item "$repoRoot\.worktrees\gpt56-compare-gpt54-jmeter\Document\experiments\gpt-5.6-sol\normalized\gpt-5.4\jmeter" "$destination\gpt-5.4\jmeter" -Recurse -Force
Copy-Item "$repoRoot\.worktrees\gpt56-compare-gpt55-sonar\Document\experiments\gpt-5.6-sol\normalized\gpt-5.5\sonarqube" "$destination\gpt-5.5\sonarqube" -Recurse -Force
Copy-Item "$repoRoot\.worktrees\gpt56-compare-gpt55-zap\Document\experiments\gpt-5.6-sol\normalized\gpt-5.5\zap" "$destination\gpt-5.5\zap" -Recurse -Force
Copy-Item "$repoRoot\.worktrees\gpt56-compare-gpt55-jmeter\Document\experiments\gpt-5.6-sol\normalized\gpt-5.5\jmeter" "$destination\gpt-5.5\jmeter" -Recurse -Force
```

- [ ] **Step 5: Write these report sections**

```markdown
# GPT-5.4 vs GPT-5.5 vs GPT-5.6-sol

## Experimental Controls
## Branch and Commit Provenance
## Environment Identity
## SonarQube Results
## OWASP ZAP Results
## Apache JMeter Results
## Patch Size and Regression Tests
## Attempts, Time, and Human Intervention
## Residual Findings and Failed Gates
## Model Ranking by Tool
## Threats to Validity
## Conclusion
```

Rank models separately for SonarQube, ZAP, and JMeter. Do not collapse all tools into one score unless the report defines and justifies the weighting before seeing results.

- [ ] **Step 6: Validate, commit, and push**

```powershell
rg -n "7a0469d|GPT-5.4|GPT-5.5|GPT-5.6-sol" `
  Document/experiments/gpt-5.6-sol/gpt-5.4-gpt-5.5-gpt-5.6-sol.md
rg -n "TBD|TODO|PLACEHOLDER" `
  Document/experiments/gpt-5.6-sol/gpt-5.4-gpt-5.5-gpt-5.6-sol.md
git add Document/experiments/gpt-5.6-sol
git diff --cached --check
git commit -m "docs: compare GPT-5.4 GPT-5.5 and GPT-5.6-sol"
git push -u origin codex/gpt-5.6-sol-comparison
```

- [ ] **Step 7: Remove the six normalized-rerun worktrees**

After all normalized outputs are copied into the comparison branch:

```powershell
git worktree remove .worktrees/gpt56-compare-gpt54-sonar
git worktree remove .worktrees/gpt56-compare-gpt54-zap
git worktree remove .worktrees/gpt56-compare-gpt54-jmeter
git worktree remove .worktrees/gpt56-compare-gpt55-sonar
git worktree remove .worktrees/gpt56-compare-gpt55-zap
git worktree remove .worktrees/gpt56-compare-gpt55-jmeter
```

---

## Completion Gates

- [ ] The user explicitly authorized execution.
- [ ] GPT-5.6-sol began from `7a0469d`.
- [ ] GPT-5.6-sol was blinded from prior model fixes until branches froze.
- [ ] All before/after raw tool artifacts are retained.
- [ ] Database state and Docker image identity are controlled.
- [ ] All compared model branches were measured in the same environment.
- [ ] Attempts and interventions are reported honestly.
- [ ] Residual findings and failed gates remain visible.
