# Final-report integrity recheck — 29 October 2026

Target: `final-report-methods-citations-20261023.docx` and matching PDF. Goal: make the completed case study's method, claimed changes, and conclusions agree with retained source and measurement evidence.

## Findings corrected

| Finding | Evidence | Correction |
| --- | --- | --- |
| The four-phase table listed intervention tracks rather than the phases shown in the workflow figures. | Table 3.1 had baseline/static/security/performance rows; Figures 3.1–3.4 describe baseline, reviewed improvement, remeasurement and comparison. | Table 3.1 now follows those four phases, with branch isolation described separately. |
| Security/performance prose presented generic improvement ideas as if they were demonstrated interventions. | Frozen ZAP diff `7a0469d9→5f3bd3cc` changes header middleware, Swagger flags/configuration and dependencies. It does not establish new encryption, session management or SQL-injection remediation. The performance revision does not establish a separately measured new pagination/connection-pooling intervention. | §§3.1 and 3.4 now describe only the source-visible changes and preserve the boundary around the combined performance revision. |
| Exact model-round counts in Table 3.9 lacked traceable prompt records in the examined package. | The inspected frozen candidate trees, retained fix logs and verification packages support source/tool outcomes, but did not establish the table's numerical per-candidate prompt-round counts. This does not prove that no original conversations exist elsewhere. | Removed numerical counts as observed measurements. Tables 3.8–3.9 now identify a retrospective prompt structure, review questions and evidence provenance. O4 and Appendix N disclose the gap. |
| Introductory/method prose implied measured time savings, comprehensive security coverage and production representativeness. | No developer-time study is reported; ZAP/role coverage is selected; the fixture is synthetic and only one API is evaluated. | Narrowed the claims to measured outcomes, scoped checks and a case-study procedure. Candidate retention for comparison is distinguished from production acceptance. |

## Verification

- Report: 138 pages, all 173 front-matter references checked against rendered pages, no unresolved figure/table identifiers.
- All ten checked measurement tables retain their numerical values. Chapter 2, Word style/theme/numbering definitions, embedded images, page margins and curated source-code listing text are unchanged.
- The ten cloud JMeter figures remain current and now appear on pages 125–134 because earlier prose changed pagination.
- The 35-slide deck keeps the same charts and quantitative results. Matching review-provenance notes and slide 34 were corrected; the exported text was checked against the PDF.
- Original report and presentation versions are backed up in the isolated worktree under `.superpowers/sdd/2026-10-29-report-integrity-review/`.

## Remaining evidence boundary

Exact original prompt/response transcripts, per-candidate interaction counts, independent reviewer scores and person-hours are not verified from the retained study artifacts. They must not be presented as measurements unless their original records are supplied and checked. The case study can describe its retrospective review process and measured software outcomes without inventing those records.

Verdict: suitable for supervisor review with the prompt-level provenance limitation explicitly disclosed; no new result mismatch was identified in the checked numerical evidence or route inventory.
