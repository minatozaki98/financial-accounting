# Cloud JMeter Experiment Deployment Implementation Plan

> **For implementation:** Use `superpowers:executing-plans` task by task. This plan covers temporary cloud deployment; the companion controlled JMeter plan defines the measurement protocol.

**Goal:** Run one to five controlled before/after JMeter research sessions on temporary, dedicated-CPU cloud servers, preserve reproducible evidence, and remove every billable resource within a $50 total budget.

**Architecture:** Put the ASP.NET Core API and SQL Server on one x86 VM and JMeter on a second x86 VM in the same private network. Build API images from exact before/after Git commits, restore an identical synthetic SQL Server backup before each measured profile, and keep all container CPU/memory limits fixed. Pair the before/after runs on the same VMs and store each session's raw evidence locally before deleting the cloud resources.

**Tech Stack:** Akamai Cloud (Linode) G6 Dedicated VMs, Ubuntu Linux x86-64, Docker Compose, ASP.NET Core 8, SQL Server 2022 Developer, Apache JMeter 5.5, PowerShell, Git.

**Spec:** `docs/superpowers/plans/2026-10-23-controlled-jmeter-before-after.md`; on 2026-10-25 the user narrowed the budget to **$30–$50 total** for the temporary experiment, with no ongoing hosting. Aim for the lowest valid spend; $30 is not a spending minimum.

## Global Constraints

- This is a **plan first** deliverable. Do not create billable resources or run load tests in the planning stage.
- Hard spend ceiling: **$50 total including tax and extras**. Aim to finish below $30; stop starting new runs at **$40 accrued/projected**, leaving $10 for rounding and final charges. Do not commit to ongoing hosting or add a managed database, backup, snapshot, load balancer, or NAT gateway.
- Selected source revisions: before `7a0469d9401a3061941b44fcd46b3beca1c9c729`; after `78b08b62570dcf6fe436354e8e6b770ab2074445`. Treat any further ChatGPT-assisted fix as a new committed candidate and new experimental round.
- Keep the current dirty checkout and unrelated worktrees intact. Prepare the harness on its own branch/worktree; do not merge source branches.
- Only synthetic accounting data may leave the local machine. Do not expose SQL Server or the research API publicly; JMeter reaches the API over the provider's private VLAN/VPC. SSH access must be restricted to the operator.
- Pin the SQL Server, .NET, and JMeter image digests. Use the same image builds, resource caps, seed backup, credentials policy, JMX hashes, warmup, and profile timing for both sides of a pair.
- No existing corporate/sponsor Azure subscription may be used without the user explicitly identifying an authorized subscription; the local Azure CLI has several unrelated enabled subscriptions. No Akamai, DigitalOcean, or Hetzner CLI/token was available in this shell at planning time.
- The user handles payment and any provider-required identity, email, or MFA verification. Once account access is available, Codex can handle technical provisioning, deployment, test runs, evidence, cost checks, and teardown.
- Price, tax, region stock, account limits, and final checkout charges must be checked live before provisioning; quoted figures below are an estimate, not an invoice.

## Review Focus

- Account cannot provision both dedicated sizes: stop; do not switch to shared CPU or another subscription without a new price and protocol check.
- Provider silently changes VM CPU model or region between paired sides: mark the pair invalid and repeat it on one fixed environment.
- Database backup, index state, or fixture IDs differ: stop before collecting a result; restore and verify again.
- JMeter generator has more than 1% CPU-quota periods throttled **during the scored hold**, p95 cgroup CPU use reaches 90% of its cap during that hold, swaps or OOMs anywhere in the run, or misses target active users: mark the run invalid instead of attributing latency to the API. Startup and ramp CPU spikes are recorded but excluded from the hold CPU gate. The old March JTLs recorded only 21–22 simultaneous threads in runs labeled 500 VU.
- Artifact transfer or cost watchdog fails: stop new tests, export available evidence, and destroy resources at the deadline; record missing evidence.

## Host choice and price snapshot

**Cheapest tier that passed the full generator headroom pilot:** Akamai Cloud **Singapore 2 (`sg-sin-2`)** G6 Dedicated. The older Singapore region (`ap-south`) lacks VPC support. The signed-in Singapore 2 creation form and API confirmed G6 Dedicated 8 GB/4 vCPU at $0.108/hour and 4 GB/2 vCPU at $0.054/hour on 2026-10-25. The smaller generator sustained 500 users but had 1.97% CPU-quota periods throttled during the scored hold, above the 1% generator limit, so it was rejected. The 8 GB/4 vCPU generator then passed the full p500 pilot with zero scored-hold throttling. The [Akamai CPU price list](https://www.akamai.com/cloud/pricing/cpu) specifies:

| VM | Published size | Hourly rate | Use |
| --- | --- | ---: | --- |
| Target | G6 Dedicated 8 GB, 4 vCPU, 160 GB SSD | $0.108 | API container 2 vCPU/2 GiB + SQL container 2 vCPU/4 GiB; 2 GiB remains for Linux/Docker and cache. Pilot must prove this headroom is sufficient. |
| Generator | G6 Dedicated 8 GB, 4 vCPU, 160 GB maximum SSD allocation | $0.108 | JMeter container 4 vCPU/4 GiB, with a 2 GiB Java heap. Final pilot must prove generator headroom again. |

Together: **$0.216/hour**, **$5.18 for 24 hours**, or **$25.92 for five 24-hour sessions** (120 billable hours), before tax. [Akamai lists 7% VAT for a Thai billing address](https://techdocs.akamai.com/cloud-computing/docs/tax-information), making the 120-hour compute estimate about **$27.73** if that rate applies. [Akamai rounds usage up to the nearest hour for services with a monthly cap](https://techdocs.akamai.com/cloud-computing/docs/understanding-how-billing-works), and resizing creates separate line items, so the actual charge can exceed the simple duration estimate. The short diagnostic trials on both generator sizes add one-time usage. The two VMs share a [free private VPC](https://techdocs.akamai.com/cloud-computing/docs/vpc), so measured API traffic stays private. Record any outbound artifact-transfer charge. VMs bill while powered off; delete them after use.

**Capacity fallback, only before scoring:** If the target host itself lacks memory/CPU headroom independent of the API/SQL caps, resize the target to G6 Dedicated 16 GB/8 vCPU ($0.216/hour) and repeat the pilot. With the 8 GB/4 vCPU generator the pair costs **$0.324/hour**, or **$38.88 for 120 hours before tax** (about $41.60 at 7% VAT). Freeze the successful sizes before any scored run.

**Price alternatives:** [DigitalOcean](https://www.digitalocean.com/pricing/droplets) lists a 4 vCPU/16 GiB General Purpose target plus 4 vCPU/8 GiB CPU-Optimized generator at $0.3125/hour, but its [new-account tiers](https://docs.digitalocean.com/platform/resource-limits/) can block the target and immediate Tier 3 prepayment is $250, outside this budget. [Hetzner](https://docs.hetzner.com/general/infrastructure-and-availability/price-adjustment/) lists two CCX23 dedicated 4 vCPU/16 GB VMs in Europe at about $0.3272/hour including two primary IPv4 addresses, but its public product page marked the type unavailable at inspection. Do not depend on either alternative until access and live stock are confirmed.

## File and artifact map

- Reuse the JMX and gate design from the companion plan. Create an isolated `codex/jmeter-cloud-harness` branch/worktree for technical scripts.
- Use `scripts/phase4/cloud-jmeter/provision.py` and `replace_generator.py` (provider price/stock preflight and resource IDs), `bootstrap-host.sh`, `restore-db.sh`, `run_matrix.py`, `collect_metrics.py`, and `teardown.py`. Keep the token and passwords in the ignored, access-restricted experiment state directory.
- Store the infrastructure manifest, VM size/CPU model, image digests, configuration hashes, synthetic backup hash, private-network details, run manifests, JTLs, telemetry, and comparisons under a new `Document/experiments/jmeter-cloud-20261023/` evidence directory. Never store provider tokens, SQL passwords, or JWTs there.
- Produce a cost ledger per session with UTC creation/deletion times, billable hours, published hourly rates, tax estimate, actual invoice when available, and all resource IDs. Do not put secret values into logs.

## Tasks

### Task 1: Prepare and check account access

- [ ] Verify the user has an Akamai Cloud account with a valid payment method, can complete required email/identity/MFA steps, and can authorize a narrowly scoped temporary API token. The user enters payment and verification details; Codex does not collect or store them.
- [ ] Recheck **Singapore 2 (`sg-sin-2`)** `g6-dedicated-4` availability for **two** VMs, actual account limits, server prices, tax location, public-IP fees, and projected total. Keep `g6-dedicated-8` as the pre-scoring target-host fallback. If the sizes are unavailable, price another two-host dedicated-CPU option without altering the benchmark protocol, and keep the total below the $40 operational stop target.
- [ ] Set up a cost ledger and local 24-hour session timer. Confirm that all resource IDs created by this experiment can be deleted without touching unrelated resources.

### Task 2: Prepare immutable experiment software

- [ ] Create two detached source checkouts at the exact commits; build both API images with one common Dockerfile and .NET runtime. Run focused startup/accounting tests. Record the source diff and image digests.
- [ ] Build a dedicated SQL Server 2022 Developer image at a pinned CU20-or-later digest and a pinned JMeter 5.5 image. Override the API's `AppSettings__ConnectionStrings` so it uses the private SQL Server container with SQL authentication instead of the checked-in localhost Windows trusted connection. Provide secrets to the VMs securely and ensure they are absent from command lines, Git, JTL, and published manifests.
- [ ] Version the profile JMX files and verify the 50/100/500 user mix, 45-minute soak, spike phase timing, gate definitions, JMeter version, test plan hashes, and synthetic seed against the companion plan. Reject automatic fallback of account/period IDs. Use duration-bound looping and 5-second active-thread telemetry so the nominal VU count can be checked against actual simultaneous users.

### Task 3: Provision and pilot

- [ ] Provision an 8 GB/4 vCPU target and 8 GB/4 vCPU generator in **Singapore 2** with one private VPC. Give each a VPC address plus public access through VPC 1:1 NAT for SSH and official image downloads; restrict ingress to operator SSH and allow measured API traffic only over VPC. Expose neither SQL port nor API to the public internet. Verify both VM sizes in the guest OS, CPU model, disk, private IPs, clock synchronization, and container cgroup support.
- [ ] On the target host, set API 2 vCPU/2 GiB and SQL 2 vCPU/4 GiB; set SQL `MSSQL_MEMORY_LIMIT_MB=3072`. On the generator host, set JMeter 4 vCPU/4 GiB. Set each container's swap limit equal to its memory limit, disable host swap during scored runs, and inspect effective cgroup limits.
- [ ] Seed 120 accounts, 30,000 journal entries, and 5,000 posted entries; create/hash one SQL backup. Run an unmeasured 500-user pilot through a full hold interval and prove that 500 users are simultaneously active and sustained under the companion plan's explicit concurrency gate. Also prove generator headroom, no OOM/swap, healthy SQL/API, at least 1 GiB target-host available memory throughout the hold, enough disk, and telemetry collection. Freeze the protocol and VM sizes after the pilot.
- [ ] If the pilot fails because JMeter itself is saturated, increase only the generator size/cap, recalculate the five-session cost under the $40 operational target, and repeat the pilot before freezing the protocol. If the target host lacks memory/CPU headroom independent of the API/SQL container caps, resize only the target to G6 Dedicated 16 GB/8 vCPU and repeat the pilot. If the API is slow while the host is healthy and 500 users remain active, retain that as a valid result; do not tune the measured API after seeing a scored run.

### Task 4: Run one to five paired sessions

- [ ] Run the five profiles on the before and after revisions with the same VMs, private network, SQL image, restored backup, resource caps, warmup, and test-plan hashes. Restore the pristine backup before every run; record the after revision's startup-created indexes. Do not score a 50/100/500 profile unless its recorded active-thread series passes the concurrency gate; rerun both sides of an invalid pair.
- [ ] Run three paired repetitions per profile using alternating AB/BA/AB order. Capture JTL, active-user counts, per-endpoint latency, throughput, error rate, API/SQL/generator CPU/RAM, CPU throttling, OOM, disk, network, and cost by run. A full matrix is about ten hours of measured load plus setup and restores.
- [ ] After each session, sync and checksum evidence to the local workspace and check accrued cost. If another fix is attempted, freeze it as a new commit and identify a new session; compare it against the same baseline under the frozen protocol.
- [ ] Use no more than **120 combined hours per VM pair** across the one to five sessions unless a fresh estimate still leaves the total below $40 and the user extends the experiment. Prefer contiguous sessions; if VMs are recreated, treat the new machine as a separate experimental block and do not pool its absolute latency with the old one without qualification.

### Task 5: Analyze, report, and stop billing

- [ ] Compute per-profile and per-endpoint paired p95/p99, errors, throughput, resource usage, and three-repeat spread. Apply the predeclared gates even if they fail. Keep the historical March/September results separate because their environment and profile definitions differ.
- [ ] Write the comparison with before/after commit links, prompts and human actions that can be verified, runtime/cost manifest, reproducibility limits, and relevant Chapter 2 literature citations. Add legitimate scholarly sources to Chapter 2 before relying on unsupported interpretation claims.
- [ ] Verify all required artifacts exist locally, then destroy every experiment VM, private-network component, token, and optional billable resource created for the study. Confirm via provider API that no experiment resources remain and capture the final invoice/estimated charge when available. Powered-off VMs are not a teardown.
