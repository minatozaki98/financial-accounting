# SonarQube Issue Fixes

## Fix Log

| # | Issue ID | Severity | Type | File | Line | Description | Fix Applied |
|---|----------|----------|------|------|------|-------------|-------------|
| 1 | CS8618 | Warning | Bug | MODEL/DataContext.cs | 8 | `DbSet` properties were reported as non-nullable members without initialization across 14 findings. | Replaced the settable `DbSet` properties with expression-bodied `Set<T>()` accessors so EF Core exposes initialized sets without nullability warnings. |
| 2 | S125 | Warning | Code Smell | MODEL/DataContext.cs | 38 | Commented-out entity configuration reduced readability. | Removed the dead commented configuration block from the `Users` entity mapping. |
| 3 | S6966 | Warning | Code Smell | API/Program.cs | 188 | The application entrypoint should await shutdown asynchronously. | Changed `app.Run()` to `await app.RunAsync()`. |
| 4 | S1118 | Warning | Code Smell | API/Program.cs | 190 | The `Program` partial type used for tests should not be an instantiable utility shell. | Added a protected constructor to the partial `Program` type. |
| 5 | S1118 | Warning | Code Smell | BAL/Shared/ServiceManager.cs | 15 | `ServiceManager` only exposes static behavior. | Converted `ServiceManager` to a `static` class and removed unused imports. |
| 6 | S107 | Warning | Code Smell | API/Controllers/JournalEntriesController.cs | 62 | The journal entry paging action exposed too many query parameters directly. | Introduced `JournalEntryQueryDto` and bound the endpoint with a single `[FromQuery]` object. |
| 7 | S107 | Warning | Code Smell | BAL/IServices/IJournalEntryService.cs | 10 | The journal entry service paging contract exposed too many parameters. | Updated the service contract to accept `JournalEntryQueryDto`. |
| 8 | S1192 | Warning | Code Smell | BAL/Services/JournalEntryService.cs | 29, 51, 225 | Repeated `"Draft"`, `"Posted"`, and `"JournalEntries"` literals reduced maintainability. | Extracted shared status and entity-name constants and reused them throughout the service. |
| 9 | CA1862 | Note | Code Smell | BAL/Services/FinancialAuthService.cs | 130 | Case-insensitive role matching used string normalization. | Switched to `StringComparison.OrdinalIgnoreCase` after materializing the small role list, which keeps the comparison clear without breaking EF translation. |
| 10 | S3260 | Warning | Code Smell | BAL/Services/FinancialReportService.cs | 317 | `AccountAggregate` is private and not inherited. | Marked the nested `AccountAggregate` type as `sealed`. |
| 11 | xUnit1042 | Note | Code Smell | tests/FinancialAccounting.IntegrationTests/RbacMatrixTests.cs | 35 | `MemberData` returned untyped rows. | Replaced the row factory with `TheoryData<string, string>` for typed theory data. |
| 12 | CA1861 | Note | Code Smell | tests/FinancialAccounting.IntegrationTests/RbacMatrixTests.cs | 46 | Inline constant arrays were recreated for status assertions. | Hoisted the allowed close statuses into a static readonly array. |
| 13 | CA1861 | Note | Code Smell | tests/FinancialAccounting.UnitTests/FinancialTokenProviderTests.cs | 37 | Inline constant arrays were recreated for token-role input. | Hoisted the token roles into a static readonly array. |
| 14 | S117 | Minor | Code Smell | API/Properties/ServiceDependencies/crc-api-test - Web Deploy/profile.arm.json | 38-39 | ARM variables did not follow the project naming convention. | Renamed ARM variables to camelCase and updated all usages. |
| 15 | S6975 | Major | Code Smell | API/Properties/ServiceDependencies/crc-api-test - Web Deploy/profile.arm.json | 46-53 | ARM resource elements were not in the Azure-recommended order. | Reordered the resource properties to `type`, `apiVersion`, `name`, `location/dependsOn`, `resourceGroup`, and `properties` order expected by Sonar. |
| 16 | S117 / S6975 / S6952 | Minor / Major / Critical | Code Smell | API/Properties/ServiceDependencies/crc-api-test - Zip Deploy/profile.arm.json | 42-50, 89-131 | The ZIP deploy ARM template used non-camelCase variables, non-recommended resource ordering, and a redundant explicit dependency. | Renamed ARM variables to camelCase, reordered the deployment resources to the Azure-recommended layout, and removed the redundant explicit dependency from the subscription-scope deployment resource. |

## Results After Fix

### Baseline C# Findings

The baseline C# Sonar issue files stored under `.sonarqube/out/0-4/Issues.json` contained **28 findings** before the fixes.  
After the final rerun on **March 23, 2026** (`ProjectVersion 1.1.3`), the regenerated `.sonarqube/out/0-4/Issues.json` files contain **0 findings**.

### SonarQube Dashboard Comparison

Comparison from SonarQube measure history:

| Metric | Before (`1.0.20260323012156`) | After (`1.1.3`) | Change |
|--------|-------------------------------|-----------------|--------|
| Bugs | 0 | 0 | 0 |
| Vulnerabilities | 0 | 0 | 0 |
| Code Smells | 21 | 0 | -21 |
| Security Hotspots | 0 | 0 | 0 |
| Quality Gate | n/a in retained baseline event payload | OK | Passed |

### Current SonarQube State

- Quality Gate: `OK`
- Remaining issues: `0`
- Coverage: `74.3%`
- Duplicated lines density: `0.0%`

## Verification Evidence

- `dotnet test API/API.sln`
  - Passed: 98 tests total
- `./scripts/phase4/run-sonarqube-scan.ps1 -SonarToken <local-token> -ProjectVersion 1.1.3`
  - Build succeeded
  - Unit and integration tests passed during analysis
  - SonarQube dashboard updated successfully
