# Plan: Fix Issues & Retest (SonarQube, ZAP, JMeter)

> **Purpose:** Fix all issues found in the baseline-v0.1 scan results, retest each tool, and compare before/after.
> **Base branch:** `baseline-v0.1` (contains all baseline scan results)
> **Runner:** Codex GPT 5.4

---

## Prerequisites

- Docker running with containers: `sonarqube`, `zap`, `jmeter`
- .NET 8.0 SDK installed
- API can be started with `dotnet run --project API`
- All scripts are in `scripts/phase4/` (PowerShell)
- Baseline results (before-fix) are already saved in `baseline-v0.1`

---

## Phase 1 — SonarQube

### 1.1 Switch branch

```bash
git checkout baseline-sonarqube-v1
```

### 1.2 Read baseline SonarQube results

Scan results are in:
- `.sonarqube/out/0/Issues.json` (MODEL module)
- `.sonarqube/out/1/Issues.json` (BAL module)
- `.sonarqube/out/2/Issues.json` (API module)
- `.sonarqube/out/3/Issues.json` (REPOSITORY module)
- `.sonarqube/out/4/Issues.json` (Tests module)

Also check SonarQube web dashboard at `http://localhost:9000` project `financial-accounting` for the full issue list (bugs, code smells, vulnerabilities, security hotspots).

Use the summary script to get an overview:

```powershell
./scripts/phase4/get-sonar-summary.ps1
```

### 1.3 Fix all issues

For each issue found:
1. Read the issue description, severity, and affected file/line
2. Apply the fix in the source code
3. Record the fix in the tracking document (see 1.4)

Common SonarQube issue categories to expect:
- **Bugs:** Null reference risks, logic errors
- **Code Smells:** Unused variables, duplicated code, naming conventions
- **Vulnerabilities:** Hardcoded credentials, SQL injection risks, insecure configurations
- **Security Hotspots:** Review-required items (CORS, crypto, etc.)

### 1.4 Record all fixes

Create `Document/sonarqube-fixes.md` with this format:

```markdown
# SonarQube Issue Fixes

| # | Issue ID | Severity | Type | File | Line | Description | Fix Applied |
|---|----------|----------|------|------|------|-------------|-------------|
| 1 | ... | Major | Bug | API/Controllers/X.cs | 42 | Null dereference | Added null check |
| 2 | ... | Minor | Code Smell | BAL/Services/Y.cs | 15 | Unused variable | Removed variable |
```

### 1.5 Rerun SonarQube scan

```powershell
./scripts/phase4/run-sonarqube-scan.ps1 -SonarToken "<token>" -ProjectVersion "1.1"
```

### 1.6 Save new results

Save the scan summary and screenshot/export from the SonarQube dashboard.
Update `Document/sonarqube-fixes.md` with a **Results After Fix** section showing:
- Total issues before vs after
- Remaining issues (if any)
- Quality gate status (pass/fail)

### 1.7 Commit

```bash
git add -A
git commit -m "fix: resolve SonarQube issues from baseline scan"
git push origin baseline-sonarqube-v1
```

---

## Phase 2 — OWASP ZAP

### 2.1 Switch branch

```bash
git checkout baseline-zap-v1
```

### 2.2 Read baseline ZAP results

Scan results are in `Document/security/`:
- `zap-baseline-20260323-001410.json` — Baseline scan (JSON)
- `zap-baseline-20260323-001410.md` — Baseline scan (Markdown, human-readable)
- `zap-api-20260323-001410.json` — Authenticated API scan (JSON)
- `zap-api-20260323-001410.md` — API scan (Markdown)

Read the markdown reports to get the full alert list.

**Known baseline alerts (2026-03-23):**
- Medium: Content Security Policy header missing, Vulnerable JS Library
- Low: CORS misconfiguration, X-Content-Type-Options missing, and others
- Informational: 3 alerts

### 2.3 Fix all issues

For each ZAP alert:
1. Identify the root cause (missing header, misconfigured middleware, vulnerable dependency)
2. Apply the fix — typically in `API/Program.cs` or middleware configuration
3. Record the fix

Common ZAP fixes:
- **CSP Header:** Add `Content-Security-Policy` header in middleware
- **X-Content-Type-Options:** Add `X-Content-Type-Options: nosniff` header
- **CORS:** Restrict CORS origins instead of wildcard `*`
- **Vulnerable JS Library:** Update NuGet packages / frontend dependencies
- **Anti-CSRF:** Ensure tokens are used for state-changing operations
- **Cookie flags:** Set `Secure`, `HttpOnly`, `SameSite` on cookies

### 2.4 Record all fixes

Create `Document/zap-fixes.md` with this format:

```markdown
# ZAP Security Issue Fixes

| # | Alert Name | Risk Level | CWE | Affected URL/Endpoint | Fix Applied |
|---|------------|------------|-----|----------------------|-------------|
| 1 | CSP Header Not Set | Medium | CWE-693 | All endpoints | Added CSP middleware in Program.cs |
| 2 | X-Content-Type-Options | Low | CWE-693 | All endpoints | Added nosniff header |
```

### 2.5 Rerun ZAP scans

Start the API first:

```bash
dotnet run --project API &
```

Then run both scans:

```powershell
./scripts/phase4/run-zap-baseline.ps1
./scripts/phase4/run-zap-api.ps1
```

### 2.6 Save new results

New reports will be saved to `Document/security/` with updated timestamps.
Update `Document/zap-fixes.md` with a **Results After Fix** section showing:
- Alert count before vs after (by severity)
- Remaining alerts (if any)

### 2.7 Commit

```bash
git add -A
git commit -m "fix: resolve ZAP security alerts from baseline scan"
git push origin baseline-zap-v1
```

---

## Phase 3 — JMeter

### 3.1 Switch branch

```bash
git checkout baseline-jmeter-v1
```

### 3.2 Read baseline JMeter results

Results are in `Document/performance/`:
- `jmeter-20260323-002542-p50.jtl` — 50 concurrent users
- `jmeter-20260323-002542-p100.jtl` — 100 concurrent users
- `jmeter-20260323-002542-p500.jtl` — 500 concurrent users
- `jmeter-20260323-002542-soak.jtl` — Soak/endurance test
- `jmeter-20260323-002542-spike.jtl` — Spike test

HTML reports in `Document/performance/report-20260323-002542-*/index.html`

Benchmark thresholds are defined in `Document/performance/benchmark-report-latest.md`.

Check for:
- Endpoints with high error rates
- Endpoints with response times exceeding thresholds
- Throughput bottlenecks
- Failed assertions

### 3.3 Fix performance issues

For each performance issue:
1. Identify the slow or failing endpoint
2. Profile the code path (controller → service → repository → database)
3. Apply optimizations

Common JMeter/performance fixes:
- **Slow queries:** Add database indexes, optimize LINQ queries, reduce N+1 queries
- **High error rate:** Fix thread-safety issues, connection pool exhaustion, timeout settings
- **Memory pressure:** Reduce allocations, add response caching, pagination
- **Throughput:** Add response compression, async processing, connection pooling tuning
- **Spike failures:** Add rate limiting, circuit breakers, retry policies

### 3.4 Record all fixes

Create `Document/jmeter-fixes.md` with this format:

```markdown
# JMeter Performance Issue Fixes

| # | Endpoint | Issue | Metric Before | Fix Applied | Expected Impact |
|---|----------|-------|---------------|-------------|-----------------|
| 1 | GET /api/accounts | Slow response >2s at p95 | p95: 2300ms | Added DB index on AccountNumber | Reduced query time |
| 2 | POST /api/transactions | High error rate at 500 users | 12% errors | Fixed connection pool size | Reduced connection exhaustion |
```

### 3.5 Rerun JMeter tests

Start the API first:

```bash
dotnet run --project API --configuration Release &
```

Then run the test matrix:

```powershell
./scripts/phase4/run-jmeter-thesis-matrix.ps1
```

Or run individual profiles:

```powershell
./scripts/phase4/run-jmeter-profile.ps1 -Profile p50
./scripts/phase4/run-jmeter-profile.ps1 -Profile p100
./scripts/phase4/run-jmeter-profile.ps1 -Profile p500
./scripts/phase4/run-jmeter-profile.ps1 -Profile soak
./scripts/phase4/run-jmeter-profile.ps1 -Profile spike
```

### 3.6 Save new results

New JTL files and HTML reports will be saved to `Document/performance/` with new timestamps.
Update `Document/jmeter-fixes.md` with a **Results After Fix** section showing:
- Response time before vs after (avg, p95, p99) per endpoint
- Error rate before vs after
- Throughput before vs after
- Pass/fail against benchmark thresholds

### 3.7 Commit

```bash
git add -A
git commit -m "fix: resolve JMeter performance issues from baseline test"
git push origin baseline-jmeter-v1
```

---

## Phase 4 — Summary & Comparison

### 4.1 Gather all results

Collect the before/after data from:
- `Document/sonarqube-fixes.md`
- `Document/zap-fixes.md`
- `Document/jmeter-fixes.md`

### 4.2 Create comparison report

Create `Document/baseline-comparison-report.md`:

```markdown
# Baseline Comparison Report
## baseline-v0.1 (before) vs v1 branches (after)

### SonarQube Code Quality
| Metric | Before (baseline-v0.1) | After (baseline-sonarqube-v1) | Change |
|--------|----------------------|-------------------------------|--------|
| Bugs | X | Y | -Z |
| Vulnerabilities | X | Y | -Z |
| Code Smells | X | Y | -Z |
| Security Hotspots | X | Y | -Z |
| Quality Gate | FAIL/PASS | PASS | ✓ |

### ZAP Security
| Severity | Before (baseline-v0.1) | After (baseline-zap-v1) | Change |
|----------|----------------------|-------------------------|--------|
| High | 0 | 0 | — |
| Medium | 2 | Y | -Z |
| Low | 6 | Y | -Z |
| Informational | 3 | Y | -Z |

### JMeter Performance
| Metric | Before (baseline-v0.1) | After (baseline-jmeter-v1) | Change |
|--------|----------------------|----------------------------|--------|
| Avg Response Time (p50) | Xms | Yms | -Z% |
| p95 Response Time (p100) | Xms | Yms | -Z% |
| Error Rate (p500) | X% | Y% | -Z% |
| Throughput (p100) | X req/s | Y req/s | +Z% |
| Soak Test Stability | ... | ... | ... |
| Spike Recovery | ... | ... | ... |
```

### 4.3 Commit the comparison report

```bash
git checkout baseline-v0.1
# or whichever branch you want the summary on
git add Document/baseline-comparison-report.md
git commit -m "docs: add baseline comparison report (before vs after fixes)"
git push
```

---

## Branch Summary

| Branch | Purpose | Tool | Status |
|--------|---------|------|--------|
| `baseline-v0.1` | Original baseline (read-only reference) | All | Baseline |
| `baseline-sonarqube-v1` | SonarQube fixes + retest | SonarQube | Pending |
| `baseline-zap-v1` | ZAP security fixes + retest | OWASP ZAP | Pending |
| `baseline-jmeter-v1` | Performance fixes + retest | JMeter | Pending |

---

## Notes

- Do NOT modify `baseline-v0.1` — it is the reference baseline for comparison
- Each branch is independent — fixes in one branch should not depend on another
- If a fix in one tool's branch would also fix issues from another tool, note it in the fix document but only apply it in the relevant branch
- All scripts assume Docker containers are running — start them with `./scripts/phase4/install-tools.ps1` if needed
- The API runs on `http://localhost:5296` by default
