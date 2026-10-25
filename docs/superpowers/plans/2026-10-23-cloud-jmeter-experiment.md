# Cloud JMeter Experiment Deployment Implementation Plan

> **For implementation:** Use `superpowers:executing-plans` task by task. This plan covers temporary cloud deployment; the companion controlled JMeter plan defines the measurement protocol.

**Goal:** Run one to five controlled before/after JMeter research sessions on temporary, dedicated-CPU cloud servers, preserve reproducible evidence, and remove every billable resource within a $100 total budget.

**Architecture:** Put the ASP.NET Core API and SQL Server on one x86 VM and JMeter on a second x86 VM in the same private network. Build API images from exact before/after Git commits, restore an identical synthetic SQL Server backup before each measured profile, and keep all container CPU/memory limits fixed. Pair the before/after runs on the same VMs and store each session's raw evidence locally before deleting the cloud resources.

**Tech Stack:** Akamai Cloud (Linode) G6 Dedicated VMs, Ubuntu Linux x86-64, Docker Compose, ASP.NET Core 8, SQL Server 2022 Developer, Apache JMeter 5.5, PowerShell, Git.

**Spec:** `docs/superpowers/plans/2026-10-23-controlled-jmeter-before-after.md` and the user's 2026-10-23 clarification: $20–$100 **total** for one to five research attempts, with no ongoing hosting.

## Global Constraints

- This is a **plan first** deliverable. Do not create billable resources or run load tests in the planning stage.
- Hard spend ceiling: **$100 total**. Operational stop target: **$80 including tax and extras**, leaving $20 of margin. Do not commit to ongoing hosting or add a managed database, backup, snapshot, load balancer, or NAT gateway.
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
- JMeter generator is CPU-throttled, swaps, or misses target active users: mark the run invalid instead of attributing latency to the API. The old March JTLs recorded only 21–22 simultaneous threads in runs labeled 500 VU.
- Artifact transfer or cost watchdog fails: stop new tests, export available evidence, and destroy resources at the deadline; record missing evidence.

## Host choice and price snapshot

**Preferred:** Akamai Cloud Singapore (`ap-south`) G6 Dedicated. The provider's public region-availability API returned `available: true` for both `g6-dedicated-8` and `g6-dedicated-4` on 2026-10-23 and again on 2026-10-24; recheck the user's account and live checkout before use. [Akamai's CPU price list](https://www.akamai.com/cloud/pricing/cpu) specifies:

| VM | Published size | Hourly rate | Use |
| --- | --- | ---: | --- |
| Target | G6 Dedicated 16 GB, 8 vCPU, 320 GB SSD | $0.216 | API container 2 vCPU/2 GiB + SQL container 2 vCPU/4 GiB. Extra host capacity supplies stable headroom. |
| Generator | G6 Dedicated 8 GB, 4 vCPU, 160 GB SSD | $0.108 | JMeter container 4 vCPU/4 GiB. |

Together: **$0.324/hour**, **$7.78 for 24 hours**, **$23.33 for 72 hours**, or **$38.88 for five 24-hour sessions** (120 billable hours), before tax. [Akamai lists 7% VAT for a Thai billing address](https://techdocs.akamai.com/cloud-computing/docs/tax-information), making the 120-hour compute estimate about **$41.60** if that rate applies. The two VMs must share a [free private VLAN/VPC](https://techdocs.akamai.com/cloud-computing/docs/network-transfer-usage-and-costs/), so measured API traffic does not consume paid public egress. Record any outbound artifact-transfer charge. VMs bill while powered off; delete them after use.

**Price alternatives:** [DigitalOcean](https://www.digitalocean.com/pricing/droplets) lists a 4 vCPU/16 GiB General Purpose target plus 4 vCPU/8 GiB CPU-Optimized generator at $0.3125/hour, but its [new-account tiers](https://docs.digitalocean.com/platform/resource-limits/) can block the target and immediate Tier 3 prepayment is $250, outside this budget. [Hetzner](https://docs.hetzner.com/general/infrastructure-and-availability/price-adjustment/) lists two CCX23 dedicated 4 vCPU/16 GB VMs in Europe at about $0.3272/hour including two primary IPv4 addresses, but its public product page marked the type unavailable at inspection. Do not depend on either alternative until access and live stock are confirmed.

## File and artifact map

- Reuse the JMX and gate design from the companion plan. Create an isolated `codex/jmeter-cloud-harness` branch/worktree for technical scripts.
- Create `scripts/phase4/cloud-jmeter/provision.ps1` (provider API and price/limit preflight), `bootstrap-target.sh` (Docker and SQL/API host), `bootstrap-generator.sh` (JMeter host), `run-session.ps1` (pair scheduling, DB restore, budget checks), `collect-metrics.sh` (container/host telemetry), and `teardown.ps1` (artifact check and resource deletion).
- Store the infrastructure manifest, VM size/CPU model, image digests, configuration hashes, synthetic backup hash, private-network details, run manifests, JTLs, telemetry, and comparisons under a new `Document/experiments/jmeter-cloud-20261023/` evidence directory. Never store provider tokens, SQL passwords, or JWTs there.
- Produce a cost ledger per session with UTC creation/deletion times, billable hours, published hourly rates, tax estimate, actual invoice when available, and all resource IDs. Do not put secret values into logs.

## Tasks

### Task 1: Prepare and check account access

- [ ] Verify the user has an Akamai Cloud account with a valid payment method, can complete required email/identity/MFA steps, and can authorize a narrowly scoped temporary API token. The user enters payment and verification details; Codex does not collect or store them.
- [ ] Recheck Singapore `g6-dedicated-8` and `g6-dedicated-4` availability, actual account limits, server prices, tax location, public-IP fees, and projected total. If either size is unavailable, price the fallback without altering the benchmark protocol, then select only a two-host dedicated-CPU option below the $80 operational stop target.
- [ ] Set up a cost ledger and local 24-hour session timer. Confirm that all resource IDs created by this experiment can be deleted without touching unrelated resources.

### Task 2: Prepare immutable experiment software

- [ ] Create two detached source checkouts at the exact commits; build both API images with one common Dockerfile and .NET runtime. Run focused startup/accounting tests. Record the source diff and image digests.
- [ ] Build a dedicated SQL Server 2022 Developer image at a pinned CU20-or-later digest and a pinned JMeter 5.5 image. Override the API's `AppSettings__ConnectionStrings` so it uses the private SQL Server container with SQL authentication instead of the checked-in localhost Windows trusted connection. Provide secrets to the VMs securely and ensure they are absent from command lines, Git, JTL, and published manifests.
- [ ] Version the profile JMX files and verify the 50/100/500 user mix, 45-minute soak, spike phase timing, gate definitions, JMeter version, test plan hashes, and synthetic seed against the companion plan. Reject automatic fallback of account/period IDs. Use duration-bound looping and 5-second active-thread telemetry so the nominal VU count can be checked against actual simultaneous users.

### Task 3: Provision and pilot

- [ ] Provision two dedicated VMs in one Singapore region and one private network. Restrict ingress to operator SSH; expose neither SQL port nor API to the public internet. Verify both VM sizes, CPU model, disk, private IPs, clock synchronization, and container cgroup support.
- [ ] On the target host, set API 2 vCPU/2 GiB and SQL 2 vCPU/4 GiB; set SQL `MSSQL_MEMORY_LIMIT_MB=3072`. On the generator host, set JMeter 4 vCPU/4 GiB. Set each container's swap limit equal to its memory limit and inspect effective runtime limits.
- [ ] Seed 120 accounts, 30,000 journal entries, and 5,000 posted entries; create/hash one SQL backup. Run an unmeasured 500-user pilot through a full hold interval and prove that 500 users are simultaneously active and sustained under the companion plan's explicit concurrency gate. Also prove generator headroom, no OOM/swap, healthy SQL/API, enough disk, and telemetry collection. Freeze the protocol and VM sizes after the pilot.
- [ ] If the pilot fails because JMeter itself is saturated, increase only the generator size/cap, recalculate the five-session cost under the $80 operational target, and repeat the pilot before freezing the protocol. If the API is slow while 500 users remain active, retain that as a valid result; do not tune the measured API after seeing a scored run.

### Task 4: Run one to five paired sessions

- [ ] Run the five profiles on the before and after revisions with the same VMs, private network, SQL image, restored backup, resource caps, warmup, and test-plan hashes. Restore the pristine backup before every run; record the after revision's startup-created indexes. Do not score a 50/100/500 profile unless its recorded active-thread series passes the concurrency gate; rerun both sides of an invalid pair.
- [ ] Run three paired repetitions per profile using alternating AB/BA/AB order. Capture JTL, active-user counts, per-endpoint latency, throughput, error rate, API/SQL/generator CPU/RAM, CPU throttling, OOM, disk, network, and cost by run. A full matrix is about ten hours of measured load plus setup and restores.
- [ ] After each session, sync and checksum evidence to the local workspace and check accrued cost. If another fix is attempted, freeze it as a new commit and identify a new session; compare it against the same baseline under the frozen protocol.
- [ ] Use no more than **120 combined hours per VM pair** across the one to five sessions unless a fresh estimate still leaves the total below $80 and the user extends the experiment. Prefer contiguous sessions; if VMs are recreated, treat the new machine as a separate experimental block and do not pool its absolute latency with the old one without qualification.

### Task 5: Analyze, report, and stop billing

- [ ] Compute per-profile and per-endpoint paired p95/p99, errors, throughput, resource usage, and three-repeat spread. Apply the predeclared gates even if they fail. Keep the historical March/September results separate because their environment and profile definitions differ.
- [ ] Write the comparison with before/after commit links, prompts and human actions that can be verified, runtime/cost manifest, reproducibility limits, and relevant Chapter 2 literature citations. Add legitimate scholarly sources to Chapter 2 before relying on unsupported interpretation claims.
- [ ] Verify all required artifacts exist locally, then destroy every experiment VM, private-network component, token, and optional billable resource created for the study. Confirm via provider API that no experiment resources remain and capture the final invoice/estimated charge when available. Powered-off VMs are not a teardown.
