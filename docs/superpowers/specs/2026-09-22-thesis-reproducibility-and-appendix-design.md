# Thesis Reproducibility and Appendix Design

## Purpose

Create a clean, examiner-facing repository path that can run the financial-accounting application and reproduce or inspect every result currently claimed by the thesis. Preserve the branch-isolated methodology, make setup and verification explicit, and prepare an appendix-ready evidence index that can later be inserted into the thesis DOCX.

This work treats repository cleanup as evidence preservation. Historical experiment branches and their exact commits are part of the research record and must not be collapsed, rebased, force-pushed, or deleted merely to make the Git graph look simpler.

## Source-of-Truth Boundary

At the start of this design, the current thesis document is:

- `Document/outputs/final-report-gpt55-comparison.docx`
- Matching rendered artifact: `Document/outputs/final-report-gpt55-comparison.pdf`

Despite the filename, the inspected DOCX currently presents the original Codex 5.4 branch-isolated study in its abstract, methodology, results, and conclusion. It claims results for SonarQube, OWASP ZAP, Apache JMeter, deterministic test data, automated regression checks, and a React/Vite demonstration client. The document currently has no thesis appendix containing runnable repository instructions.

Later GPT-5.4/GPT-5.5 and new-API v2 experiments are supplemental evidence. They must remain outside the main thesis appendix until the paper itself is deliberately updated to discuss them. Defense materials may refer to supplemental work only when clearly labeled as later evidence or future work.

The DOCX and PDF will not be edited during this implementation. The immediate appendix deliverable is Markdown plus machine-readable manifests designed for later insertion.

## Goals

1. Preserve exact provenance for every before-and-after result claimed in the current thesis.
2. Provide one canonical branch from which an examiner can build and run the integrated application.
3. Provide explicit setup for prerequisites, SQL schema, deterministic data, API, frontend, tests, and optional research tools.
4. Verify each historical evidence branch independently with the smallest relevant checks.
5. Rerun SonarQube, ZAP, and JMeter where the required local services are available, while distinguishing fresh reproduction results from historical thesis measurements.
6. Create an appendix-ready evidence matrix linking paper claims to exact branches, commits, source files, commands, archived artifacts, fresh verification results, and limitations.
7. Commit and push all intended work before removing obsolete local worktrees or branches.

## Non-Goals

- Do not edit the current thesis DOCX or PDF in this phase.
- Do not rewrite or replace historical thesis measurements with new numbers.
- Do not merge the isolated SonarQube, ZAP, and JMeter evidence branches into a single historical result.
- Do not claim that a successful build or test reproduces SonarQube, ZAP, or JMeter results.
- Do not include GPT-5.5 or new-API v2 results in the current-paper appendix unless the paper scope is updated later.
- Do not delete remote evidence branches.
- Do not commit secrets, live credentials, database contents, machine-specific caches, `bin/`, `obj/`, `node_modules/`, temporary reports, or unrelated document exports.

## Evidence Model

The repository will use three distinct evidence layers.

### Layer 1: Historical Measurement Evidence

This layer preserves the exact code and artifacts used for the numerical claims already present in the thesis.

| Evidence role | Git reference | Exact commit | Thesis claim |
|---|---|---|---|
| Common pre-fix baseline | `origin/baseline-v0.1` | `7a0469d9401a3061941b44fcd46b3beca1c9c729` | Baseline for all three isolated comparisons |
| SonarQube remediation | `origin/baseline-sonarqube-v1` | `a2279bcbdc20751529335cf72f8baac1bc6f994b` | Retained findings reduced from 28 to 0; gate remained OK |
| OWASP ZAP remediation | `origin/baseline-zap-v1` | `5f3bd3ccd9e0d460f52cac6a8a0d5fdceff1ce3d` | Gated High, Medium, and Low business-endpoint alerts cleared |
| JMeter remediation code | `origin/baseline-jmeter-v1` | `78b08b62570dcf6fe436354e8e6b770ab2074445` | Core and stress-profile latency improvements |
| JMeter evidence branch head | `origin/baseline-jmeter-v1` | `3c9392d8dcecf986da5438962e20c5d862e8be08` | Same tested code plus the comparison-report commit |

Annotated tags will be created only after verification and remote-ref confirmation. Proposed tag names are:

- `thesis-evidence/baseline-v0.1`
- `thesis-evidence/sonarqube-v1`
- `thesis-evidence/zap-v1`
- `thesis-evidence/jmeter-v1`

The tags supplement the branches; they do not replace or delete them.

### Layer 2: Integrated Demonstration

The integrated application lineage is `baseline-v0.2` and its descendants. It combines the three remediation streams, deterministic tooling, the React/Vite client, report artifacts, and later documentation.

A new canonical branch, `codex/thesis-reproducibility-v1`, will be created after the existing detached defense work and dirty report changes are classified and preserved. It will contain only the coherent, current integrated application, reproducibility tooling, appendix manifests, and intentionally retained thesis deliverables.

The integrated branch demonstrates that the final application works. It is not the source of the isolated before-and-after measurements unless a specific thesis claim explicitly names it.

### Layer 3: Supplemental Experiments

GPT-5.5 comparison branches, blinded v2 controllers, mutation-source branches, and raw new-API outputs will be catalogued as supplemental. Their status will be one of:

- `supplemental-verified`
- `supplemental-partial`
- `supplemental-archived`
- `not-in-current-paper`

These branches and artifacts will not be mixed into the primary appendix tables.

## Repository Architecture

The canonical branch will expose the following structure while reusing existing scripts where practical:

```text
README.md
docs/
  appendix/
    thesis-appendix-source-code-and-results.md
    thesis-evidence-manifest.json
    thesis-branch-register.md
    verification-runs/
scripts/
  thesis/
    Test-ThesisEnvironment.ps1
    Initialize-ThesisDatabase.ps1
    Invoke-ThesisDemo.ps1
    Invoke-ThesisVerification.ps1
  phase4/
    existing SonarQube, ZAP, JMeter, seed, and evidence scripts
API/
BAL/
MODEL/
tests/
WEB/
Document/
  performance/
  security/
  outputs/
```

Existing `scripts/phase4` commands remain the measurement implementation. The new `scripts/thesis` layer provides clean-clone orchestration, prerequisite checks, safe defaults, lifecycle management, and concise examiner output. It must call the phase-4 scripts rather than duplicate their analysis logic.

## Examiner Workflows

### Workflow A: Inspect the Historical Evidence

1. Open the appendix evidence matrix.
2. Select SonarQube, ZAP, or JMeter.
3. Read the baseline and remediation branch names and immutable commit identifiers.
4. Open the linked source files and archived result artifacts.
5. Review the documented command and the historical outcome.
6. Review the latest reproduction status separately.

No checkout mutation is required for this inspection path.

### Workflow B: Run the Integrated Application

1. Clone or check out `codex/thesis-reproducibility-v1`.
2. Run `Test-ThesisEnvironment.ps1`.
3. Run `Initialize-ThesisDatabase.ps1` to apply the checked-in SQL schema and deterministic seed data to a local `Financial` database.
4. Run `Invoke-ThesisDemo.ps1`.
5. The runner starts the API on port 5296, checks `/health/live` and `/health/ready`, starts the frontend on port 5173, and reports the local URLs.
6. The runner performs a bounded smoke check and prints explicit cleanup instructions or stops child processes that it owns.

The runner must fail before mutation if the database target is non-local, required commands are missing, or requested ports are already owned by unrelated processes.

### Workflow C: Run Fast Verification

`Invoke-ThesisVerification.ps1 -Mode Fast` will run:

- .NET restore/build with deterministic repository settings
- unit tests
- integration tests
- frontend unit tests
- frontend production build
- optional browser smoke test when the API and frontend are available

The output will be a timestamped Markdown and JSON run record containing the Git branch, commit, environment versions, command results, durations, and artifact paths.

### Workflow D: Run Full Research Verification

`Invoke-ThesisVerification.ps1 -Mode Full` will require Docker Desktop and a local SQL Server. It will:

1. Verify the exact checked-out branch and commit.
2. Verify or start the research tool containers through the existing phase-4 installer.
3. Initialize and seed the local database.
4. Start the API and verify readiness.
5. Run the relevant tests and coverage collection.
6. Run SonarQube when a token is supplied through a secure parameter or environment variable.
7. Run ZAP baseline and authenticated API scans.
8. Run JMeter p50, p100, p500, soak, and spike profiles.
9. Generate a timestamped evidence package.
10. Record failures, skipped gates, and environmental differences without overwriting historical artifacts.

Full verification is branch-specific. A wrapper may guide the operator through separate worktrees, but it must never switch a dirty checkout in place.

## Environment Contract

The environment checker will report, without printing secret values:

- Windows and PowerShell version
- Git version and clean/dirty checkout state
- current branch and commit
- .NET SDK required by `global.json`
- Node.js and npm versions
- Docker client and daemon availability
- SQL Server service/connectivity status
- `sqlcmd` availability
- availability of required ports 5296, 5173, 9000, 8080, 8088, and 8090
- presence of required source, schema, JMX, rule, and project files
- presence of a Sonar token without displaying it

The checked-in local connection string and demo credentials are development-only inputs. Runner logs and appendix files must redact password values and connection-string details beyond the local server/database identity.

## Database and Data Safety

`Initialize-ThesisDatabase.ps1` will use `Document/sql/financial_accounting_schema.sql` and `scripts/phase4/seed-test-data.ps1`.

Safety rules:

- Default target must resolve to local SQL Server and database `Financial`.
- A non-local server, alternate database, or explicit destructive reset requires a separate opt-in parameter.
- The ordinary path is idempotent schema creation and idempotent/upsert-style seed preparation.
- The runner must report the final account, journal-entry, posted-entry, user, and role counts.
- Database passwords and full connection strings must not be written to evidence artifacts.
- Existing data must not be dropped by default.

## Branch and Worktree Cleanup Policy

Cleanup will follow a manifest-first sequence:

1. Fetch and record current remote refs.
2. Inventory every local branch, remote branch, tag, worktree, dirty file, and unreachable commit relevant to the thesis.
3. Rescue the detached final-defense lineage onto a named branch before any cleanup.
4. Classify current uncommitted files as canonical source, generated deliverable, historical evidence, duplicate, supplemental, or discardable cache.
5. Commit coherent changes in narrow commits.
6. Push the canonical branch, preserved work branches, and approved evidence tags.
7. Verify local and remote object identifiers match.
8. Remove only clean, fully preserved worktrees.
9. Delete only local branches that are both recoverable from a verified remote/tag and no longer needed by a registered worktree.
10. Leave remote evidence branches intact.

No cleanup command may use `git reset --hard`, `git clean`, broad recursive deletion, or a computed path that has not been resolved and checked under the repository worktree directory.

## Appendix Evidence Contract

`docs/appendix/thesis-appendix-source-code-and-results.md` will be structured for later conversion into a thesis appendix.

### Appendix A: Repository and Environment

- repository URL
- canonical demonstration branch and commit
- platform and prerequisite versions
- setup and startup commands
- database initialization and deterministic seed parameters

### Appendix B: Branch and Commit Provenance

- exact baseline and remediation refs
- commit identifiers
- purpose of each branch
- before/after relationship
- annotated evidence tags

### Appendix C: Source-Code Evidence

- SonarQube controller/request-model remediation
- ZAP security-header and Swagger hardening
- JMeter report-generation, indexing, caching, and write-amplification remediation
- file paths and compact before/after references

### Appendix D: Commands and Test Profiles

- build and automated-test commands
- SonarQube command and required token boundary
- ZAP baseline and authenticated scan commands
- JMeter p50, p100, p500, soak, and spike commands
- frontend and browser demonstration commands

### Appendix E: Result Traceability

Each result row will contain:

| Field | Meaning |
|---|---|
| Paper location | Chapter, section, table, or figure in the current DOCX |
| Claim | Exact bounded claim made by the thesis |
| Baseline ref | Branch/tag and commit |
| After ref | Branch/tag and commit |
| Source files | Files responsible for the change |
| Historical artifacts | Existing reports that support the published number |
| Reproduction command | Command used for a fresh run |
| Fresh status | Pass, fail, partial, skipped, or environment-blocked |
| Difference note | Why a fresh value may differ from the historical value |
| Limitation | Scope boundary or unresolved condition |

### Appendix F: Working Application Demonstration

- API and frontend startup
- health/readiness results
- role-based demo accounts with password omitted from the document
- screen-to-endpoint mapping
- browser smoke-test result

### Appendix G: Known Limitations

- one codebase and one primary model configuration
- local machine and SQL Server dependence
- Docker/tool-version drift
- performance sensitivity to machine state and dataset state
- unresolved mixed-workload soak/spike drift heuristic
- supplemental GPT-5.5/v2 work excluded from the current-paper results

## Historical Versus Fresh Results

Historical and fresh measurements will never occupy the same unlabelled column.

- `Historical result` means the number already reported in the thesis and backed by the preserved branch/artifact.
- `Fresh reproduction result` means a new run performed during consolidation.
- `Verification pass` means the relevant command completed and satisfied its current gate.
- `Not reproduced` means the tool or environment was unavailable or the exact historical environment could not be reconstructed.

A fresh mismatch does not automatically invalidate the historical result. It triggers an investigation of code ref, tool version, database contents, configuration, host conditions, and measurement rules. The appendix records the discrepancy and does not conceal it.

## Failure Handling

All orchestration scripts will:

- stop on unexpected command failure
- preserve the first causal error and the path to its log
- return a non-zero exit code for failed required gates
- distinguish `FAIL`, `PARTIAL`, `SKIPPED`, and `ENVIRONMENT_BLOCKED`
- clean up only processes and temporary resources created by that run
- leave historical evidence untouched
- avoid displaying secret parameter values

The full runner will not convert missing Docker, missing Sonar credentials, unavailable SQL Server, or an occupied port into a false pass.

## Verification Strategy

Verification is proportional and layered.

### Documentation and Manifest Checks

- Markdown links resolve to versioned repository paths.
- Every primary thesis claim has at least one evidence row.
- Every evidence row has an exact commit identifier.
- JSON manifests parse successfully.
- No unresolved placeholder markers remain.
- `git diff --check` passes.

### Script Tests

- Pester tests cover prerequisite detection, path resolution, ref validation, redaction, port ownership handling, and exit-status classification.
- Dry-run modes prove intended commands without starting tools or altering data.
- Failure-path tests verify that missing Docker, SQL, source files, or credentials produce explicit statuses.

### Application Checks

- solution build
- unit tests
- integration tests
- frontend tests
- frontend build
- API health and readiness
- browser smoke path through login, dashboard, reports, audit logs, and role restrictions

### Research-Tool Checks

- SonarQube is measured only after analyzer completion and quality-gate retrieval.
- ZAP uses the versioned baseline/API rule files and records High, Medium, Low, and Informational results separately.
- JMeter records the exact profile, dataset, branch, commit, JTL/statistics paths, p95/p99, throughput, error rate, and drift calculation.
- Historical acceptance rules remain visible even if a fresh runner later gains stricter gates.

## Implementation Boundaries

The first implementation slice will establish manifests, safe environment validation, database initialization, and fast verification. Full Docker-based scans and multi-branch replay follow only after the fast path is green. Branch deletion or worktree removal is the final slice, never the first.

The implementation must preserve the primary dirty checkout and the detached final-defense worktree until their contents are committed and their remote recovery paths are verified.

## Acceptance Criteria

The consolidation is complete only when:

1. A named canonical branch is pushed and can be cloned independently.
2. The detached defense lineage and intended report changes are no longer reachable only from local worktrees.
3. Every current-paper result maps to exact refs, source files, commands, artifacts, and a fresh verification status.
4. A clean local setup can initialize the database, build the backend and frontend, run automated tests, start the application, and complete the browser smoke path.
5. SonarQube, ZAP, and JMeter are either freshly rerun with recorded results or explicitly marked environment-blocked with no false completion claim.
6. Historical result numbers remain unchanged and clearly separated from fresh reruns.
7. Primary evidence branches remain available remotely and have immutable evidence tags.
8. Only clean, recoverable local worktrees and branches are removed.
9. The appendix Markdown and JSON manifest are ready for later DOCX insertion without another repository audit.
10. The primary checkout, report artifacts, camera-ready manuscript, databases, and unrelated user work are preserved.
