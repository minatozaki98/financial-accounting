# Financial Accounting API

Financial Accounting backend built with ASP.NET Core 8.0, JWT auth, role-based authorization, and EF Core.

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

## Apply Report Performance Indexes

After restoring an existing `Financial` database, apply the report indexes before starting the API or collecting performance measurements:

```powershell
sqlcmd -S localhost -d Financial -E -b -i Document/sql/performance_report_indexes.sql
```

The script runs both index creations in one transaction, fails if the expected tables are missing, and checks `sys.indexes` before each creation. It is safe to run again against the same restored database. Fresh databases created from `Document/sql/financial_accounting_schema.sql` receive the same indexes, and the EF Core model carries the matching definitions for `EnsureCreated` environments.

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
