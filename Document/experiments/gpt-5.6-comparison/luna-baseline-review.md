## Actual sequencing

1. Parses parameters and defaults.
2. Resolves or installs `dotnet-sonarscanner` and `dotnet-coverage`.
   - Missing tools are installed from the current/latest global-tool source.
3. Resolves all paths relative to the current working directory.
4. Validates the solution and both test projects.
5. Creates artifact directories, but does not clean them.
6. Runs SonarScanner `begin`.
7. Builds the solution once in the selected configuration, normally `Debug`.
8. Runs unit tests under coverage.
9. Runs integration tests under coverage.
10. Runs SonarScanner `end` in `finally`, even when build or test execution fails.
11. Throws afterward if build/tests/coverage did not all complete.

`$buildSucceeded` is therefore misnamed: it becomes true only after the build and both coverage runs succeed.

## Important execution risks

- The coverage command is constructed as one string:

  ```powershell
  $coverageCommand = "dotnet test ... "
  & $coverageToolPath collect $coverageCommand -f xml -o ...
  ```

  `dotnet-coverage collect` normally expects the executable and its arguments separately. This may pass the entire string as the command name instead of executing `dotnet` with arguments. The intended test execution must be confirmed from the actual tool output; do not assume coverage was collected.

- `dotnet test --no-build` assumes the earlier solution build produced all required test binaries. This fails or becomes misleading if the solution excludes either test project or uses different target frameworks/configuration.

- `dotnet test` can still restore dependencies because `--no-restore` is not specified. The run may therefore change assets or resolve different package content than a prior run.

- The `finally` block runs Sonar `end` after a failed build or failed test. Sonar may upload a partial analysis, possibly using stale coverage files.

- Artifact files are not deleted first. Existing `unit-coverage.xml` or `integration-coverage.xml` can survive a failed collection and be consumed by Sonar.

- A failure in the `end` step can obscure the original build or test failure.

- The script depends on the current working directory. Running it from another directory changes the meaning of every relative path.

## Comparability risks

Findings should not be compared across runs until these conditions are captured and shown equivalent:

- Source identity: commit SHA, branch, dirty/uncommitted changes, and repository path.
- Sonar identity: server version, scanner version, installed analyzer/plugin versions, active quality profile, rule configuration, exclusions, new-code definition, and quality-gate settings.
- Toolchain: OS, .NET SDK/runtime versions, `global.json`, package lock/assets state, and project target frameworks.
- Script inputs: exact parameter values, especially configuration, project key, Sonar URL, solution path, and project version.
- Test population: test counts, passed/failed/skipped counts, test filters, test ordering, retries, and generated test data.
- Integration dependencies: database/service versions, seed data, environment variables, external service availability, and timezone/locale.
- Coverage scope: whether unit and integration tests overlap in the same production code, whether both reports were generated successfully, and how Sonar merged them.
- Analysis scope: `sonar.scanner.scanAll=false` and any other scope or exclusion differences.
- Versioning: `ProjectVersion` changes on every run, so it is not a source baseline. The timestamped version must not be treated as proof that the code changed.

The largest comparability concern is that this script can produce a Sonar analysis with different tools, dependencies, environment state, test execution, or stale coverage while appearing to be the same project scan.

## Evidence to capture before remediation

Preserve the raw run evidence before changing source code:

- Full console output for tool resolution, `begin`, build, both test runs, and `end`.
- Exit status for each command.
- Exact commit SHA, branch, repository status, and diff summary.
- Exact script parameters and working directory.
- `dotnet --info`, SDK/runtime versions, scanner version, and coverage-tool version.
- Sonar server/analyzer versions, analysis ID/task ID, quality profile, quality gate, and new-code definition.
- `.trx` files and their test totals: passed, failed, skipped, and discovered.
- Coverage XML files, their existence timestamps, sizes, hashes, and summary coverage values.
- Confirmation that coverage files were newly generated rather than inherited from a prior run.
- Build warnings/errors and Sonar warnings about missing or unreadable coverage.
- The complete pre-remediation issue export: issue key, rule, severity, type, component, line, status, message, effort, and remediation guidance.
- Baseline measures: lines/branches covered, duplications, reliability/security ratings, maintainability rating, and analyzed lines.

Bottom line: the script’s intended order is sensible—begin, build, test with coverage, end—but the coverage invocation, stale-artifact behavior, floating tool installation, and unconditional `end` step make the resulting findings unsafe to use for remediation until the run’s actual execution and evidence are verified.