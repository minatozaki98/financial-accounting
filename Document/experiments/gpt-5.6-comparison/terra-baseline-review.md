Actual sequence:

1. Resolves or globally installs `dotnet-sonarscanner` and `dotnet-coverage`.
2. Resolves paths and checks the solution plus both test projects exist.
3. Creates/reuses `.tmp/sonar/coverage` and `test-results`.
4. Runs `SonarScanner begin`, configuring one static project key and two expected coverage XML paths.
5. Builds the entire solution in `Debug`.
6. Runs unit tests with `--no-build`, collecting coverage and a TRX file.
7. Runs integration tests with `--no-build`, collecting coverage and a TRX file.
8. Always runs `SonarScanner end` in `finally`, uploading analysis even if build or either test/coverage run failed.
9. Only after the upload, throws if the build/test block did not fully complete.

Key comparability risks:

- `ProjectVersion` is timestamp-based, so every scan is labelled uniquely; it is not a stable benchmark version.
- The static `ProjectKey` means repeated runs publish into the same Sonar project. Unless branch/PR parameters are supplied elsewhere, results are compared against whatever analysis and “new code” baseline Sonar currently has.
- No source revision, branch, commit SHA, or dirty-worktree state is captured. You cannot establish that two scans assessed the same code.
- Global tools may be auto-installed at different versions. Scanner, coverage collector, .NET SDK/runtime, SonarQube server, plugins, and quality profiles can all alter findings or coverage.
- `Debug` is an explicit measurement choice. Conditional compilation, generated output, analyzers, and test behavior may differ from Release/CI.
- Artifact directories are reused rather than cleaned. A failed coverage run can leave an old XML report available for a later upload, creating misleading coverage evidence.
- Integration tests are environment-dependent: database state, services, credentials, timing, network, and parallel activity can change both execution and coverage.
- `sonar.scanner.scanAll=false` constrains scope to MSBuild-discovered content. This may omit non-.NET or otherwise untracked source files; scope must be held constant between scans.
- TRX files are created but not configured for Sonar ingestion. The scan can report coverage while lacking Sonar-visible test-execution evidence.
- The `finally` block uploads partial analysis after a failed build or test collection. Worse, if `end` also fails, its error may obscure the original failure.

Before treating findings as remediation input, capture:

- Exact Git remote, branch, commit SHA, submodule state, and whether the worktree was dirty.
- Full invocation and resolved absolute paths; all effective parameters, especially configuration and Sonar URL/project key.
- Exact versions of .NET SDK, scanner, coverage tool, SonarQube server/edition, installed plugins, quality profile/rule-set versions, and relevant analyzer packages.
- Sonar project state before and after: branch context, new-code definition, quality gate, exclusions/inclusions, prior analysis identifier/date, and Compute Engine task status.
- Build output and outcome; each test command, TRX result, discovered/passed/failed/skipped counts, duration, and integration-environment identity/state.
- Both coverage XML files’ creation timestamps, hashes, size, parse validity, and summary totals. Confirm they were produced by this run and map to the intended source paths.
- Scanner begin/end logs and the resulting Sonar analysis/task ID.
- An export of candidate issues with rule key, message, severity/type, file and line, effort estimate, status, tags, quality-profile origin, and whether each is new versus existing.

The script can produce a useful scan, but it is not yet a defensible benchmark record. Its largest methodological flaws are unpinned tooling, reused artifacts, missing source/environment provenance, and uploading after failed measurement steps.