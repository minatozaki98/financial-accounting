# Phase 4 Tooling Setup (SonarQube, OWASP ZAP, JMeter)

This repository now has runnable setup and execution scripts for all three tools.

## 1) SonarQube Setup

### Start tool containers (or refresh images)
```powershell
./scripts/phase4/install-tools.ps1
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
  -TargetUrl "http://localhost:5296/swagger"
```

Config file used:
- `scripts/phase4/zap-baseline-rules.tsv`

Reports output:
- `Document/security/zap-baseline.html`
- `Document/security/zap-baseline.json`
- `Document/security/zap-baseline.md`

## 3) Apache JMeter Setup

### Test plan file
- `Document/performance/jmeter/financial-api-load-test.jmx`

### Run direct with custom values
```powershell
./scripts/phase4/run-jmeter.ps1 `
  -TestPlanPath "Document/performance/jmeter/financial-api-load-test.jmx" `
  -Users 50 -RampUp 30 -Loops 10 `
  -BaseUrl "http://localhost:5296" `
  -Username "admin" -Password "Admin@123"
```

### Run thesis profiles (50/100/500 users)
```powershell
./scripts/phase4/run-jmeter-profile.ps1 -Profile 50
./scripts/phase4/run-jmeter-profile.ps1 -Profile 100
./scripts/phase4/run-jmeter-profile.ps1 -Profile 500
```

Outputs:
- JTL result files under `Document/performance`
- HTML reports under `Document/performance/report-*`
