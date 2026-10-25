# Controlled cloud JMeter comparison protocol

**Status:** The environment, caps, seed, and all five profile rules were frozen after the final 500-user and spike pilots passed on 2026-10-25. The before and after application source commits remain `7a0469d9401a3061941b44fcd46b3beca1c9c729` and `78b08b62570dcf6fe436354e8e6b770ab2074445`. Pilot repairs changed only the shared measurement harness, not those application commits.

## Rationale and fixed environment

Use the same Singapore 2 Akamai G6 Dedicated 8 GB/4 vCPU target and generator for each before/after pair. Fixing the VM tier, region, CPU model, image digests, workload, seed, and ordering addresses the cloud measurement and reporting concerns described by [Papadopoulos et al. (2021)](https://doi.org/10.1109/TSE.2019.2927908) and the VM variability studied by [Baresi et al. (2023)](https://doi.org/10.1002/spe.3244). Three paired repetitions alternate before/after, after/before, before/after; publish the median, range, and each paired difference. p95/p99 latency is primary because the tail of Web service response times can matter even when the mean looks acceptable, as discussed by [Dean and Barroso (2013)](https://doi.org/10.1145/2408776.2408794). The exact pair order, thresholds, and active-user gate below are this study's own pre-scoring choices.

The API and SQL Server share the target VM. Their Docker caps are 2 CPU/2 GiB and 2 CPU/4 GiB, respectively; SQL Server also has `MSSQL_MEMORY_LIMIT_MB=3072`. JMeter has 4 CPU/4 GiB and a 2 GiB Java heap on the separate generator. Every container's swap limit equals its memory limit, and host swap is disabled. Docker 29.9.2/Compose 5.6.1 run on Ubuntu 24.04 x86-64. The two VMs communicate over one private VPC; SQL listens only on the target host loopback, the API only on its VPC address, and the public firewall allows operator SSH. No paid backup add-on is enabled.

The pristine SQL Server 2022 CU20 Developer fixture has 120 accounts, 30,000 journal entries (5,000 posted), period ID 202601, and default account ID 1. Its backup SHA-256 is `2c2e7ce6aac675ab1f2924e4dea4a07bae70dbd587618fd5c64e4ebb5e7365b4`. Restore and verify counts before **every** run, then start a fresh API container. Record the schema indexes and row counts before and after; the after source creates two SQL indexes at startup. The workload includes bulk writes, so database growth during a run is a stated limitation rather than an unreported change. All data sent to the VMs is synthetic.

## Workload and timing

All five controlled JMX files use the same authenticated API workload for both source revisions. The normal profile mix is 70% core and 30% complex: p50 has 35/15 threads, p100 has 70/30, and p500 has 350/150. Every report GET places its synthetic period/account ID in the URL, and mixed mode is explicit. JMeter runs non-GUI from the pinned version 5.5 image.

| Profile | Scored window from test start | Unscored buffer |
| --- | --- | --- |
| p50, p100, p500 | 0–120 s ramp; 120–720 s hold | 720–750 s shutdown |
| soak | 0–120 s ramp; 120–2820 s hold | 2820–2850 s shutdown |
| spike | 0–30 s ramp to 100; 30–150 s base; 150–180 s ramp to 500; 180–480 s peak; 510–810 s recovery at 100 | 480–510 s drain; 810–840 s shutdown |

The buffers were added before scored runs after a diagnostic p500 JMeter run stopped threads in the last 10 seconds of its declared hold. The buffer is excluded from latency, error, throughput, and active-user analysis. The spike uses a distinct unscored drain interval so its recovery phase begins after the extra 400 threads have ended.

The frozen JMX SHA-256 values are:

| Profile | SHA-256 |
| --- | --- |
| p50 | `cc27c4dfa179b1798aafd419e86c95b96d1a58254cb33cea93763f569969a6dd` |
| p100 | `dce2794e385704dd1068141cb011798e38faa921fdff1b9fcef18a6f139a9261` |
| p500 | `f359be8ce0311512e6433550369fc94b18425665b56628ada032c67e9beea076` |
| soak | `33c2947c691ecc7e43e648ba1859607a2764087a3e42d62c1a1eb09c73db4a70` |
| spike | `f2f2ef08f60a190d67959a15767361444dd63df66df078531fc75f7d48d172dc` |

## Validity and acceptance gates

A normal run is valid only if the target active users are reached by ramp end, every scored five-second bin has a JTL sample, at least 95% of hold bins show the exact target, and no bin drops below 95% of target. The base, peak, and recovery spike phases are checked separately. A JMeter log error or exception invalidates the run. Docker container thread counts sampled every five seconds corroborate the JTL series but are not exact virtual-user counts. A run is invalid if a host has less than 1 GiB available memory, any active host swap, swap page activity, or an OOM kill. The generator must have at most 1% CPU-quota periods throttled and p95 cgroup CPU use below 90% of its cap **during the scored hold**; its peak memory must stay below 95% of cap. CPU bursts during unscored startup/ramp are reported but do not fail the hold gate. An invalid run requires the whole before/after pair to be rerun.

Performance gates are applied without changing them after results: p50 p95 ≤300 ms/errors ≤0.5%; p100 ≤500 ms/≤1%; p500 ≤1200 ms/≤2%; soak errors ≤1% and first-to-last ten-minute p95 drift ≤20%; spike scored-phase errors ≤3% and recovery-versus-base p95 drift ≤20%. A valid measurement can fail a performance gate; these are distinct outcomes. Report per-endpoint p95/p99, throughput, errors, host/container CPU and memory, throttling, and run-to-run spread. The older March/September results use different profiles and resource controls and remain historical context only.
For continuity with the original thesis runner, also calculate its first-versus-last 20% **of all JTL samples** drift for soak and spike. That legacy statistic is reported separately from the new phase-based drift because it can mix ramp, peak, and recovery traffic. The ≤20% threshold is retained, but the two window definitions are never treated as the same measurement.

## Cost and stopping

The user's 2026-10-25 limit is **$50 total**, with a goal below $30 and a stop on new runs at $40 accrued/projected. The two active G6 8 GB/4 vCPU VMs list at $0.108/hour each; Akamai rounds billable usage up to an hour and lists resized sizes as separate line items. A 24-hour local cleanup task is armed for 2026-10-26 07:28:42 UTC, and the experiment resources will be deleted after evidence is copied. Read the provider's accrued charges before each new run and use the final invoice, when available, for the actual cost. The methodology for explicit cloud cost reporting is also supported by [Papadopoulos et al. (2021)](https://doi.org/10.1109/TSE.2019.2927908).
