# Financial Accounting API

Financial Accounting backend built with ASP.NET Core 8.0, JWT auth, role-based authorization, and EF Core.

## GPT-5.4 Thesis Reproducibility

This repository preserves the branch-isolated evidence for the GPT-5.4 thesis study. Historical measurements remain tied to the exact baseline, SonarQube, OWASP ZAP, and JMeter commits recorded in [`docs/appendix/thesis-evidence-manifest.json`](docs/appendix/thesis-evidence-manifest.json). Fresh runs are reproduction evidence and do not overwrite or silently replace the historical thesis numbers.

Run the read-only prerequisite audit:

```powershell
./scripts/thesis/Test-ThesisEnvironment.ps1 -Mode Fast
```

Initialize the local `Financial` SQL Server database and deterministic minimum dataset:

```powershell
./scripts/thesis/Initialize-ThesisDatabase.ps1
```

The initializer refuses non-local SQL targets by default and does not drop existing data. Use `-WhatIf` to inspect the target without changing it.

Start and verify the integrated API and web demonstration:

```powershell
./scripts/thesis/Invoke-ThesisDemo.ps1 -KeepRunning
```

The default URLs are `http://localhost:5296` and `http://localhost:5173`. If a port belongs to another process, the runner reports its PID and stops without killing it; choose an alternate port such as `-WebPort 5175`.

Run the reproducible fast gate:

```powershell
./scripts/thesis/Invoke-ThesisVerification.ps1 -Mode Fast
```

The fast gate runs the Release build, unit tests, integration tests, frontend clean install, frontend tests, and frontend production build. Docker-based SonarQube, ZAP, and JMeter verification is a separate full gate because it requires live tool containers, a running API, and longer branch-specific executions.

Appendix source and evidence are under [`docs/appendix/`](docs/appendix/). The thesis DOCX is intentionally not modified by these runners.

Verified consolidation status (22 September 2026):

- 62 thesis-tooling Pester tests passed.
- Canonical Release build, 6 unit tests, and 107 integration tests passed.
- 13 frontend tests, the alternate-port live browser workflow, and the frontend production build passed.
- All four exact evidence refs built and passed their available unit/integration suites.
- Fresh SonarQube, ZAP, and ten-profile JMeter evidence is recorded without replacing historical results.
- All 18 required SonarQube/ZAP/JMeter dashboard images are present and hash-validated.

See [`docs/appendix/thesis-appendix-source-code-and-results.md`](docs/appendix/thesis-appendix-source-code-and-results.md) for the Appendix A-H source and [`docs/appendix/thesis-branch-register.md`](docs/appendix/thesis-branch-register.md) for retained branches, tags, and cleanup status.

Never place Sonar tokens, passwords, authorization headers, full connection strings, or browser profiles in Git. Supply secrets through process-local parameters or environment variables; generated records redact credential-shaped values and Windows user-profile paths.

## Solution Layout

- `API/` - ASP.NET Core Web API host and controllers
- `BAL/` - service layer (business logic)
- `MODEL/` - entities, DTOs, DbContext, configuration models
- `scripts/phase4/` - thesis tooling scripts (seed, security, performance, quality)
- `tests/` - unit and integration test projects
- `Document/` - generated security/performance/quality artifacts

## Prerequisites

- .NET SDK 8.0+
- SQL Server (local or remote)
- Docker Desktop (for ZAP/JMeter/Sonar containers)
- PowerShell 7+ or Windows PowerShell

## Run API Locally

```powershell
dotnet run --project API/API.csproj --urls http://0.0.0.0:5296 --environment Development
```

Health endpoints:

- `GET /health/live`
- `GET /health/ready`

## Run Research Web App Locally

The React/Vite web app in `WEB/` demonstrates the current API surface for the final report research.

```powershell
./scripts/phase4/seed-test-data.ps1
dotnet run --project API/API.csproj --urls http://0.0.0.0:5296 --environment Development
cd WEB
npm install
npm run dev
```

Open `http://localhost:5173`.

Demo users:

- `admin / Admin@123`
- `finance-manager / Admin@123`
- `normal-user / Admin@123`
- `auditor-user / Admin@123`

Frontend checks:

```powershell
cd WEB
npm test
npm run build
npm run test:e2e
$env:RUN_LIVE_E2E="1"; npm run test:e2e
```

The live e2e command expects the API to be running at `http://localhost:5296` with seed data loaded.

## Test and Quality Commands

### Start Persistent Tool Containers

```powershell
./scripts/phase4/install-tools.ps1
```

Default localhost endpoints:

- SonarQube: `http://localhost:9000`
- ZAP GUI: `http://localhost:8080/zap`
- ZAP API/proxy: `http://localhost:8090`
- JMeter report UI: `http://localhost:8088`

Custom ZAP/JMeter ports:

```powershell
./scripts/phase4/install-tools.ps1 -ZapWebPort 8081 -ZapApiPort 8091 -JMeterPort 8092
```

### Unit + Integration Tests (with coverage)

```powershell
dotnet test tests/FinancialAccounting.UnitTests/FinancialAccounting.UnitTests.csproj --collect:"XPlat Code Coverage"
dotnet test tests/FinancialAccounting.IntegrationTests/FinancialAccounting.IntegrationTests.csproj --collect:"XPlat Code Coverage"
```

### SonarQube Scan

```powershell
./scripts/phase4/run-sonarqube-scan.ps1 -SonarToken "<YOUR_TOKEN>" -SolutionPath "API/API.csproj"
```

### ZAP Security Scans

```powershell
./scripts/phase4/run-zap-baseline.ps1 -TargetUrl "http://localhost:5296/swagger" -OutputPrefix "zap-baseline-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

./scripts/phase4/run-zap-api.ps1 -OpenApiUrl "http://localhost:5296/swagger/v1/swagger.json" -BaseUrl "http://localhost:5296" -Username "admin" -Password "Admin@123" -OutputPrefix "zap-api-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
```

### JMeter Thesis Matrix (50/100/500 + soak + spike)

```powershell
./scripts/phase4/run-jmeter-thesis-matrix.ps1 -BaseUrl "http://localhost:5296" -Username "admin" -Password "Admin@123" -PeriodId 202601 -AccountId 1
```

## Full Thesis Suite (One Command)

```powershell
./scripts/phase4/run-thesis-suite.ps1 -BaseUrl "http://localhost:5296" -OpenApiUrl "http://localhost:5296/swagger/v1/swagger.json" -SonarToken "<YOUR_TOKEN>"
```

This command runs:

1. deterministic seed data
2. unit and integration tests + coverage checks
3. ZAP baseline + authenticated API scan
4. JMeter profile + soak + spike matrix
5. runtime metrics collection
6. thesis summary and baseline anchor generation

Generate thesis evidence package from a completed run:

```powershell
./scripts/phase4/generate-thesis-evidence.ps1 -RunId "<RUN_ID>"
```

Outputs:

- `Document/performance/test-summary-<RUN_ID>.md`
- `Document/performance/thesis-evidence-<RUN_ID>.md`
- `Document/performance/thesis-evidence-<RUN_ID>.csv`
