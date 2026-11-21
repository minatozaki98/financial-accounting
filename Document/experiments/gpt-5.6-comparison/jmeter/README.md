# JMeter preparation for GPT-5.6

Three independent model sessions used high reasoning and the same [baseline-only input](baseline-input.md) from the original performance experiment. Their independent source started at 7a0469d9401a3061941b44fcd46b3beca1c9c729. The [build manifest](builds.json) identifies the controller-verified source revisions, Linux AMD64 API images, and post-restore SQL hashes. The performance commits and comparison runner are on the branches listed below. The five container images are stored locally.

| Candidate | Frozen commit | Main change | Unit / integration tests passed |
|---|---|---|---|
| GPT-5.6 Luna | c05fb6d | Two composite indexes, no-tracking report reads, account DTO projection, and split queries for journal-entry detail/list | 3 / 96 |
| GPT-5.6 Terra | 2ba92cd | Two composite indexes for posted entries in a period and account-to-entry joins, with schema and report/audit regression tests | 2 / 98 |
| GPT-5.6 Sol | eea341f | Two composite indexes, including a ledger-line index covering debit and credit | 4 / 96 |

Each candidate has a branch named codex/benchmark-20261121-MODEL-performance, with MODEL replaced by luna, terra or sol. The candidate folders contain the frozen revisions, patches and test counts. The reference builds use the pre-fix revision above and GPT-5.5 JMeter revision 8d0be3b918008f1cf38a7c61669f8d7609df0963.

## Local SQL verification

The controller used the pinned SQL Server 2022 image and verified the original backup digest 2c2e7ce6aac675ab1f2924e4dea4a07bae70dbd587618fd5c64e4ebb5e7365b4. Each candidate started from a separate restore with 120 accounts, 30,000 journal entries and 5,000 posted entries. Applying its SQL twice produced the same two additional indexes and column definitions. The API passed readiness checks across two starts. Authenticated trial balance for period 202601 and ledger for account 1 returned the same payload hashes as the pre-fix build, and each call wrote a report and an audit record. The four SQL smoke JSON files preserve these checks.

These are correctness checks on one fixture. Extra indexes can increase write and storage costs. Luna also changes query shape, including separate reads when loading entries and lines. Performance under concurrent reads and writes remains unmeasured. An initial Windows LocalDB restore attempt failed; the checks reported here all used the pinned SQL Server container.

## Comparison runner

Branch **codex/jmeter-five-build-runner**, commit 355342b83ebfcd47d4e731cde708c2f818d545c9, extends the controlled harness at fc18adbcc42b9d8a0ea01cfde4dac4c269ef4d8b. The [runner patch](comparison-runner.patch) reproduces the change on that base. The original two-build entry point remains available.

The [offline schedule](schedule.json) has 75 scored slots: five builds × five profiles × three repetitions. Each build occurs three times in each execution position across the 15 blocks. The runner checks image IDs, workload and schema hashes, restores the fixture, applies that candidate’s indexes before API startup, and retains the existing resource, concurrency and scoring checks. An interrupted block is retried as a whole. Outputs include each repetition, medians, ranges and paired differences from both references.

From the runner checkout, run the following with the path to this folder's manifest:

~~~powershell
python scripts/phase4/cloud-jmeter/run_five_builds.py --builds <path-to-builds.json>
~~~

This default is an offline dry run. The local dry run checked the five workload hashes and candidate SQL files. An offline controller test also checked order balance, a mid-block interruption, resumption, and aggregation into 25 profile/build rows. No deployment or JMeter workload was executed.

For the later deployment, transfer the five exact tagged images and frozen workload/fixture files, install the updated restore helper, and copy the three SQL files byte-for-byte into /opt/jmeter-research/schema/ on the target. Use a fresh cloud session with current budget and host metadata. The execution entry point requires both --execute and --state-dir; live host setup, end-to-end runner verification and performance scoring remain pending.
