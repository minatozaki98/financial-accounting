# GPT-5.6 Luna Sonar Evidence

Date: 2026-11-21 (Asia/Bangkok)

## Source change

Applied exactly the 9 edits in `../luna-sonar-attempt1.json` to the Luna checkout. The six touched source files compare to `../shared-baseline` with only those requested replacements; existing CRLF line endings were preserved.

## Tests

- Unit suite: `FinancialAccounting.UnitTests` — 2 total, 2 passed, 0 failed; exit code 0.
- Integration suite: `FinancialAccounting.IntegrationTests` — 96 total, 96 passed, 0 failed; exit code 0.
- Test result files: `.tmp/luna-tests/unit/luna-unit.trx` and `.tmp/luna-tests/integration/luna-integration.trx`.

## SonarQube

- Scanner: `scripts/phase4/run-sonarqube-scan.ps1`, local SDK `9.0.308`, SonarQube `http://localhost:19061`.
- Project key: `fa-56-luna`.
- Client log: `luna-sonar-scan.log` — analysis uploaded successfully; post-processing succeeded.
- Server task: `51c9a162-3c2a-4573-b8b9-bd31ab9dde59` — `SUCCESS`.
- Quality gate: `OK`.
- Server measures: bugs 0, vulnerabilities 0, code smells 0, coverage 74.4%, duplicated lines density 0.0%, reliability rating 1.0, security rating 1.0, maintainability rating 1.0.
- Dashboard: http://localhost:19061/dashboard?id=fa-56-luna

Coverage artifacts are under `.tmp/sonar/coverage/`, with unit and integration TRX files under `.tmp/sonar/test-results/`.
