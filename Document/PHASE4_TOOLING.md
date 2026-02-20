# Phase 4 Tooling Setup (SonarQube, OWASP ZAP, JMeter)

This repository now has runnable setup and execution scripts for all three tools.

## 1) SonarQube Setup

### Start tool containers (or refresh images)
```powershell
./scripts/phase4/install-tools.ps1
```

This starts persistent containers for all tools:
- SonarQube: `http://localhost:9000`
- ZAP Web UI: `http://localhost:8080/zap`
- ZAP API/proxy: `http://localhost:8090`
- JMeter report UI: `http://localhost:8088`

You can change ZAP/JMeter ports:
```powershell
./scripts/phase4/install-tools.ps1 `
  -ZapWebPort 8081 `
  -ZapApiPort 8091 `
  -JMeterPort 8092
```

If you need to fully reset SonarQube (back to default `admin/admin`), run:
```powershell
./scripts/phase4/install-tools.ps1 -ResetSonarData
```

If SonarQube shows a banner like "version ... is no longer active", you are running an old image.
Run a reset (or recreate) so Docker starts the newer `sonarqube:community` image:
```powershell
./scripts/phase4/install-tools.ps1 -ResetSonarData
```

### Upgrade from SonarQube 9.9.x (Docker)

If you are currently on **Community Edition v9.9.x** and want the latest Community Build in Docker:

1) If you do NOT need to keep existing SonarQube data (recommended for local/dev):
```powershell
./scripts/phase4/install-tools.ps1 -ResetSonarData
```

2) If you DO need to keep existing SonarQube data (volumes), upgrade in steps:
```powershell
# 9.9.x -> 24.12 (required)
./scripts/phase4/install-tools.ps1 -RecreateSonar -SonarImage "sonarqube:24.12.0.100206-community"

# 24.12 -> a 2025.x version (avoid 25.12 due to known upgrade issues)
./scripts/phase4/install-tools.ps1 -RecreateSonar -SonarImage "sonarqube:25.11.0.114957-community"

# 2025.x -> 26.1 (required cutoff for upgrades to later 2026 releases)
./scripts/phase4/install-tools.ps1 -RecreateSonar -SonarImage "sonarqube:26.1.0.118079-community"

# 26.1 -> latest
./scripts/phase4/install-tools.ps1 -RecreateSonar -SonarImage "sonarqube:community"
```

### Bootstrap SonarQube project
```powershell
./scripts/phase4/setup-sonarqube.ps1 `
  -ProjectKey "financial-accounting" `
  -ProjectName "Financial Accounting" `
  -GenerateToken
```

Notes:
- SonarQube URL: `http://localhost:9000`
- Default container: `financial-sonarqube`
- Default ZAP container: `financial-zap`
- Default JMeter container: `financial-jmeter`
- Save the generated token immediately (shown once).
- If your admin password is not `Admin@123456`, pass `-AdminPassword "<yourPassword>"` (or use `-AdminToken "<token>"`).
- After `-ResetSonarData`, SonarQube starts with the default password `admin`. Either change it in the UI, or run:
  - `./scripts/phase4/setup-sonarqube.ps1 -AdminPassword "admin" -NewAdminPassword "Admin@123456" -GenerateToken`

### Run .NET Sonar scan
```powershell
./scripts/phase4/run-sonarqube-scan.ps1 `
  -SonarToken "<YOUR_TOKEN>" `
  -SolutionPath "API/API.csproj"
```

Note: the first run installs the `dotnet-sonarscanner` global tool from NuGet (requires internet access).

## 2) OWASP ZAP Setup

### Baseline scan with project rules
```powershell
./scripts/phase4/run-zap-baseline.ps1 `
  -TargetUrl "http://localhost:5296/swagger" `
  -OutputPrefix "zap-baseline-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
```

Notes:
- Persistent ZAP GUI container is available at `http://localhost:8080/zap` (or your custom `-ZapWebPort`).
- ZAP API/proxy is exposed on `http://localhost:8090` (or your custom `-ZapApiPort`).
- The baseline/API scan scripts still use isolated scan runs to keep report generation deterministic.
- If the script exits with code `2`, that means ZAP found warnings (reports are still generated).
- To force exit code `0` while keeping warnings in the report, add `-IgnoreWarnings`.
- Use `-OutputPrefix` to avoid overwriting previous report files.

Config file used:
- `scripts/phase4/zap-baseline-rules.tsv`

Reports output:
- `Document/security/<outputPrefix>.html`
- `Document/security/<outputPrefix>.json`
- `Document/security/<outputPrefix>.md`

### Authenticated OpenAPI scan (business routes)
```powershell
./scripts/phase4/run-zap-api.ps1 `
  -OpenApiUrl "http://localhost:5296/swagger/v1/swagger.json" `
  -BaseUrl "http://localhost:5296" `
  -Username "admin" -Password "Admin@123" `
  -OutputPrefix "zap-api-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
```

Notes:
- Logs in first to obtain a JWT token and injects it into API scan requests.
- Runs pre-checks for expected `401/403` on protected/admin endpoints.
- Uses API-specific rule profile: `scripts/phase4/zap-api-rules.tsv`.

## 3) Apache JMeter Setup

### Test plan file
- `Document/performance/jmeter/financial-api-load-test.jmx`

### Run direct with custom values
```powershell
./scripts/phase4/run-jmeter.ps1 `
  -TestPlanPath "Document/performance/jmeter/financial-api-load-test.jmx" `
  -Users 50 -RampUp 30 -Loops 10 `
  -Mode "core" -CoreUsers 50 -ComplexUsers 0 `
  -AccountId 1 -PeriodId 202601 `
  -BaseUrl "http://localhost:5296" `
  -Username "admin" -Password "Admin@123"
```

Notes:
- Persistent JMeter container serves `Document/performance` on `http://localhost:8088` (or your custom `-JMeterPort`).
- JMeter execution scripts still run isolated test executions for reproducible `.jtl` and HTML artifacts.
- The script auto-maps `localhost`/`127.0.0.1` to `host.docker.internal` so the container can reach your host API.
- Make sure your API is listening on `0.0.0.0:5296` (not only `localhost`) before running JMeter:
  - `dotnet run --project API/API.csproj --urls http://0.0.0.0:5296 --environment Development`

### Run thesis profiles (50/100/500 users)
```powershell
./scripts/phase4/run-jmeter-profile.ps1 -Profile 50
./scripts/phase4/run-jmeter-profile.ps1 -Profile 100
./scripts/phase4/run-jmeter-profile.ps1 -Profile 500
```

Profile behavior:
- `50`: core flow only (`mode=core`, `coreUsers=50`, `complexUsers=0`)
- `100`: mixed flow (`mode=mixed`, `coreUsers=70`, `complexUsers=30`)
- `500`: mixed flow (`mode=mixed`, `coreUsers=350`, `complexUsers=150`)

Outputs:
- JTL result files under `Document/performance`
- HTML reports under `Document/performance/report-*`

## 4) Data Bootstrap for Thesis Runs

```powershell
./scripts/phase4/seed-test-data.ps1 `
  -PeriodId 202601 `
  -AccountCount 120 `
  -JournalEntryCount 30000 `
  -MinimumPostedEntries 5000
```

This script ensures:
- admin user (`admin`) exists with the provided password.
- roles and role mappings are available (`Admin`, `FinanceManager`).
- the target accounting period exists and is open.
- account volume and journal entry targets are met.

## 5) One-Command Thesis Suite

```powershell
./scripts/phase4/run-thesis-suite.ps1 `
  -BaseUrl "http://localhost:5296" `
  -OpenApiUrl "http://localhost:5296/swagger/v1/swagger.json"
```

This suite runs:
1. data bootstrap
2. ZAP baseline scan
3. ZAP authenticated OpenAPI scan
4. JMeter profiles 50/100/500
5. summary generation in `Document/performance/test-summary-<timestamp>.md`

Baseline anchor (first full suite run):
- `Document/performance/thesis-baseline-anchor.json`

## 6) Runtime Metrics Collection

```powershell
./scripts/phase4/collect-runtime-metrics.ps1 `
  -OutputPath "Document/performance/runtime-metrics-manual.csv" `
  -DurationSeconds 900 `
  -IntervalSeconds 5
```

Outputs:
- CSV samples for CPU and memory trends used by reliability gates.

## 7) JMeter Thesis Matrix Runner

```powershell
./scripts/phase4/run-jmeter-thesis-matrix.ps1 `
  -BaseUrl "http://localhost:5296" `
  -Username "admin" -Password "Admin@123" `
  -PeriodId 202601 -AccountId 1
```

This runner executes:
- profile 50
- profile 100
- profile 500
- soak plan (`financial-api-soak-test.jmx`)
- spike plan (`financial-api-spike-test.jmx`)

## 8) Sonar Summary Parser

```powershell
./scripts/phase4/get-sonar-summary.ps1 `
  -SonarToken "<YOUR_TOKEN>" `
  -ProjectKey "financial-accounting"
```

Outputs:
- quality gate status + key measures for thesis reporting.

## 9) Evidence Generator

```powershell
./scripts/phase4/generate-thesis-evidence.ps1 -RunId "<RUN_ID>"
```

Outputs:
- `Document/performance/thesis-evidence-<RUN_ID>.md`
- `Document/performance/thesis-evidence-<RUN_ID>.csv`
