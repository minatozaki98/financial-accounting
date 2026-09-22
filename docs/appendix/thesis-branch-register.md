# Thesis Branch Register

## Current-paper evidence

| Role | Remote reference | Commit | Retention rule |
|---|---|---|---|
| Common pre-fix baseline | `origin/baseline-v0.1` | `7a0469d9401a3061941b44fcd46b3beca1c9c729` | Preserved by branch and `thesis-evidence/baseline-v0.1` |
| SonarQube remediation | `origin/baseline-sonarqube-v1` | `a2279bcbdc20751529335cf72f8baac1bc6f994b` | Preserved by branch and `thesis-evidence/sonarqube-v1` |
| OWASP ZAP remediation | `origin/baseline-zap-v1` | `5f3bd3ccd9e0d460f52cac6a8a0d5fdceff1ce3d` | Preserved by branch and `thesis-evidence/zap-v1` |
| JMeter remediation | `origin/baseline-jmeter-v1` | `3c9392d8dcecf986da5438962e20c5d862e8be08` | Preserved by branch and `thesis-evidence/jmeter-v1`; tested code is `78b08b62570dcf6fe436354e8e6b770ab2074445` |

## Working branches preserved before consolidation

| Purpose | Branch | Remote commit | Status |
|---|---|---|---|
| Final defense package | `origin/codex/final-thesis-defense` | `42c27760db11aa16ba4c9dbf6460459792653efc` | Pushed; 29 tests and package validator passed before commit |
| Report working artifacts | `origin/codex/thesis-report-working-20260922` | `f36f6f0cf9fc8fbdffd4feef3ef81930cccd8ff1` | Pushed checkpoint; excluded duplicate defense outputs, camera-ready copy, and supplemental experiment directory |
| Canonical reproducibility implementation | `origin/codex/thesis-reproducibility-v1` | Pushed through `48dce2b5aa644d7a4781abb1c7638c6fc0c09e10` before the final handoff commit | Final branch contains the runnable tooling, manifests, Appendix A-H source, compact fresh evidence, and 18 dashboards |

## Fresh verification completed on 22 September 2026

| Verification | Result |
|---|---|
| Canonical fast gate | PASS: Release build, 6 unit tests, 107 integration tests, frontend clean install, 10 frontend tests, frontend production build |
| Baseline ref | PASS: 0 build warnings/errors, 2 unit tests, 96 integration tests |
| SonarQube remediation ref | PASS: 0 build warnings/errors, 2 unit tests, 96 integration tests |
| ZAP remediation ref | PASS: 0 build warnings/errors, 2 unit tests, 103 integration tests |
| JMeter remediation tested-code ref | PASS: 0 build warnings/errors, 6 unit tests, 100 integration tests |
| SonarQube 26.7 | PASS execution: baseline 17 issues, remediation 0 issues, both Quality Gates OK |
| OWASP ZAP 2.17 | PASS execution: all four fresh scans completed; raw severity differences are retained in the appendix |
| Apache JMeter 5.5 | PASS execution: both five-profile matrices completed; baseline core gate PASS, remediation fresh core gate FAIL (p100/p500 exceeded thresholds) |
| Dashboard evidence | PASS: 18 of 18 required images hash-match their manifests and source artifacts |
| Browser workflow | PASS: alternate-port admin login/report/audit and auditor restriction flows against isolated LocalDB |
| Thesis tooling tests | PASS: 62 Pester tests and 13 frontend tests |

Historical and fresh results remain separate. Fresh results do not overwrite the current paper's measurements.

## Cleanup performed

- Removed the clean detached worktrees `verify-baseline`, `verify-sonar`, `verify-zap`, and `verify-jmeter` using `git worktree remove`.
- Kept their source commits recoverable through existing remote branches and the four annotated evidence tags.
- Moved the generated 80.48 MiB JMeter tree and 1.34 MiB ZAP HTML/Markdown tree into ignored, recoverable `.tmp` archives.
- Versioned only compact summaries, statistics, selected raw ZAP JSON, screenshots, and JTL hashes.
- Left Docker tool containers available for later appendix demonstrations.

## Supplemental work

GPT-5.5 comparison branches, new-API v2 branches, mutation-source branches, and raw experiment outputs are not current-paper evidence. They must not be presented as GPT-5.4 thesis results.

The primary report-working checkout intentionally retains three untracked groups: `Document/experiments/`, `Document/outputs/camera-ready-manuscript-V2 (1).docx`, and duplicate `Document/outputs/final-defense/` exports. The intended report changes are recoverable on `origin/codex/thesis-report-working-20260922`; the final-defense source and outputs are recoverable on `origin/codex/final-thesis-defense`. The raw v2 experiment directory remains local-only pending a separate supplemental-evidence decision and is excluded from this current-paper consolidation.

Other registered v2/mutation worktrees were not removed because they are supplemental research state outside the current paper. The detached `benchmark-v2-reference-candidate` is recoverable through tag `benchmark-v2-reference-code`.
