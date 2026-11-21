# JMeter full-report reconciliation — 29 October 2026

Later editorial integrity review: [final-report-integrity-review-20261029.md](final-report-integrity-review-20261029.md). Its prose changes move the unchanged cloud JMeter figures to pages 125–134 in the 138-page report. The page counts below describe the earlier JMeter-reconciliation checkpoint.

Updated deliverable: `final-report-methods-citations-20261023.docx` and its matching PDF in this directory. This check supersedes the JMeter appendix status in the earlier four-item synchronization note.

## What changed

- Replaced all ten local JMeter screenshots in Appendix L, Figures L.9–L.18, with researcher-generated figures from the accepted controlled cloud measurements. Each figure shows all three accepted runs for that profile/source side, exact run IDs, p95/p99, throughput, errors, gate outcome, and resource context. Soak/spike figures also show their relative-stability windows. These are clearly labelled research plots, not native JMeter UI screenshots.
- Updated the environment and request-scope descriptions, Table 3.6 profile comparison, Table 4.4 endpoint comparison, Table 4.5 closure matrix, Table 4.6 p95 ranges, resource definitions, and related performance prose. Current JMeter results now consistently refer to the 25–26 October controlled experiment.
- Added Appendix K.4 and Table K.1 with the precise scored windows, CPU/RAM controls, normal/error/drift gates, validity checks, paired-summary definitions, and the disclosed protocol-v2 concurrency amendment.
- Updated Appendices A, M and N to distinguish local static/security scans from controlled cloud performance. Removed stale local latency figures and old local JMeter run captions from the current report. Historical tables and screenshots remain in the support package.
- Refreshed all 173 contents, figure and table page references. The final PDF has 137 pages. JMeter Figures L.9–L.18 are on pages 124–133.

## Evidence verification

The original analysis functions reprocessed all 30 accepted JTL/log pairs. Their p95, p99, throughput, errors, endpoint metrics and performance-gate counts match the published comparison. All 15 accepted before/after pairs were retained; the slow third 500-user baseline was not discarded. Resource-validity checks were repeated against the recorded evidence. A total of 150 captured input files were rehashed; the separate raw archive hash was also verified.

The results remain qualified: after 50/100-user gates pass 3/3, 500-user p95 passes 0/3, soak stability passes 1/3, and spike recovery passes 0/3. The paired 50-user p99 and bulk-write p95 regressions remain explicit. p99 has no declared pass threshold. No new load tests or cloud resources were created.

See the [support package](../experiments/jmeter-cloud-20261023/appendix-refresh-20261029/README.md), [accepted-run CSV](../experiments/jmeter-cloud-20261023/appendix-refresh-20261029/evidence/accepted-runs.csv), [figure provenance](../experiments/jmeter-cloud-20261023/appendix-refresh-20261029/figures/figure-provenance.json), and [verification record](../experiments/jmeter-cloud-20261023/appendix-refresh-20261029/verification.json).

Word styles, numbering definitions, theme, page size and margins were preserved. Chapter 2 and the eight SonarQube/ZAP dashboard images remain unchanged. Each JMeter figure, its heading, caption and source note was checked together in the rendered PDF; the relevant main-report tables and protocol pages were also visually inspected.

The pre-edit report is backed up in the isolated worktree under `.superpowers/sdd/2026-10-29-jmeter-report-refresh/original.docx` and `original.pdf`. The existing PowerPoint was checked for references to the retired local JMeter appendix screenshots; its cloud metrics were already consistent and needed no change in this revision.
