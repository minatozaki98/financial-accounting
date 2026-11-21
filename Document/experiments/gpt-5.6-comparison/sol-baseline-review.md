The script performs one sequential scan, but it does not create a clean, reproducible benchmark by itself.

## Actual sequencing

1. Resolves `dotnet-sonarscanner` and `dotnet-coverage`.
   - Uses whatever version is already installed.
   - If absent, installs the latest available global-tool version.
2. Resolves all input paths relative to the current working directory.
3. Checks only that the solution and two test project paths exist.
4. Creates artifact directories with `-Force`; it does not clean previous results.
5. Runs SonarScanner `begin`.
6. Builds the solution in the selected configuration.
7. Runs unit tests under `dotnet-coverage`.
8. Runs integration tests under `dotnet-coverage`.
9. Runs SonarScanner `end` unconditionally through `finally`.
10. Prints completion only if the preceding operations and `end` return successfully.

Important consequences:

- Unit and integration tests are sequential, not parallel.
- Integration tests never run if the unit coverage command fails.
- `end` runs even after build or test failure, so an incomplete analysis can still be submitted.
- Existing coverage files are not removed first. If a coverage run fails before replacing its XML, `end` could potentially consume an older file.
- If both the main operation and the `end` step fail, the `end` failure may obscure the original build/test failure.
- `$buildSucceeded` is misnamed: it becomes true only after the build and both coverage runs succeed. Its final check is mostly redundant because tracked failures already throw.
- `--no-build` assumes the solution build produced everything needed by both test projects. That is only safe if both projects and their required configuration are actually included in the solution build.

## Comparability risks

These scans should not be compared until the following variables are controlled.

### Source identity

The script does not record:

- Commit SHA
- Branch
- Dirty/untracked working-tree state
- Submodule state
- Generated or locally modified files

The timestamp-based `ProjectVersion` is not source identity. Two runs of identical source receive different versions, while two different dirty working trees could appear to represent the same repository commit.

### Toolchain drift

It neither pins nor records:

- SonarScanner version
- `dotnet-coverage` version
- .NET SDK/runtime details
- OS and architecture
- SonarQube server version
- Installed C# analyzer/plugin version

“Install if missing” makes a fresh machine especially non-comparable because it obtains whatever global-tool release is current at execution time.

### Sonar configuration drift

The same source can produce different findings when any of these change:

- Quality profile and activated rule versions
- Rule parameters and severity overrides
- Analysis exclusions
- Coverage exclusions
- New Code definition and baseline
- Server/plugin upgrades
- Branch or pull-request analysis mode
- Project-level settings

Using the same `ProjectKey` does not isolate benchmark runs; it updates the same Sonar project history.

### Analysis scope

`sonar.scanner.scanAll=false` is a material scope choice. Comparisons with default `scanAll` behavior or a different scan configuration may contain different file sets.

The script should not be assumed to scan every repository file merely because it builds the solution. Findings are bounded by the projects/files visible to the scanner and its exclusions.

### Build and dependency state

The script does not explicitly perform or capture a clean restore. Results may depend on:

- Existing `bin` and `obj` contents
- NuGet cache state
- Lock files and resolved dependency versions
- Conditional build properties
- Environment variables
- Locally installed workloads
- Warnings or generated-code differences

A successful incremental Debug build is not necessarily comparable to a clean build or Release analysis.

### Test and coverage conditions

Coverage depends on more than source:

- Whether both test projects are built by the solution
- Test filters and run settings
- Data, database schema and seed state
- External services
- Environment-specific skipped tests
- Flaky or order-dependent tests
- Instrumentation/tool version
- Processes or child processes included in coverage

The two coverage reports are supplied to Sonar, but the TRX reports are not configured as Sonar test-execution reports. Therefore, Sonar coverage measures alone do not prove how many tests passed, failed, or were skipped.

### Artifact contamination

The artifact directory is reused and never cleared. Stable filenames such as:

- `unit-coverage.xml`
- `integration-coverage.xml`
- `unit.trx`
- `integration.trx`

create a risk of mixing current and previous-run evidence, especially when a run terminates early.

## Capture before using findings for remediation

Before changing source, preserve an immutable benchmark receipt containing:

- Commit SHA, branch, remote URL and complete working-tree status
- Patch or diff for all tracked modifications
- Inventory or archive of relevant untracked/generated source
- Exact invocation and all effective parameters, excluding the token
- Start/end timestamps and timezone
- Project key, project version, configuration and resolved absolute paths
- Sonar analysis ID/task ID, dashboard URL and compute-engine status
- Quality profile name and revision/export
- Quality gate and New Code definition
- Effective inclusions, exclusions and coverage exclusions
- SonarQube server and analyzer/plugin versions
- SonarScanner and `dotnet-coverage` versions
- Complete `dotnet --info` output
- Dependency/restore evidence and applicable lock files
- Full build log, including warnings
- Unit and integration TRX files
- Passed, failed and skipped counts for each test suite
- Both coverage XML files and their hashes
- Logs showing whether each coverage file was newly generated
- Integration-test environment identity and sanitized database/seed version
- Exported issue set containing issue key, rule, severity, file, line, message, status and scope
- Baseline measures: bugs, vulnerabilities, security hotspots, code smells, duplication and coverage
- Explicit confirmation that the background Sonar task completed successfully

Do not treat “SonarScanner end returned zero” or “scan completed” as sufficient evidence. The server processes analysis asynchronously; the compute-engine result must be checked.

Most importantly, freeze the issue export and environment receipt before remediation. Otherwise, later rule-profile changes, line movement, server upgrades, or overwritten project history can make it impossible to distinguish a genuine source improvement from benchmark drift.