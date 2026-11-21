# Compare GPT-5.6 Luna, Terra, and Sol with GPT-5.5

## Objective

Measure each variant's improvement over the same unmodified financial-accounting application and compare its final result with a freshly measured GPT-5.5 fix for each criterion.

## Common starting point

Extend the [existing Sol protocol](2026-07-19-gpt-5-6-sol-quality-benchmark.md). Verify the exact selectable identifiers for Luna, Terra, and Sol and record their displayed labels and reasoning settings. Availability is unverified. Retain a column marked unavailable for any missing variant.

Start from pre-fix commit 7a0469d9401a3061941b44fcd46b3beca1c9c729. Verify the saved GPT-5.5 revision for each criterion. Pin tool versions, image digests, scan rules, endpoint scope, workloads, database backup, and pass thresholds before capturing the fresh baseline.

## Nine independent improvement tasks

Give each variant one fresh workspace per criterion. Supply the same prompt, source revision, and baseline findings for that criterion. Exclude previous fixes, reports, and other candidates' work from these workspaces. Allow one initial attempt and up to two corrections based on tool feedback. Record attempts and freeze each final revision, including failures and remaining findings.

| Criterion | Measurements |
|---|---|
| Code quality (SonarQube) | Record quality gate, bugs, code smells, and test coverage. Run the same test suite and verify the scan covers the same source. |
| Security (OWASP ZAP) | Use the established authorized baseline and API scans against the isolated test application. Record alert categories and instances by severity, high and medium findings on business endpoints, and endpoint coverage. Investigate reduced endpoint coverage before comparing findings. |
| Performance (Apache JMeter) | Run the existing 50-, 100-, and 500-user, soak, and spike profiles. Measure p95 and p99 latency, throughput, error rate, and soak drift. Run candidates sequentially on the same host. Use three measured repetitions per profile and report the median and range. |

Restore the same database backup before each ZAP or JMeter measurement. Apply the same measurement procedure to the pre-fix baseline, the saved GPT-5.5 fixes, and the frozen candidate revisions.

## Comparison and deliverables

- If a GPT-5.5 revision cannot be recovered, mark its figures historical only and leave the fresh comparison open for that criterion.
- Produce one results table per criterion with columns for the pre-fix baseline, GPT-5.5, Luna, Terra, and Sol. Show raw values, changes from baseline, differences from GPT-5.5, and gate outcomes. Include residual alerts and performance regressions.
- Link the report to raw results, prompts, revision IDs, and environment settings. Limit conclusions to this application and these runs. Keep the accepted thesis and camera-ready manuscript unchanged.
