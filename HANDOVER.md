# Financial-accounting handover

## 2026-11-21 checkpoint

The current thesis documents, defense materials, runbooks, and historical measurement evidence are checkpointed on the thesis working branch. Four previously tracked report files were already absent in the working tree. Earlier versions remain in Git history.

The [Luna, Terra, and Sol protocol](docs/superpowers/plans/gpt-5-6-luna-terra-sol-comparison.md) covers three independent criteria and a fresh GPT-5.5 comparison. Verify model selection before attributing any remediation. Deployment and JMeter load testing are deferred at the user's request.

## 2026-11-21 benchmark measurements

The [GPT-5.6 comparison report](Document/experiments/gpt-5.6-comparison/RESULTS.md) records the finished SonarQube and passive ZAP measurements for the pre-fix build, saved GPT-5.5 fixes, and separate Luna, Terra, and Sol candidates. Local Git branches under codex/benchmark-20261121 preserve the measured model fixes. Terra and Sol cleared all High and Medium passive alerts. The final Luna revision retained one High alert in the Swagger UI JavaScript bundle. Deployment and JMeter load testing remain deferred.

## 2026-11-21 JMeter preparation

The [preparation report](Document/experiments/gpt-5.6-comparison/jmeter/README.md) links the frozen inputs and local verification for the three performance candidates. The branches are `codex/benchmark-20261121-luna-performance` (99 tests passed), `codex/benchmark-20261121-terra-performance` (100), and `codex/benchmark-20261121-sol-performance` (100). Each candidate preserved the baseline ledger and trial-balance results and expected audit writes on the restored 30,000-entry fixture.

The comparison runner is on `codex/jmeter-five-build-runner` at `355342b`. Its [schedule](Document/experiments/gpt-5.6-comparison/jmeter/schedule.json) covers 75 scored runs across five builds, five profiles and three repetitions. The [manifest](Document/experiments/gpt-5.6-comparison/jmeter/builds.json) identifies the five local images and the SQL to apply after each restore. Deployment and load testing are pending. Performance gains remain unmeasured.
