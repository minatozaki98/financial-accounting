# Final paired SonarQube run record

- Date: 2026-07-29 (Asia/Bangkok)
- Final paired scan completed: 2026-07-29T16:43:19.8533026Z
- SonarQube: 26.7.0.124771 in a temporary isolated `sonarqube:community` container
- Scanner: SonarScanner for .NET 11.1
- Profile: the same fresh default profile on the same newly created server for both candidates
- Temporary server: removed after the evidence export; the pre-existing port-9000 server was not changed

## Model/candidate provenance

- GPT-5.4: controller-assigned GPT-5.4 remediation candidate at clean commit `33ec4293653874baaeff07a1a4b23a78112f33ff`
- GPT-5.5: correction task `019faeb2-c4e6-7a13-9e4a-3eb3779408c0`, explicitly configured as `gpt-5.5` with `xhigh` reasoning; source HEAD `59e2e3d73172fd4aef8814573bde8af96c7d1f74` plus measured correction patch SHA-256 `C36914B1183C514ADF09B711E9EDD2815CC1C186C43353DC507D7D996EA524AB`
- SonarQube, `dotnet build`, and `dotnet test` measure source code and do not invoke either model.

## GPT-5.5 correction

Changed files:

- `API/SonarChallenge/SonarChallengeRequestInspector.cs`
- `BAL/Services/JournalImportService.cs`
- `BAL/Services/SonarChallengeReconciliationAnalyzer.cs`
- `MODEL/SonarChallenge/SonarChallengeLedgerProjection.cs`

Verification performed by the GPT-5.5 task:

- `dotnet test .\API\API.sln -c Debug --nologo`: passed (9 unit, 139 integration)
- `dotnet build .\API\API.sln -c Release --nologo`: passed (0 warnings, 0 errors)
- `git diff --check`: passed

## Final paired measurement

- GPT-5.4: Quality Gate OK, 0 issues, 76.2% coverage, 0 bugs, 0 code smells, reliability 1.0
- GPT-5.5: Quality Gate OK, 0 issues, 74.8% coverage, 0 bugs, 0 code smells, reliability 1.0
- Fresh measurement tests: GPT-5.4 passed 9 unit and 140 integration tests; GPT-5.5 passed 9 unit and 139 integration tests
- Remaining SonarQube findings: none for either candidate

## Run notes

- Two launcher/exporter corrections were made before the accepted paired run: Windows PowerShell required an instance RNG API, and SonarScanner for .NET 11.1 exposed the CE task identifier in `scanner-end.log` rather than a retained `report-task.txt`.
- The failed launch/export attempts did not produce an accepted comparison result. The final results above came from one new isolated server and the same end-to-end scan sequence for both candidates.
- No source changes were committed.
