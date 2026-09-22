# Thesis Appendix Source: Code, Tools, Dashboards, and Results

This Markdown file is the controlled source for later insertion into the thesis DOCX. It does not modify the current paper. Historical measurements and fresh reproduction results are deliberately separated.

## Appendix A - Repository and Environment

- Repository: `https://github.com/minatozaki98/financial-accounting`
- Canonical branch: `codex/thesis-reproducibility-v1`
- Thesis model identity: `gpt-5.4`
- Current paper source: `Document/outputs/final-report-gpt55-comparison.docx`
- Required platform: Windows, PowerShell, .NET, Node.js/npm, local SQL Server; Docker for the full research-tool gate

Quick start:

```powershell
./scripts/thesis/Test-ThesisEnvironment.ps1 -Mode Fast
./scripts/thesis/Initialize-ThesisDatabase.ps1
./scripts/thesis/Invoke-ThesisVerification.ps1 -Mode Fast
./scripts/thesis/Invoke-ThesisDemo.ps1 -KeepRunning
```

## Appendix B - Branch and Commit Provenance

| Evidence role | Reference | Exact commit |
|---|---|---|
| baseline | `origin/baseline-v0.1` | `7a0469d9401a3061941b44fcd46b3beca1c9c729` |
| sonarqube-remediation | `origin/baseline-sonarqube-v1` | `a2279bcbdc20751529335cf72f8baac1bc6f994b` |
| zap-remediation | `origin/baseline-zap-v1` | `5f3bd3ccd9e0d460f52cac6a8a0d5fdceff1ce3d` |
| jmeter-remediation | `origin/baseline-jmeter-v1` | `3c9392d8dcecf986da5438962e20c5d862e8be08 (tested code: 78b08b62570dcf6fe436354e8e6b770ab2074445)` |

## Appendix C - Selected Source-Code Evidence

### 4.2 / Table 4.2: sonarqube-primary

Historical result: 28 retained findings to 0; Quality Gate OK; coverage 74.3%; duplication 0.0%

Source files:
- [`API/Controllers/JournalEntriesController.cs`](../../API/Controllers/JournalEntriesController.cs)
- [`API/Program.cs`](../../API/Program.cs)
- [`BAL/Services/JournalEntryService.cs`](../../BAL/Services/JournalEntryService.cs)
- [`Document/sonarqube-fixes.md`](../../Document/sonarqube-fixes.md)

Historical artifacts:
- [`Document/sonarqube-fixes.md`](../../Document/sonarqube-fixes.md)
- [`Document/outputs/final-report-gpt55-comparison.docx`](../../Document/outputs/final-report-gpt55-comparison.docx)

### 4.3: zap-primary

Historical result: gated High, Medium, and Low business-endpoint alerts cleared

Source files:
- [`API/Middleware/SecurityHeadersMiddleware.cs`](../../API/Middleware/SecurityHeadersMiddleware.cs)
- [`API/Program.cs`](../../API/Program.cs)
- [`scripts/phase4/zap-baseline-rules.tsv`](../../scripts/phase4/zap-baseline-rules.tsv)
- [`scripts/phase4/zap-api-rules.tsv`](../../scripts/phase4/zap-api-rules.tsv)
- [`Document/zap-fixes.md`](../../Document/zap-fixes.md)

Historical artifacts:
- [`Document/security/zap-baseline-20260222-230133.html`](../../Document/security/zap-baseline-20260222-230133.html)
- [`Document/security/zap-baseline-20260222-230133.json`](../../Document/security/zap-baseline-20260222-230133.json)
- [`Document/security/zap-baseline-20260324-000724.html`](../../Document/security/zap-baseline-20260324-000724.html)
- [`Document/security/zap-baseline-20260324-000724.json`](../../Document/security/zap-baseline-20260324-000724.json)
- [`Document/security/zap-api-20260222-230133.html`](../../Document/security/zap-api-20260222-230133.html)
- [`Document/security/zap-api-20260222-230133.json`](../../Document/security/zap-api-20260222-230133.json)
- [`Document/security/zap-api-20260324-000856.html`](../../Document/security/zap-api-20260324-000856.html)
- [`Document/security/zap-api-20260324-000856.json`](../../Document/security/zap-api-20260324-000856.json)

### 4.4 / Table 4.4: jmeter-primary

Historical result: p50, p100, and p500 p95 improved; soak/spike improved with drift caveat

Source files:
- [`BAL/Services/FinancialReportService.cs`](../../BAL/Services/FinancialReportService.cs)
- [`BAL/Shared/AccountLedgerCache.cs`](../../BAL/Shared/AccountLedgerCache.cs)
- [`BAL/Shared/SqlServerPerformanceIndexStartup.cs`](../../BAL/Shared/SqlServerPerformanceIndexStartup.cs)
- [`Document/performance/jmeter/financial-api-load-test.jmx`](../../Document/performance/jmeter/financial-api-load-test.jmx)
- [`Document/performance/jmeter/financial-api-soak-test.jmx`](../../Document/performance/jmeter/financial-api-soak-test.jmx)
- [`Document/performance/jmeter/financial-api-spike-test.jmx`](../../Document/performance/jmeter/financial-api-spike-test.jmx)

Historical artifacts:
- [`Document/baseline-comparison-report.md`](../../Document/baseline-comparison-report.md)
- [`Document/jmeter-fixes.md`](../../Document/jmeter-fixes.md)
- [`Document/performance/thesis-evidence-20260222-231435.md`](../../Document/performance/thesis-evidence-20260222-231435.md)
- [`Document/performance/thesis-evidence-20260222-231435.csv`](../../Document/performance/thesis-evidence-20260222-231435.csv)
- [`Document/performance/thesis-baseline-anchor.json`](../../Document/performance/thesis-baseline-anchor.json)

### 3.2 / Tables 3.7-3.8: deterministic-data

Historical result: 120 accounts, 30000 journal entries, at least 5000 posted entries

Source files:
- [`Document/sql/financial_accounting_schema.sql`](../../Document/sql/financial_accounting_schema.sql)
- [`scripts/phase4/seed-test-data.ps1`](../../scripts/phase4/seed-test-data.ps1)

Historical artifacts:
- [`Document/performance/thesis-evidence-20260222-231435.md`](../../Document/performance/thesis-evidence-20260222-231435.md)
- [`Document/performance/test-summary-20260222-231435.md`](../../Document/performance/test-summary-20260222-231435.md)

### 3.1.1 and 3.5: automated-regression

Historical result: unit, integration, RBAC, and coverage checks support non-regression

Source files:
- [`tests/FinancialAccounting.UnitTests/FinancialAccounting.UnitTests.csproj`](../../tests/FinancialAccounting.UnitTests/FinancialAccounting.UnitTests.csproj)
- [`tests/FinancialAccounting.IntegrationTests/FinancialAccounting.IntegrationTests.csproj`](../../tests/FinancialAccounting.IntegrationTests/FinancialAccounting.IntegrationTests.csproj)

Historical artifacts:
- [`Document/performance/test-results-unit-20260222-231435/unit-20260222-231435.trx`](../../Document/performance/test-results-unit-20260222-231435/unit-20260222-231435.trx)
- [`Document/performance/test-results-integration-20260222-231435/integration-20260222-231435.trx`](../../Document/performance/test-results-integration-20260222-231435/integration-20260222-231435.trx)
- [`Document/performance/test-summary-20260222-231435.md`](../../Document/performance/test-summary-20260222-231435.md)

### 4.6 / Figures 4.1-4.7: working-application

Historical result: React/Vite client demonstrates current role-aware API workflows

Source files:
- [`WEB/package.json`](../../WEB/package.json)
- [`WEB/src/App.tsx`](../../WEB/src/App.tsx)
- [`WEB/src/lib/api.ts`](../../WEB/src/lib/api.ts)
- [`WEB/tests/e2e/research-demo.spec.ts`](../../WEB/tests/e2e/research-demo.spec.ts)

Historical artifacts:
- [`Document/outputs/web-app-evidence/01-login.png`](../../Document/outputs/web-app-evidence/01-login.png)
- [`Document/outputs/web-app-evidence/02-dashboard-admin.png`](../../Document/outputs/web-app-evidence/02-dashboard-admin.png)
- [`Document/outputs/web-app-evidence/03-reports-trial-balance.png`](../../Document/outputs/web-app-evidence/03-reports-trial-balance.png)
- [`Document/outputs/web-app-evidence/04-audit-logs.png`](../../Document/outputs/web-app-evidence/04-audit-logs.png)
- [`Document/outputs/web-app-evidence/05-auditor-role-view.png`](../../Document/outputs/web-app-evidence/05-auditor-role-view.png)
- [`Document/outputs/web-app-evidence/06-research-evidence.png`](../../Document/outputs/web-app-evidence/06-research-evidence.png)
- [`Document/outputs/web-app-evidence/07-journal-entry-details.png`](../../Document/outputs/web-app-evidence/07-journal-entry-details.png)

## Appendix D - Reproduction Commands and Profiles

```powershell
# SonarQube (use a secure process-local SONAR_TOKEN)
./scripts/phase4/run-sonarqube-scan.ps1 -SonarToken $env:SONAR_TOKEN -ProjectKey <role-specific-key> -SolutionPath API/API.csproj
# OWASP ZAP baseline and authenticated API scans
./scripts/phase4/run-zap-baseline.ps1 -TargetUrl http://localhost:5296/health/live -OutputPrefix <run-id>
./scripts/phase4/run-zap-api.ps1 -OpenApiUrl http://localhost:5296/swagger/v1/swagger.json -BaseUrl http://localhost:5296 -Username admin -Password <process-local-demo-password> -OutputPrefix <run-id>
# JMeter p50, p100, p500, soak, and spike
./scripts/phase4/run-jmeter-thesis-matrix.ps1 -BaseUrl http://localhost:5296 -Username admin -Password <process-local-demo-password> -PeriodId 202601 -AccountId 1
```

## Appendix E - Result Traceability

| Claim | Paper location | Historical result | Fresh reproduction result |
|---|---|---|---|
| sonarqube-primary | 4.2 / Table 4.2 | 28 retained findings to 0; Quality Gate OK; coverage 74.3%; duplication 0.0% | PASS: baseline 17 issues, remediation 0 issues; gates OK/OK |
| zap-primary | 4.3 | gated High, Medium, and Low business-endpoint alerts cleared | PASS: baseline raw alerts passive M3/L6, API M1/L3; remediation raw alerts passive M0/L0, API M1/L0 |
| jmeter-primary | 4.4 / Table 4.4 | p50, p100, and p500 p95 improved; soak/spike improved with drift caveat | PASS: p50 p95 33->199.9 ms; p100 255.9->1146.9; p500 106->1547.95; soak 443.95->171; spike 33401.75->4730.85 |
| deterministic-data | 3.2 / Tables 3.7-3.8 | 120 accounts, 30000 journal entries, at least 5000 posted entries | PASS |
| automated-regression | 3.1.1 and 3.5 | unit, integration, RBAC, and coverage checks support non-regression | PASS |
| working-application | 4.6 / Figures 4.1-4.7 | React/Vite client demonstrates current role-aware API workflows | PASS |

## Appendix F - Research-Tool Dashboards and Results

### SonarQube Dashboards

#### baseline-overview

![Dashboard: baseline-overview](dashboards/sonarqube/sonarqube-baseline-overview.png)

Classification: `fresh-reproduction`; role: `baseline`; branch: `origin/baseline-v0.1`; commit: `7a0469d9`; run: `20260922-183352`; tool version: `26.7.0.124771`; source: [`docs/appendix/verification-runs/research/sonar/baseline/summary.json`](../../docs/appendix/verification-runs/research/sonar/baseline/summary.json).

#### baseline-issues

![Dashboard: baseline-issues](dashboards/sonarqube/sonarqube-baseline-issues.png)

Classification: `fresh-reproduction`; role: `baseline`; branch: `origin/baseline-v0.1`; commit: `7a0469d9`; run: `20260922-183352`; tool version: `26.7.0.124771`; source: [`docs/appendix/verification-runs/research/sonar/baseline/summary.json`](../../docs/appendix/verification-runs/research/sonar/baseline/summary.json).

#### remediation-overview

![Dashboard: remediation-overview](dashboards/sonarqube/sonarqube-remediation-overview.png)

Classification: `fresh-reproduction`; role: `remediation`; branch: `origin/baseline-sonarqube-v1`; commit: `a2279bcb`; run: `20260922-183352`; tool version: `26.7.0.124771`; source: [`docs/appendix/verification-runs/research/sonar/remediation/summary.json`](../../docs/appendix/verification-runs/research/sonar/remediation/summary.json).

#### remediation-issues

![Dashboard: remediation-issues](dashboards/sonarqube/sonarqube-remediation-issues.png)

Classification: `fresh-reproduction`; role: `remediation`; branch: `origin/baseline-sonarqube-v1`; commit: `a2279bcb`; run: `20260922-183352`; tool version: `26.7.0.124771`; source: [`docs/appendix/verification-runs/research/sonar/remediation/summary.json`](../../docs/appendix/verification-runs/research/sonar/remediation/summary.json).

### OWASP ZAP Dashboards

#### baseline-before-summary

![Dashboard: baseline-before-summary](dashboards/zap/zap-baseline-before-summary.png)

Classification: `rendered-historical`; role: `baseline`; branch: `origin/baseline-v0.1`; commit: `7a0469d9`; run: `20260222-230133`; tool version: `2.17.0`; source: [`Document/security/zap-baseline-20260222-230133.json`](../../Document/security/zap-baseline-20260222-230133.json).

#### baseline-after-summary

![Dashboard: baseline-after-summary](dashboards/zap/zap-baseline-after-summary.png)

Classification: `rendered-historical`; role: `remediation`; branch: `origin/baseline-zap-v1`; commit: `5f3bd3cc`; run: `20260324-000724`; tool version: `2.17.0`; source: [`Document/security/zap-baseline-20260324-000724.json`](../../Document/security/zap-baseline-20260324-000724.json).

#### api-before-summary

![Dashboard: api-before-summary](dashboards/zap/zap-api-before-summary.png)

Classification: `rendered-historical`; role: `baseline`; branch: `origin/baseline-v0.1`; commit: `7a0469d9`; run: `20260222-230133`; tool version: `2.17.0`; source: [`Document/security/zap-api-20260222-230133.json`](../../Document/security/zap-api-20260222-230133.json).

#### api-after-summary

![Dashboard: api-after-summary](dashboards/zap/zap-api-after-summary.png)

Classification: `rendered-historical`; role: `remediation`; branch: `origin/baseline-zap-v1`; commit: `5f3bd3cc`; run: `20260324-000856`; tool version: `2.17.0`; source: [`Document/security/zap-api-20260324-000856.json`](../../Document/security/zap-api-20260324-000856.json).

### Apache JMeter Dashboards

#### baseline-p50-dashboard

![Dashboard: baseline-p50-dashboard](dashboards/jmeter/jmeter-baseline-p50-dashboard.png)

Classification: `fresh-reproduction`; role: `baseline`; branch: `origin/baseline-v0.1`; commit: `7a0469d9`; run: `baseline-20260922-192730`; tool version: `5.5`; source: [`docs/appendix/verification-runs/research/jmeter/baseline/report-baseline-20260922-192730-p50/statistics.json`](../../docs/appendix/verification-runs/research/jmeter/baseline/report-baseline-20260922-192730-p50/statistics.json).

#### baseline-p100-dashboard

![Dashboard: baseline-p100-dashboard](dashboards/jmeter/jmeter-baseline-p100-dashboard.png)

Classification: `fresh-reproduction`; role: `baseline`; branch: `origin/baseline-v0.1`; commit: `7a0469d9`; run: `baseline-20260922-192730`; tool version: `5.5`; source: [`docs/appendix/verification-runs/research/jmeter/baseline/report-baseline-20260922-192730-p100/statistics.json`](../../docs/appendix/verification-runs/research/jmeter/baseline/report-baseline-20260922-192730-p100/statistics.json).

#### baseline-p500-dashboard

![Dashboard: baseline-p500-dashboard](dashboards/jmeter/jmeter-baseline-p500-dashboard.png)

Classification: `fresh-reproduction`; role: `baseline`; branch: `origin/baseline-v0.1`; commit: `7a0469d9`; run: `baseline-20260922-192730`; tool version: `5.5`; source: [`docs/appendix/verification-runs/research/jmeter/baseline/report-baseline-20260922-192730-p500/statistics.json`](../../docs/appendix/verification-runs/research/jmeter/baseline/report-baseline-20260922-192730-p500/statistics.json).

#### baseline-soak-dashboard

![Dashboard: baseline-soak-dashboard](dashboards/jmeter/jmeter-baseline-soak-dashboard.png)

Classification: `fresh-reproduction`; role: `baseline`; branch: `origin/baseline-v0.1`; commit: `7a0469d9`; run: `baseline-20260922-192730`; tool version: `5.5`; source: [`docs/appendix/verification-runs/research/jmeter/baseline/report-baseline-20260922-192730-soak/statistics.json`](../../docs/appendix/verification-runs/research/jmeter/baseline/report-baseline-20260922-192730-soak/statistics.json).

#### baseline-spike-dashboard

![Dashboard: baseline-spike-dashboard](dashboards/jmeter/jmeter-baseline-spike-dashboard.png)

Classification: `fresh-reproduction`; role: `baseline`; branch: `origin/baseline-v0.1`; commit: `7a0469d9`; run: `baseline-20260922-192730`; tool version: `5.5`; source: [`docs/appendix/verification-runs/research/jmeter/baseline/report-baseline-20260922-192730-spike/statistics.json`](../../docs/appendix/verification-runs/research/jmeter/baseline/report-baseline-20260922-192730-spike/statistics.json).

#### remediation-p50-dashboard

![Dashboard: remediation-p50-dashboard](dashboards/jmeter/jmeter-remediation-p50-dashboard.png)

Classification: `fresh-reproduction`; role: `remediation`; branch: `origin/baseline-jmeter-v1`; commit: `78b08b62`; run: `remediation-20260922-200712`; tool version: `5.5`; source: [`docs/appendix/verification-runs/research/jmeter/remediation/report-remediation-20260922-200712-p50/statistics.json`](../../docs/appendix/verification-runs/research/jmeter/remediation/report-remediation-20260922-200712-p50/statistics.json).

#### remediation-p100-dashboard

![Dashboard: remediation-p100-dashboard](dashboards/jmeter/jmeter-remediation-p100-dashboard.png)

Classification: `fresh-reproduction`; role: `remediation`; branch: `origin/baseline-jmeter-v1`; commit: `78b08b62`; run: `remediation-20260922-200712`; tool version: `5.5`; source: [`docs/appendix/verification-runs/research/jmeter/remediation/report-remediation-20260922-200712-p100/statistics.json`](../../docs/appendix/verification-runs/research/jmeter/remediation/report-remediation-20260922-200712-p100/statistics.json).

#### remediation-p500-dashboard

![Dashboard: remediation-p500-dashboard](dashboards/jmeter/jmeter-remediation-p500-dashboard.png)

Classification: `fresh-reproduction`; role: `remediation`; branch: `origin/baseline-jmeter-v1`; commit: `78b08b62`; run: `remediation-20260922-200712`; tool version: `5.5`; source: [`docs/appendix/verification-runs/research/jmeter/remediation/report-remediation-20260922-200712-p500/statistics.json`](../../docs/appendix/verification-runs/research/jmeter/remediation/report-remediation-20260922-200712-p500/statistics.json).

#### remediation-soak-dashboard

![Dashboard: remediation-soak-dashboard](dashboards/jmeter/jmeter-remediation-soak-dashboard.png)

Classification: `fresh-reproduction`; role: `remediation`; branch: `origin/baseline-jmeter-v1`; commit: `78b08b62`; run: `remediation-20260922-200712`; tool version: `5.5`; source: [`docs/appendix/verification-runs/research/jmeter/remediation/report-remediation-20260922-200712-soak/statistics.json`](../../docs/appendix/verification-runs/research/jmeter/remediation/report-remediation-20260922-200712-soak/statistics.json).

#### remediation-spike-dashboard

![Dashboard: remediation-spike-dashboard](dashboards/jmeter/jmeter-remediation-spike-dashboard.png)

Classification: `fresh-reproduction`; role: `remediation`; branch: `origin/baseline-jmeter-v1`; commit: `78b08b62`; run: `remediation-20260922-200712`; tool version: `5.5`; source: [`docs/appendix/verification-runs/research/jmeter/remediation/report-remediation-20260922-200712-spike/statistics.json`](../../docs/appendix/verification-runs/research/jmeter/remediation/report-remediation-20260922-200712-spike/statistics.json).

## Appendix G - Working Application Demonstration

- API live and ready endpoints: True / True
- Frontend smoke result: True
- Demonstrated areas: login, role-aware navigation, accounts, journal lines, periods, reports, audit logs, user administration, and research evidence.
- Demo credentials are local-only and intentionally omitted from this appendix source.

## Appendix H - Known Limitations

- The current paper evaluates one ASP.NET Core financial-accounting API and attributes remediation evidence to GPT-5.4.
- GPT-5.5 and new-API v2 work is supplemental and is not current-paper evidence.
- Fresh SonarQube, ZAP, and JMeter values can differ because of tool versions, host load, database state, and runtime conditions.
- The current local database exceeds the paper minimum dataset, so performance reruns must record their actual counts or use an isolated clean local database.
- Mixed-workload soak/spike drift remains a documented limitation.
- A dashboard screenshot is accepted only when its manifest links it to the same run and machine-readable source artifact.
