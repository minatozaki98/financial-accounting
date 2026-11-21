# SonarQube comparison

All five revisions were measured locally on the same SonarQube 26.11.0.134175 server. Each of the three GPT-5.6 variants received the same seven baseline findings, proposed nine edits across six files, and was measured after its edits. The comparison revision for GPT-5.5 is the original sonar remediation branch at 19763f15cbc8412eb74ff5b9d706be69456e62ff.

| Candidate | Bugs | Code smells | Coverage | Unit tests | Integration tests | Quality gate |
|---|---:|---:|---:|---:|---:|---|
| Pre-fix | 1 | 6 | 74.4% | 2/2 | 96/96 | OK |
| GPT-5.5 | 1 | 0 | 74.3% | 2/2 | 96/96 | OK |
| GPT-5.6 Luna | 0 | 0 | 74.4% | 2/2 | 96/96 | OK |
| GPT-5.6 Terra | 0 | 0 | 74.4% | 2/2 | 96/96 | OK |
| GPT-5.6 Sol | 0 | 0 | 74.5% | 2/2 | 96/96 | OK |

The one remaining GPT-5.5 finding concerned cancellation of an HTTP response write. All three GPT-5.6 candidates resolved it. The current server reported six pre-fix code smells. The historical study recorded 21 under its earlier analyzer. Use the fresh measurements for model comparisons.

All three GPT-5.6 fixes also changed a role lookup to load the role table into application memory before matching a name. Luna used the current culture for case-insensitive comparison and Terra and Sol used ordinal comparison. The existing tests passed. These scans did not measure the runtime cost or equivalence across all cultures and database collations.

Per-project folders contain the server task, measures, gate, issues and test counts. Candidate folders also contain the model proposal, source patch and frozen revision.
