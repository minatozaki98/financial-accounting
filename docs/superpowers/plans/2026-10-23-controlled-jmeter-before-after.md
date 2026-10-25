# Controlled JMeter Before and After Implementation Plan

> **For implementation:** Execute the checked tasks in order. Keep the experiment harness separate from the two frozen application revisions.

**Goal:** Rerun the 50, 100, and 500 user, soak, and spike JMeter profiles against the pre-fix and ChatGPT-assisted JMeter-fix source under the same explicit CPU and memory limits, then report reproducible before/after results.

**Architecture:** Build the API from two exact Git commits in isolated checkouts. Run each against an identically restored synthetic SQL Server database, using a separately limited JMeter generator. Use two short-lived dedicated-CPU VMs in one private cloud network as detailed in `docs/superpowers/plans/2026-10-23-cloud-jmeter-experiment.md`; the local idle-machine design remains the fallback. Store the harness, resource limits, raw telemetry, provenance, and comparison outside both frozen source revisions.

**Tech Stack:** ASP.NET Core 8, SQL Server, Docker Engine/Compose on cloud Linux (Docker Desktop for local fallback), PowerShell, Apache JMeter 5.5, Git.

**Spec:** The user's 2026-10-23 request; existing evaluation rules in `scripts/phase4/run-thesis-suite.ps1`; historical experiment design in `docs/superpowers/plans/2026-07-19-gpt-5-5-quality-benchmark.md`.

## Global Constraints

- Plan first: this document authorizes no application edit or load run by itself. Do not alter the two measured source commits.
- Before = `baseline-v0.1` at `7a0469d9401a3061941b44fcd46b3beca1c9c729`. After = source-fix commit `78b08b62570dcf6fe436354e8e6b770ab2074445` on `baseline-jmeter-v1`; branch HEAD `3c9392d8dcecf986da5438962e20c5d862e8be08` adds documentation only. Verify this source equivalence at execution.
- The existing dirty primary checkout and other worktrees are out of scope. Use two new detached worktrees or immutable build contexts. Do not merge SonarQube, ZAP, or later model branches into this comparison.
- Use synthetic data only; isolate the test database from the local `Financial` database and other services. Never change global limits on a shared SQL Server instance.
- Freeze and record Docker image digests, .NET SDK/runtime, JMeter version, host/VM specifications, cap values, test-plan hashes, database backup hash, endpoint mix, and app settings before collecting measured results.
- Restore the same database backup before **every** measured run. Allow the after application's startup index creation, then record the resulting index inventory; it is part of the fix being measured.
- Keep credentials and JWTs out of Git, process arguments, JTL, logs, and manifests. Do not silently replace missing period/account IDs.
- Preserve the March and September JMeter artifacts. The new protocol gets a new run directory; old and new numbers are not interchangeable.
- Report failures and uncertainty. No threshold or cap adjustment after seeing before/after results; a change requires a newly versioned experiment protocol and full rerun.
- The user's latest budget is **$30–$50 total** for one to five temporary research attempts, including tax and extras, with no ongoing hosting. Aim below $30, stop starting new runs at $40 accrued/projected, and enforce the $50 hard ceiling. The companion cloud plan contains the cost controls.

## Review Focus

- If the after revision needs a schema/index change, prove the baseline database was restored before the run and record its post-start schema.
- If a load generator throttles or fails to reach target active threads, mark that run invalid, not a successful API result.
- If a 500-user p95 is lower than a 100-user p95, verify actual concurrency, request mix, throughput, warmup/cache state, and database state before explaining the result; do not assume latency must rise monotonically.
- If a requested fixture ID is absent, fail the preflight rather than benchmarking another account or period.
- If host/Docker memory headroom is inadequate, stop before starting load; do not swap or kill unrelated applications automatically.
- If traffic changes the database, reset it before the next repetition and confirm the restored row counts/hash.
- If Windows or unrelated Docker workloads change between a before/after pair, flag the pair and repeat it only after the host returns to the frozen idle baseline.

## Evidence already found

| Item | Current evidence |
| --- | --- |
| Branches | `baseline-v0.1` and `baseline-jmeter-v1` share the before commit. The after source is the first child fix commit; the next commit contains its report. |
| Source treatment | Report write amplification removed, ledger balances reused, SQL composite indexes added, ledger JSON cached/invalidation added, response compression enabled. Compression is not exercised unless JMeter sends `Accept-Encoding`. |
| Last fresh rerun | September 2026 archived summary: before passed, after **failed** the 100-user p95 gate (1146.9 ms > 500 ms) and 500-user p95 gate (1547.95 ms > 1200 ms). This conflicts with the older March improvement claim. |
| Current profile flaw | Fixed JMeter loops with scheduler disabled can end threads before a stable hold; 50 users is core-only while 100/500 are mixed. The current runner has no container CPU/RAM caps. |
| Raw concurrency check, 2026-10-24 | In three March 2026 p100/p500 JTL pairs, all configured thread names appeared eventually, but p100's highest recorded simultaneous `allThreads` was only 23–24 and p500's was only 21–22. In the `20260324-103712` pair, p100 ran 76.7 seconds and p500 ran 189.5 seconds; neither had a recorded sample at even 90% of nominal concurrency. September 2026 summaries use the same loop/ramp scripts but their raw JTLs were not found in the archived appendix, so their true active-thread peaks remain unverified. |
| Current machine, checked 2026-10-23 | i9-11900H, 8 physical cores/16 logical, 31.68 GiB RAM; Docker Linux VM exposes 15.46 GiB RAM and 4 GiB swap. Host free RAM was 7.45 GiB and Docker VM available RAM about 12.25 GiB. A 10-second Windows process sample used about 28% aggregate CPU. These are snapshots, not a stable idle baseline. |
| Background work, checked 2026-10-23 | Three unrelated Docker containers were running: OCIPA Keycloak (711 MiB), OCIPA SQL Server (1.70 GiB), and Government Coverage PostgreSQL (45 MiB). All three had unlimited Docker CPU and memory settings. Windows also had two SQL Server services and PostgreSQL running; ChatGPT, browsers/WebView, Claude, Codex, and Steam were active. The local machine is **not ready** for the measured run. |

## Free web hosting assessment (checked 2026-10-23)

Free hosting is suitable for a separate API demonstration, but not for the controlled 50/100/500-user results in this plan:

| Option | Verified limit | Decision for this experiment |
| --- | --- | --- |
| [Render Free web service](https://render.com/docs/compute-plans) | 0.1 CPU, 512 MB RAM; [spins down after 15 minutes idle](https://render.com/docs/free). | Can potentially demonstrate a Dockerized ASP.NET Core API. It cannot provide the planned 2 vCPU/2 GiB API environment or host the separate 4 GiB SQL Server and 2.5 GiB JMeter roles. |
| [Koyeb Free web service](https://www.koyeb.com/docs/reference/instances) | 0.1 vCPU, 512 MB RAM; no persistent volume. | Same demo-only conclusion. |
| [Azure App Service Free](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/azure-subscription-service-limits) | Shared compute, 1,024 MB memory quota per plan, 3 CPU minutes per 5 minutes and 60 per day. | Might host a light demo after deployment checks; sustained load can exhaust its quotas and cause 403 responses. It does not reproduce the planned fixed caps. |
| [OCI Always Free](https://docs.oracle.com/cd/E97706_01/Content/FreeTier/resourceref.htm) | Arm A1 allowance is 2 OCPUs/12 GB; x86 E2 Micro has 1 GB RAM. | Arm can run an API but [Microsoft's SQL Server container is x86-64 only](https://learn.microsoft.com/en-us/sql/linux/sql-server-linux-docker-container-deployment?view=sql-server-ver17). The x86 micro is below [SQL Server's 2 GB minimum](https://learn.microsoft.com/en-us/sql/linux/sql-server-linux-setup?view=sql-server-ver15). Neither reproduces the full proposed topology. |

The API currently targets .NET 8 and uses SQL Server with a localhost Windows trusted connection in `API/appsettings.json`. A public demo would need a Dockerfile or native deployment setup and a separate cloud SQL connection. [Azure SQL Database's free tier](https://learn.microsoft.com/en-us/azure/azure-sql/database/free-tier-faq?view=azuresql) may serve a synthetic demo if the account is eligible, but it has monthly compute/storage limits and does not accept restoring an existing database into the free tier. It would change the database environment and therefore must **not** be substituted into this benchmark. The demo, if requested, should use its own branch and synthetic data; no public deployment is part of the measured rerun.

## Cloud hosting decision (checked 2026-10-23)

The authoritative deployment and budget plan is `docs/superpowers/plans/2026-10-23-cloud-jmeter-experiment.md`. Its cheapest generator tier that avoided material CPU throttling in a diagnostic pilot is an [Akamai Cloud G6 Dedicated](https://www.akamai.com/cloud/pricing/cpu) 4 vCPU/8 GB VM ($0.108/hour), paired with the same sized API/SQL target in **Singapore 2 (`sg-sin-2`)**. Singapore 2 supports the private VPC required by this topology; the older `ap-south` Singapore region does not. The pair is **$0.216/hour**, or **$25.92 for five 24-hour sessions** before tax (about $27.73 with the provider's listed [7% Thai VAT](https://techdocs.akamai.com/cloud-computing/docs/tax-information), if applicable), plus short diagnostic usage and hourly rounding. The 2 vCPU/4 GB generator sustained 500 users but had 1.97% CPU-quota periods throttled during the scored hold; it was rejected before scoring. The resized 4 vCPU/8 GB generator passed the full p500 pilot with zero scored-hold throttling.

The cloud plan explains the alternatives and full lifecycle. [DigitalOcean's](https://docs.digitalocean.com/platform/resource-limits/) cheaper nominal pair may need a $250 account-tier prepayment, and the [Hetzner](https://www.hetzner.com/cloud/general-purpose/) dedicated size was marked unavailable on its public page. None of the existing unrelated Azure subscriptions will be used without the user's explicit choice. The cloud system under test remains private and temporary.

## File and result map

- Keep original source commits and existing `Document/performance/jmeter/*.jmx` unchanged.
- Create an isolated experiment worktree/branch, suggested `codex/jmeter-controlled-rerun`, for the harness and analysis only.
- Create `scripts/phase4/controlled-jmeter/compose-target.yaml` and `compose-generator.yaml` for container caps/network/health checks on the two VMs; `run-matrix.ps1` for preflight, backup restoration, run scheduling, and manifest; `collect-container-metrics.ps1` for per-container CPU/RAM/throttling/OOM; versioned JMX plans for stable load profiles; `summarize.ps1` for phase-filtered output and comparison.
- Write results under `Document/experiments/jmeter-controlled-20261023/` with one `protocol.md`, `environment.json`, and immutable `before/<profile>/<repeat>/` and `after/<profile>/<repeat>/` folders containing JTL, JMeter report, telemetry CSV, health/event log, row counts, hashes, and run manifest. Keep large generated artifacts out of ordinary commits if repository policy requires; preserve their checksums and location.
- Produce `comparison.md` with before/after source diff references, medians and ranges, endpoint-level results, gate outcomes, resources, and limitations. Cite relevant Chapter 2 papers for interpretation; add verified scholarly literature to the literature review if a needed claim has no support.

## Tasks

### Task 1: Freeze source and protocol

- [ ] Verify both commit hashes, their merge base, the source-only diff, and clean detached measurement checkouts. Archive `git diff --binary` and changed-file list as provenance; identify any source differences unrelated to JMeter.
- [ ] Record the exact ChatGPT prompt/model/session evidence associated with the fix if it exists. If no primary interaction record exists, label the branch *ChatGPT-assisted per project records* and do not claim a particular model or degree of autonomy.
- [ ] Version the five JMX profiles. Keep the same 70% core / 30% complex thread mix at 50 (35/15), 100 (70/30), and 500 (350/150) users, with the same endpoints, data, timers, headers, and authentication on both revisions. Set loops to continue until a fixed duration; validate observed active users. Define ramp, hold, and recovery windows explicitly. Keep write traffic, if any, identical and restore the database between runs. Save JTL `allThreads` as the active-VU measure and five-second Docker container thread counts as an independent sanity check; container thread counts are not exact VU counts.
- [ ] Predeclare the concurrency validity rule: target 50/100/500 active threads must be reached by the end of ramp; at least 95% of scored hold-window 5-second bins must show the exact target, and no hold bin may fall below 95% of it. Reject and rerun the **pair** if this or generator headroom fails. Report actual peak, median, and minimum hold-window active threads beside each VU label.
- [ ] Predeclare primary metrics (hold-window p95, error %, throughput per profile) and secondary metrics (p99, endpoint distributions, CPU, memory, GC, throttle, OOM, soak drift, spike recovery). Retain existing gate values: 50 p95 ≤300 ms/error ≤0.5%; 100 ≤500 ms/≤1%; 500 ≤1200 ms/≤2%; soak error ≤1% and p95 drift ≤20%; spike error ≤3% and recovery drift ≤20%. Recheck that phase-based definitions match the gate calculation; report original gate and revised steady-state analysis separately if they differ.
- [ ] Hash the final protocol and JMX files before measurement. Verify a profile validation script rejects missing IDs, mismatched mix, missing credentials, or changed hashes.

### Task 2: Build the capped isolated environment

- [ ] Pin one SQL Server image digest and one JMeter 5.5 image digest. Use SQL Server 2022 CU20 or later so its process recognizes the Docker host's cgroup v2 limits; verify the actual SQL build. Build before/after API images using the same .NET SDK/runtime and build flags from exact SHAs; record image IDs/digests.
- [ ] Before any paid provisioning, confirm the $50 **total** ceiling and $40 operational stop target, two eligible dedicated-CPU sizes in one region/private network, live hourly price and tax, SSH/access method, available disk, and an elapsed-time teardown. If this cannot be guaranteed, keep the run local or propose a newly priced alternative.
- [ ] Current final-pilot caps: API **2 vCPU/2 GiB**, SQL Server **2 vCPU/4 GiB** with `MSSQL_MEMORY_LIMIT_MB=3072`, JMeter **4 vCPU/4 GiB** with a 2 GiB Java heap. In Compose set each service's `cpus`, `mem_limit`, and `memswap_limit`; make `memswap_limit` equal `mem_limit` to disallow container swap. Disable host swap for scored runs. Inspect running `NanoCpus`, `Memory`, `MemorySwap`, and cgroup values to prove enforcement. CPU quotas cap usage; they do **not** reserve host cores. The final 4 vCPU generator pilot must still prove headroom.
- [ ] **Local fallback only:** coordinate an idle window for the three unrelated Docker containers and other active apps; do not stop or change them automatically. Require zero unrelated running containers, at least **14 GiB available host RAM**, at least **12 GiB available to the Docker VM**, adequate disk space, healthy isolated containers, and no active Windows load test/build. Record five minutes of host CPU/memory/swap and Docker background baseline before each pair: target median host CPU <10%, p95 <20%, no swap-in/out activity, and no sustained disk contention. If the gate is not met, postpone or move the experiment; do not quietly reduce caps or run alongside other projects.
- [ ] Set the API's connection string to the isolated SQL service through environment configuration. Seed 120 accounts, 30,000 journal entries, 5,000 posted entries into a dedicated test database; create and hash its backup. Validate API endpoints and fixed fixture IDs.
- [ ] Confirm both builds pass and perform focused accounting/report tests. Run an unmeasured 500-user pilot through the full hold; prove **500 concurrent active threads**, JMeter headroom, no OOM, database health, and workable caps. During the scored hold, the generator gate requires fewer than 1% CPU-quota periods throttled and p95 cgroup CPU usage below 90% of its cap. Peak memory must stay below 95% of its cap and no OOM/swap activity may occur anywhere in the run. The pilot fails if it merely starts 500 thread names sequentially. Freeze caps, image digests, JMX, seed, and phase durations after the valid pilot; repeat the pilot if any change.

### Task 3: Execute paired profiles

- [ ] For each revision and each profile, restore the pristine database; start a fresh API process; record initial and post-start DB indexes, row counts, and health; apply an equal warmup outside the scored window.
- [ ] Score 50/100/500 at 2-minute ramp + 10-minute hold, then let JMeter run a further **30 unscored seconds** before shutdown. Score soak at 2-minute ramp + 45-minute hold with the same 30-second shutdown buffer. For spike, score a 30-second ramp to 100 + 2-minute 100-user base, a 30-second ramp to 500 + 5-minute 500-user peak, then allow a **30-second unscored drain** before scoring 5 minutes of 100-user recovery; retain another 30-second unscored shutdown buffer. The first diagnostic p500 run lost active threads in its final 10 seconds, so these buffers were added before any scored run. Use actual active-thread telemetry to establish windows and do not claim a measured gradual ramp-down.
- [ ] Run **three paired repetitions** per profile, alternating order (before/after, after/before, before/after). New database restoration and fresh API process are required for every repetition. Expected measured load time is about **10 hours** plus startup, restore, pilot, and analysis; schedule it when the machine can remain otherwise idle.
- [ ] Sample API, SQL, and JMeter container CPU, memory, CPU-throttle time, OOM events, host free RAM, host CPU, swap activity, and disk activity at 5-second intervals; capture active users and requests/sec. Record process/container inventory before and after each pair. Abort/flag a run if a process crashes, OOMs, the generator saturates, fixtures change unexpectedly, the predeclared active-thread hold gate fails, or unrelated host work starts. Repeat an invalid **pair**, not only its slower side.

### Task 4: Analyze and write the evidence

- [ ] Verify JTL/report/telemetry hashes and complete run manifests; exclude only invalid runs with a recorded reason, then rerun the pair under the same frozen protocol.
- [ ] Compute per-profile and per-endpoint p50/p95/p99, error %, throughput, median of three paired results, range, absolute and percentage change; show hold/soak/spike phases separately. Report CPU/RAM peaks and time series, throttling/OOM, host background activity, and whether resource caps were binding. State that a same-host result is less isolated than a dedicated-host result even when all Docker caps are enforced.
- [ ] Apply predeclared gates without revision. Place September 2026 and March 2026 results in a separate historical-context section because their profile protocol/resource controls differ. Explain any disagreement with new evidence rather than replacing it.
- [ ] Link each tested source SHA and relevant changed files to the measured result. Keep claims about ChatGPT's role limited to the verified interaction record. Map performance-method and interpretation claims to Chapter 2 references; add and verify scholarly citations before changing the final report.
- [ ] Review `comparison.md` and evidence pack for reproducibility and data leakage. Update the thesis final report only after the controlled comparison is complete and the chapter citations are validated.

## Method references

- [Docker Engine resource constraints](https://docs.docker.com/engine/containers/resource_constraints/) documents CPU and hard memory limits.
- [Docker Compose service attributes](https://docs.docker.com/reference/compose-file/services/) defines `cpus`, `mem_limit`, and `memswap_limit`.
- [Microsoft SQL Server memory guidance for containers](https://learn.microsoft.com/en-us/sql/linux/configure/performance-best-practices-sql-server-memory?view=sql-server-ver17) supports a SQL memory setting below the container cap and identifies SQL Server 2022 CU20 as the start of cgroup v2 awareness.
- [Apache JMeter Thread Group reference](https://jmeter.apache.org/usermanual/component_reference.html) explains scheduling and loop termination; [JMeter best practices](https://jmeter.apache.org/usermanual/best-practices.html) recommends non-GUI load generation and monitoring the generator.
