# Performance and Security Testing Plan

## 1. Introduction & Objectives

This document defines the performance and security testing plan for the Financial Accounting System API. It serves two purposes: (1) as the formal test specification for the thesis, establishing what is tested, why, and how results are evaluated; and (2) as a repeatable execution guide ensuring every test run uses identical parameters, tools, and criteria.

**Scope — In:**

- Authentication & identity: `/auth`, `/users`
- Accounting core: `/accounts`, `/periods`, `/journal-entries`
- Financial reporting: `/reports/*`
- Compliance: `/audit-logs`
- Health checks: `/health/live`, `/health/ready`

**Scope — Out:**

- Frontend UI performance or security
- External integrations not exposed by this API
- Database administration or infrastructure-level testing

---

## 2. Test Environment & Prerequisites

### Runtime Environment

- API Framework: ASP.NET Core 8.0
- Database: SQL Server (localhost, `Financial` database)
- Host OS: Windows 11
- API URL: `http://0.0.0.0:5296` (Development mode)

### Tool Versions (Containerized)

All testing tools run inside Docker containers to guarantee version consistency across runs.

| Tool | Container Image | Access |
|------|----------------|--------|
| Apache JMeter | `justb4/jmeter:5.5` | CLI via Docker |
| OWASP ZAP | `ghcr.io/zaproxy/zaproxy:stable` | API: `http://localhost:8090`, UI: `http://localhost:8080/zap` |

### Seeded Test Data

Before any test run, the database is seeded with a deterministic dataset to eliminate data variability:

| Parameter | Value | Purpose |
|-----------|-------|---------|
| PeriodId | 202601 | Open accounting period |
| AccountCount | 120 | Chart-of-accounts entries (all 5 types: Asset, Liability, Equity, Revenue, Expense) |
| JournalEntryCount | 30,000 | Total journal entries |
| MinimumPostedEntries | 5,000 | Entries in Posted status |

This volume ensures that report endpoints (trial balance, P&L, balance sheet) operate against a realistic data size representative of a medium-sized organization's monthly transaction volume.

### Pre-seeded User Accounts

| Username | Role | Purpose |
|----------|------|---------|
| admin | Admin | Full-access testing, JMeter load user |
| finance-manager | FinanceManager | RBAC boundary testing |
| normal-user | User | Limited-access testing |
| auditor | Auditor | Read-only testing |

---

## 3. Repeatability Controls

To maintain testing integrity across multiple runs, the following controls are enforced:

1. **Containerized tools** — JMeter and ZAP run in Docker with pinned image tags. No local installation differences can affect results.
2. **Deterministic seed data** — The same seed script with identical parameters runs before every full test suite. This ensures query result sets, report calculations, and data volumes are consistent.
3. **Locked test parameters** — All scenario parameters (user counts, ramp-up times, loop counts, timeouts) are defined in this document and hardcoded in scripts. No parameter is left to operator discretion.
4. **Rule profiles checked into source control** — ZAP rule files (`zap-baseline-rules.tsv`, `zap-api-rules.tsv`) are versioned alongside the code. Any rule change is tracked in git history.
5. **Fixed pass/fail thresholds** — Performance and security gates are defined numerically in this plan and enforced programmatically by the test suite script. Human judgment is not involved in pass/fail determination.
6. **Artifact preservation** — Every run produces timestamped reports (HTML, JSON, Markdown) stored in `Document/performance/` and `Document/security/`. Results from different runs can be compared objectively.

---

## 4. Performance Testing (JMeter)

### 4.1 Theory: Load, Soak, and Spike Testing

Performance testing validates that a system meets non-functional requirements under varying conditions. This plan employs three distinct test types, each answering a different question:

**Load Testing** measures system behavior under expected and elevated user volumes. It answers: *"Can the system handle its target number of users with acceptable response times and error rates?"* Users ramp up gradually over a defined period, execute a fixed number of request iterations, and the system's throughput, response time percentiles, and error rates are recorded. This is the primary test type and is run at three user levels (50, 100, 500).

**Soak Testing** (also called endurance testing) runs a moderate load over an extended period. It answers: *"Does the system degrade over time?"* Degradation can manifest as memory leaks, connection pool exhaustion, database lock contention, or gradual response time increases. A system that passes a 10-minute load test may still fail after 3 hours of sustained use. The key metric is not absolute performance but **drift** — whether p95 response times at the end of the test are significantly worse than at the beginning.

**Spike Testing** subjects the system to a sudden, extreme surge of users with minimal ramp-up time. It answers: *"Can the system survive a sudden traffic burst and recover gracefully?"* Unlike load testing where users ramp up gradually, spike testing compresses the ramp-up to stress the system's ability to allocate resources quickly. The key metric is **recovery** — whether response times return to baseline after the surge, not just whether the system stays alive during it.

### 4.2 Tool Selection: Why Apache JMeter

Apache JMeter was selected for the following reasons:

1. **Protocol support** — JMeter natively supports HTTP/HTTPS with full control over headers, authentication tokens, and request bodies, which is required for testing JWT-authenticated API endpoints.
2. **Parameterization** — Thread group properties (users, ramp-up, loops) can be injected via command-line arguments, enabling the same `.jmx` test plan to serve multiple scenarios without file modification.
3. **Containerized execution** — The `justb4/jmeter:5.5` Docker image provides a reproducible runtime, eliminating "works on my machine" inconsistencies.
4. **Reporting** — JMeter generates JTL files (raw data) and HTML dashboard reports with statistics including throughput, response time percentiles (p50, p90, p95, p99), and error rates — all required for thesis evidence.
5. **Industry adoption** — JMeter is widely recognized in academic and industry contexts, making test results credible to thesis reviewers.

**Alternatives considered:**

- **k6** — Excellent scripting model but requires JavaScript test scripts, adding a language dependency. JMeter's XML-based plans are more self-contained.
- **Gatling** — Strong reporting but Scala-based, adding complexity. JMeter's Docker approach is simpler for this project's scope.
- **Artillery** — Lightweight but less mature reporting and fewer academic references.

### 4.3 User Count Rationale (50 / 100 / 500)

The three load levels are derived from the target deployment context: a medium-sized organization with an estimated 50–200 concurrent users during peak business hours.

| Level | Users | Rationale |
|-------|------:|-----------|
| **Baseline (p50)** | 50 | Represents typical daily usage — the lower bound of expected concurrency. The system must handle this comfortably with minimal latency. This is the "normal day" scenario. |
| **Peak (p100)** | 100 | Represents peak-hour usage — month-end closing, bulk journal entry posting, simultaneous report generation. This is the realistic upper bound the system should be designed for. |
| **Stress (p500)** | 500 | Represents 2.5× the peak load. This is not an expected scenario but a stress boundary that reveals the system's breaking point. It answers: "How far beyond peak can we push before degradation becomes unacceptable?" Knowing this ceiling is critical for capacity planning. |

This progression (1× → 2× → 10× baseline) is a standard load testing pattern that establishes a performance curve from comfortable to stressed, allowing the thesis to demonstrate how the system's response characteristics change as load increases.

### 4.4 Test Scenarios & Parameters

All parameters are locked. No operator discretion is permitted — every run must use exactly these values.

| Scenario | Users | Ramp-Up (s) | Loops | Mode | Thread Split | Approximate Duration |
|----------|------:|------------:|------:|------|-------------|---------------------|
| **p50 (Baseline Load)** | 50 | 30 | 10 | core | core=50, complex=0 | ~5 min |
| **p100 (Peak Load)** | 100 | 60 | 10 | mixed | core=70, complex=30 | ~10 min |
| **p500 (Stress Load)** | 500 | 180 | 5 | mixed | core=350, complex=150 | ~15 min |
| **Soak (Endurance)** | 100 | 60 | 180 | mixed | core=100, complex=30 | ~3 hours |
| **Spike (Burst)** | 500 | 30 | 20 | mixed | core=350, complex=150 | ~10 min |

**Parameter definitions:**

- **Users** — Number of concurrent simulated users (JMeter threads).
- **Ramp-Up** — Time in seconds to start all threads. A 30s ramp-up for 50 users means 1 new user starts roughly every 0.6 seconds.
- **Loops** — Number of times each thread executes the full request sequence. Higher loops = longer test duration.
- **Mode** — `core` tests only CRUD endpoints; `mixed` adds report-generation endpoints which involve heavier database queries.
- **Thread Split** — How users are distributed between core operations and complex (reporting) operations. In `mixed` mode, 70% of threads execute core operations and 30% execute report queries, reflecting realistic usage patterns where most users perform data entry while fewer generate reports.

**Why these ramp-up times:**

- **p50 (30s):** Quick ramp — the system should handle 50 users appearing within half a minute without stress.
- **p100 (60s):** Moderate ramp — simulates a gradual peak-hour buildup.
- **p500 (180s):** Extended ramp — gives the system time to allocate resources, testing sustained scaling rather than shock.
- **Soak (60s):** Same as peak — the test is about duration, not ramp pressure.
- **Spike (30s):** Deliberately fast ramp for 500 users — this *is* the stress. The compressed ramp-up is the point of a spike test.

### 4.5 Endpoints Under Test

JMeter test plans exercise two categories of endpoints:

**Core Operations (CRUD)** — High-frequency endpoints representing daily accounting work:

| Method | Endpoint | Operation |
|--------|----------|-----------|
| POST | `/auth/login` | Authenticate and obtain JWT token |
| GET | `/accounts` | List chart of accounts |
| GET | `/accounts/{id}` | Retrieve single account |
| GET | `/accounts/{id}/balance` | Retrieve account balance |
| POST | `/journal-entries` | Create draft journal entry |
| GET | `/journal-entries` | List journal entries (paged) |
| GET | `/journal-entries/{id}` | Retrieve single journal entry |
| POST | `/journal-entries/{id}/post` | Post (finalize) a draft entry |
| GET | `/periods` | List accounting periods |

**Complex Operations (Reports)** — Lower-frequency but database-intensive endpoints:

| Method | Endpoint | Operation |
|--------|----------|-----------|
| GET | `/reports/trial-balance?periodId={id}` | Generate trial balance |
| GET | `/reports/profit-loss?periodId={id}` | Generate profit & loss statement |
| GET | `/reports/balance-sheet?periodId={id}` | Generate balance sheet |
| GET | `/reports/account-ledger?periodId={id}&accountId={id}` | Generate account ledger |

**Why this split matters:** Report endpoints execute aggregate queries across thousands of journal entry lines. Under load, they consume significantly more database and CPU resources than simple CRUD operations. The 70/30 thread split in mixed mode reflects realistic usage — most users create and review entries while a smaller number generate reports simultaneously.

### 4.6 Pass/Fail Criteria & Justification

Each scenario has numerically defined gates. A test **passes** only if all conditions are met.

| Scenario | Max Error Rate | Max p95 Response Time | Additional |
|----------|---------------:|----------------------:|------------|
| **p50 (Baseline)** | ≤ 0.5% | ≤ 300 ms | — |
| **p100 (Peak)** | ≤ 1.0% | ≤ 500 ms | — |
| **p500 (Stress)** | ≤ 2.0% | ≤ 1,200 ms | — |
| **Soak (Endurance)** | ≤ 1.0% | — | p95 drift ≤ 20% |
| **Spike (Burst)** | ≤ 3.0% | — | Recovery drift ≤ 20% |

**Why these thresholds:**

- **Error rate** — The baseline scenario allows only 0.5% errors because at normal load, virtually no request should fail. The tolerance increases with load: 1.0% at peak (acknowledging some contention), 2.0% at stress (the system is beyond design capacity), and 3.0% for spike (a sudden burst is inherently disruptive). These are standard industry tolerances for non-mission-critical business applications.

- **p95 response time** — The 95th percentile is used instead of average because averages hide outliers. A 300ms p95 at baseline means 95% of requests complete within 300ms — fast enough that users perceive the system as responsive. At peak (500ms), users experience slight delays but the system remains usable. At stress (1,200ms), noticeable delays are acceptable since the system is operating beyond its design capacity.

- **Drift (soak/spike)** — Absolute response times are less meaningful for soak and spike tests. What matters is *change over time*. A 20% drift threshold means the p95 at the end of the soak test must not exceed 120% of the p95 measured at the beginning. If the system starts at 400ms p95 and ends at 520ms, that is a 30% drift and a failure — indicating a resource leak or degradation pattern. The same logic applies to spike recovery: after the burst subsides, response times must return to within 20% of pre-spike levels.

---

## 5. Security Testing (OWASP ZAP)

### 5.1 Theory: Passive vs Active Scanning

Security scanning operates in two fundamentally different modes:

**Passive Scanning** observes HTTP traffic without modifying requests. The scanner acts as a proxy — it inspects responses for missing security headers, insecure cookie flags, information leakage, and other issues detectable from normal server responses. Passive scanning is safe, non-intrusive, and cannot cause damage to the application. It is appropriate for detecting configuration-level vulnerabilities.

**Active Scanning** sends deliberately malicious or malformed requests to the application — SQL injection payloads, cross-site scripting vectors, path traversal attempts, and other attack patterns. It probes the application's defenses by simulating real attacks. Active scanning can cause unexpected behavior (data corruption, crashes, error floods) and should only be run against test environments, never production. It is appropriate for detecting code-level vulnerabilities.

This plan uses both modes: passive scanning via the **baseline scan** (Section 5.4.1) and active scanning via the **authenticated API scan** (Section 5.4.2). Together, they cover both configuration weaknesses and code-level injection vulnerabilities.

### 5.2 Tool Selection: Why OWASP ZAP

OWASP ZAP (Zed Attack Proxy) was selected for the following reasons:

1. **OWASP alignment** — ZAP is the OWASP Foundation's flagship security testing tool. Using it demonstrates alignment with the OWASP Testing Guide methodology, which is a recognized standard in academic security research.
2. **OpenAPI integration** — ZAP can import an OpenAPI/Swagger specification and automatically generate scan targets for every documented endpoint. This eliminates manual endpoint enumeration and ensures full API coverage.
3. **Authentication support** — ZAP supports scripted authentication flows, allowing it to obtain JWT tokens and scan authenticated endpoints — critical for testing an API where all business routes require authorization.
4. **Customizable rule profiles** — Scan rules can be individually set to IGNORE, WARN, or FAIL via TSV configuration files. This allows the plan to define hard security gates (e.g., SQL injection = FAIL) while tolerating known low-risk findings.
5. **Containerized execution** — The `ghcr.io/zaproxy/zaproxy:stable` Docker image ensures identical scanner behavior across runs.
6. **Multi-format reporting** — ZAP produces HTML (human-readable), JSON (machine-parseable), and Markdown reports from a single scan run.

**Alternatives considered:**

- **Burp Suite** — Industry-leading scanner but the full-featured version requires a commercial license. The free Community Edition lacks automated scanning capabilities needed for repeatable CI/CD integration.
- **Nikto** — Focused on web server misconfiguration. Does not support OpenAPI-driven API scanning or JWT authentication flows.
- **SQLMap** — Specialized for SQL injection only. Does not cover the broader vulnerability categories (XSS, header misconfiguration, CSRF) required for comprehensive security testing.
- **Nuclei** — Template-based scanner with strong community templates, but lacks native OpenAPI import and JWT authentication workflow support. Better suited for infrastructure scanning than API testing.

### 5.3 ZAP Capabilities: Evaluated, Used, and Excluded

ZAP offers a broad set of scanning capabilities. This section documents which were selected, which were excluded, and the rationale for each decision.

**Capabilities Used:**

| Capability | Used In | Purpose |
|------------|---------|---------|
| **Passive Scanner** | Baseline scan | Detect missing security headers, insecure cookies, information leakage |
| **Active Scanner** | API scan | Inject attack payloads (SQLi, XSS) against all endpoints |
| **OpenAPI Import** | API scan | Auto-discover endpoints from `/swagger/v1/swagger.json` |
| **Script Authentication** | API scan | Obtain JWT tokens to scan authenticated routes |
| **Rule Configuration (TSV)** | Both scans | Enforce consistent pass/fail classification across runs |
| **Multi-format Reporting** | Both scans | Generate HTML, JSON, and Markdown artifacts |

**Capabilities Excluded:**

| Capability | Reason for Exclusion |
|------------|---------------------|
| **Traditional Spider** | Designed for HTML-based websites with hyperlinks. This is a JSON API with no navigable HTML pages — the spider would only crawl Swagger UI, providing no additional coverage beyond what OpenAPI import already achieves. |
| **AJAX Spider** | Uses a headless browser to discover JavaScript-rendered content. Irrelevant for a backend API that returns JSON, not HTML. No client-side rendering exists to discover. |
| **Fuzzer** | ZAP's built-in fuzzer sends randomized payloads to discover unexpected behavior. While valuable, the active scanner already performs structured fuzzing with known attack patterns (SQLi, XSS). Adding unstructured fuzzing would increase scan duration significantly without proportional coverage gain for a well-typed API with model validation. |
| **WebSocket Scanner** | The Financial Accounting API does not use WebSocket connections. No endpoints to scan. |
| **DOM-based XSS Scanner** | Targets client-side JavaScript DOM manipulation. Not applicable to a server-side JSON API. |
| **Access Control Testing** | ZAP's access control module requires manual role-endpoint mapping in the ZAP UI. RBAC validation is already covered comprehensively by the integration test suite (85 test cases across 17 endpoints × 5 roles), making ZAP's less precise approach redundant. |
| **Forced Browse / Directory Bruteforce** | Useful for discovering hidden files on web servers. This API uses explicit routing — all endpoints are defined in controllers and documented in OpenAPI. No hidden paths exist to discover. |

### 5.4 Scan Configurations

This plan defines two distinct ZAP scan configurations, each targeting a different attack surface.

#### 5.4.1 Baseline Scan (Passive)

**Purpose:** Detect security misconfigurations visible without authentication — missing HTTP headers, insecure defaults, information leakage in publicly accessible responses.

**Target:** The unauthenticated surface of the API. In suite mode, this targets `/health/live`; in standalone mode, `/swagger`.

**What it checks:**

- Presence and correctness of security headers (CSP, X-Frame-Options, X-Content-Type-Options, HSTS, Referrer-Policy, Permissions-Policy, Cross-Origin headers)
- Cookie security attributes (HttpOnly, Secure, SameSite)
- Cache-control directives (no-store for sensitive responses)
- Information leakage (server version disclosure, stack traces, timestamps in responses)

**What it does NOT do:** The baseline scan does not send attack payloads. It only inspects responses from normal requests. It cannot detect SQL injection, XSS, or any vulnerability that requires probing.

**Why run it separately:** Security headers are application-wide — they apply to every response regardless of authentication. Testing them against the unauthenticated surface isolates header configuration from endpoint-specific logic. If headers are misconfigured, this scan catches it without the noise of authentication failures.

#### 5.4.2 Authenticated API Scan (Active)

**Purpose:** Probe all authenticated API endpoints with attack payloads to detect code-level vulnerabilities — injection flaws, broken access controls, and input validation failures.

**Target:** The full API surface discovered via the OpenAPI specification at `/swagger/v1/swagger.json`.

**Authentication flow:**

1. ZAP sends a `POST /auth/login` request with valid credentials
2. Extracts the JWT `accessToken` from the response
3. Injects `Authorization: Bearer <token>` into all subsequent scan requests
4. This ensures every endpoint is tested in its authenticated state, not just returning 401 responses

**What it checks:**

- **SQL Injection** (rules 40018–40021) — Sends SQL metacharacters and tautologies in query parameters, path parameters, and request bodies to detect unsanitized database queries
- **Reflected XSS** (rule 40012) — Injects script tags and JavaScript event handlers into inputs to detect values echoed back in responses without encoding
- **Persistent XSS** (rule 40014) — Injects payloads that may be stored (e.g., in journal entry descriptions) and reflected in subsequent GET requests
- **CSRF token validation** — Checks whether state-changing operations (POST, PUT, DELETE) are protected against cross-site request forgery
- **Path traversal** — Attempts directory traversal sequences (e.g., `../../etc/passwd`) in file-related parameters
- **Parameter tampering** — Modifies numeric IDs, enum values, and boundary values to test input validation

**Why authenticated scanning is critical:** An unauthenticated scan would only see 401 responses from every protected endpoint, providing zero useful security data. The entire attack surface of this API lives behind JWT authentication. Without valid tokens, ZAP cannot reach the code paths where injection vulnerabilities exist.

### 5.5 Rule Profiles & Customization

ZAP's behavior is controlled by two TSV rule files checked into source control. Each rule is assigned one of three actions:

| Action | Meaning |
|--------|---------|
| **FAIL** | A finding on this rule causes the scan to fail with exit code 3+. These are critical vulnerabilities that must be fixed before release. |
| **WARN** | A finding is reported but does not fail the scan (exit code 2). These are configuration items tracked for awareness. |
| **IGNORE** | Findings on this rule are suppressed. Used for known false positives or irrelevant findings from third-party assets (e.g., Swagger UI JavaScript). |

**Baseline Rules (`zap-baseline-rules.tsv`):**

| Rule ID | Description | Action | Rationale |
|---------|-------------|--------|-----------|
| 10003 | Vulnerable JS Library | IGNORE | Flagged by Swagger UI's bundled libraries, not application code |
| 10010 | Cookie No HttpOnly Flag | WARN | Monitored — application sets HttpOnly via middleware |
| 10011 | Cookie Without Secure Flag | WARN | Monitored — application enforces Secure via cookie policy |
| 10015 | Incomplete or No Cache-control | WARN | Monitored — middleware sets `no-store, no-cache` |
| 10017 | Cross-Domain JavaScript Source | IGNORE | Swagger UI loads external JS in development mode |
| 10020 | X-Frame-Options Header | WARN | Monitored — middleware sets DENY |
| 10021 | X-Content-Type-Options Header | WARN | Monitored — middleware sets nosniff |
| 10023 | Information Disclosure - Debug Errors | IGNORE | Development mode stack traces are expected |
| 10038 | Content Security Policy | WARN | Monitored — middleware sets restrictive CSP |
| 10049 | Storable/Cacheable Content | IGNORE | Cache headers are explicitly set by middleware |
| 10055 | CSP Wildcard Directive | WARN | Monitored — CSP uses `'self'` not wildcards |
| 10063 | Permissions-Policy Header | WARN | Monitored — middleware sets restrictive policy |
| 10096 | Timestamp Disclosure | IGNORE | Timestamps in JSON responses are expected (audit logs, entries) |
| 10098 | Cross-Domain Misconfiguration | WARN | Monitored — CORS is explicitly configured |
| 10202 | Absence of Anti-CSRF Tokens | IGNORE | API uses JWT bearer tokens, not cookies — CSRF does not apply |
| 10038 | Browser XSS Protection | IGNORE | Deprecated header — modern CSP replaces it |

**API Rules (`zap-api-rules.tsv`):**

Inherits all baseline rules plus:

| Rule ID | Description | Action | Rationale |
|---------|-------------|--------|-----------|
| 40012 | Reflected XSS | **FAIL** | Injection of executable scripts is a critical vulnerability |
| 40014 | Persistent XSS | **FAIL** | Stored script injection can compromise all users |
| 40018 | SQL Injection | **FAIL** | Direct database manipulation is a critical vulnerability |
| 40019 | SQL Injection (MySQL) | **FAIL** | Database-specific injection variant |
| 40020 | SQL Injection (Hypersonic/HSQLDB) | **FAIL** | Database-specific injection variant |
| 40021 | SQL Injection (Oracle) | **FAIL** | Database-specific injection variant |
| 20019 | External Redirect | IGNORE | API returns JSON, not HTML redirects |
| 30001 | Buffer Overflow | WARN | Monitored — .NET manages memory but worth tracking |
| 90022 | Application Error Disclosure | IGNORE | Expected during active fuzzing — scanner sends deliberately malformed requests |
| 90033 | Loosely Scoped Cookie | IGNORE | JWT-based auth — cookie scoping is not a concern |

### 5.6 Pass/Fail Criteria & Justification

Security gates are evaluated only against **business API endpoints** — routes under `/auth`, `/users`, `/accounts`, `/journal-entries`, `/periods`, `/reports`, and `/audit-logs`. Findings against Swagger UI or development tooling are excluded from gate evaluation.

| Criteria | Threshold | Rationale |
|----------|-----------|-----------|
| High severity alerts | **0** | Any high-severity finding (e.g., confirmed SQL injection, XSS) represents an exploitable vulnerability. No tolerance. |
| Medium severity alerts | **0** | Medium findings (e.g., missing protections, weak configurations) on business endpoints indicate security gaps that must be resolved before release. |
| FAIL-rule hits | **0** | Any hit on a FAIL-classified rule (40012, 40014, 40018–40021) causes immediate test failure regardless of alert severity classification. These rules target injection attacks that represent the highest risk to a financial system handling sensitive accounting data. |
| Low/Informational alerts | No gate | Tracked for awareness but do not block release. These typically represent defense-in-depth improvements, not exploitable vulnerabilities. |

**ZAP exit code interpretation:**

| Exit Code | Meaning | Action |
|-----------|---------|--------|
| 0 | No findings above IGNORE level | **PASS** |
| 2 | WARN-level findings detected | **PASS** (with `-IgnoreWarnings` flag) or **REVIEW** |
| 3+ | FAIL-rule hit or scan failure | **FAIL** — must fix and rescan |

**Why zero tolerance for High/Medium on business endpoints:** This is a financial accounting system. A SQL injection vulnerability could allow an attacker to manipulate journal entries, fabricate financial reports, or extract sensitive data. The cost of a false negative (shipping a vulnerability) far exceeds the cost of a false positive (investigating a clean finding). Zero tolerance is the appropriate standard.

---

## 6. Execution Cadence

Tests are organized into three tiers based on scope and duration. Each tier is appropriate for a different stage of development.

### Tier 1: PR Smoke (per pull request, ~10 minutes)

Validates that new code does not introduce obvious regressions.

- ZAP baseline scan (passive only)
- JMeter p50 profile (50 users, baseline load)

### Tier 2: Nightly (~30 minutes)

Broader validation run on the current development branch.

- ZAP baseline scan + authenticated API scan
- JMeter p50 and p100 profiles
- Unit and integration test suites with coverage gates

### Tier 3: Pre-Release / Thesis Evidence (~4 hours)

Full test matrix generating all artifacts required for thesis documentation.

- Data re-seeding (fresh deterministic dataset)
- Full ZAP suite (baseline + API scan)
- Full JMeter matrix (p50, p100, p500, soak, spike)
- Consolidated thesis summary report with benchmark comparison

**Why three tiers:** Running the full matrix on every PR would take 4+ hours and block development. The tiered approach balances thoroughness with development velocity — fast feedback on PRs, moderate coverage nightly, and exhaustive validation before release or thesis evidence collection.

---

## 7. Reporting & Artifacts

Every test run produces timestamped artifacts. No results are overwritten — all runs are preserved for comparison and thesis evidence.

### Performance Artifacts (JMeter)

| Artifact | Path | Format | Purpose |
|----------|------|--------|---------|
| Raw results | `Document/performance/jmeter-{runTag}.jtl` | JTL (CSV) | Complete request-level data — every request's timestamp, response time, status code, and thread name |
| HTML dashboard | `Document/performance/report-{runTag}/` | HTML | Visual report with response time graphs, throughput charts, and percentile distribution |
| Statistics summary | `Document/performance/report-{runTag}/statistics.json` | JSON | Machine-readable aggregate metrics — p50, p90, p95, p99, error rate, throughput per endpoint |
| Runtime metrics | `Document/performance/runtime-metrics-{timestamp}.csv` | CSV | CPU and memory utilization captured during the test run |

### Security Artifacts (ZAP)

| Artifact | Path | Format | Purpose |
|----------|------|--------|---------|
| Interactive report | `Document/security/{prefix}.html` | HTML | Full scan report with alert details, risk ratings, and remediation guidance |
| Machine-readable results | `Document/security/{prefix}.json` | JSON | Structured alert data for automated gate evaluation |
| Summary report | `Document/security/{prefix}.md` | Markdown | Concise summary for inclusion in thesis documentation |

### Consolidated Reports

| Artifact | Path | Purpose |
|----------|------|---------|
| Test summary | `Document/performance/test-summary-{runId}.md` | Combined performance and security results for a full suite run |
| Benchmark report | `Document/performance/benchmark_report_latest.md` | Comparison against baseline anchor — tracks improvement or regression across runs |
| Thesis evidence | `Document/performance/thesis-evidence-{runId}.csv` | Tabular data formatted for thesis appendix inclusion |
| Baseline anchor | `Document/performance/thesis-baseline-anchor.json` | Reference metrics from the accepted baseline run — used for drift calculations |

**Naming convention:** The `{runTag}` and `{prefix}` values include timestamps (format: `yyyyMMdd-HHmmss`) to ensure uniqueness. Example: `zap-api-20260222-231435.html`, `jmeter-p100-20260222-231435.jtl`.

---

## 8. Defect Triage Workflow

When a test fails, the following workflow determines priority and resolution sequence.

### Security Failures (ZAP)

1. **Classify** — Identify the failing rule ID, affected endpoint, and alert severity from the JSON report
2. **Prioritize** — FAIL-rule hits (injection vulnerabilities) are fixed first, then High severity, then Medium
3. **Fix** — Apply code-level fix (input validation, parameterized queries, output encoding)
4. **Verify** — Re-run both ZAP scans (baseline + API) to confirm the fix resolves the finding without introducing new alerts
5. **Document** — Record the finding, fix, and verification in the thesis as evidence of the security testing lifecycle

### Performance Failures (JMeter)

1. **Identify** — Locate the failing samplers from `statistics.json` — which endpoints exceeded error rate or p95 thresholds
2. **Prioritize** — Persistent failures across multiple profiles are addressed first. Failures only in stress/spike profiles are lower priority.
3. **Diagnose** — Check runtime metrics (CPU/memory) for resource saturation. Examine failing endpoints for inefficient queries, missing indexes, or connection pool exhaustion.
4. **Fix** — Apply targeted optimizations (query optimization, database indexing, caching, connection pool tuning)
5. **Verify** — Re-run the failing profile(s) to confirm improvement, then run the full matrix to ensure no regressions

### Exit Criteria for Release

All of the following must be satisfied:

- ZAP: Zero High/Medium alerts on business endpoints, zero FAIL-rule hits
- JMeter: All five profiles meet their respective pass/fail thresholds
- No unresolved critical security or performance defects
- All artifacts generated and preserved for thesis evidence

---

## 9. Execution Commands Reference

All commands below are exact — copy-paste reproducible. No parameters are left to operator judgment.

### Prerequisites

```powershell
# 1. Start Docker Desktop (required for JMeter and ZAP containers)

# 2. Install/start tool containers
./scripts/phase4/install-tools.ps1

# 3. Start the API in Development mode
dotnet run --project API/API.csproj --urls http://0.0.0.0:5296 --environment Development

# 4. Seed deterministic test data
./scripts/phase4/seed-test-data.ps1 -PeriodId 202601 -AccountCount 120 -JournalEntryCount 30000 -MinimumPostedEntries 5000
```

### Tier 1: PR Smoke

```powershell
# ZAP baseline scan (passive)
./scripts/phase4/run-zap-baseline.ps1 `
  -TargetUrl "http://localhost:5296/swagger" `
  -OutputPrefix "zap-baseline-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

# JMeter baseline load (50 users)
./scripts/phase4/run-jmeter-profile.ps1 `
  -Profile p50 `
  -BaseUrl "http://localhost:5296" `
  -Username "admin" -Password "Admin@123" `
  -PeriodId 202601 -AccountId 1
```

### Tier 2: Nightly

```powershell
# ZAP baseline scan
./scripts/phase4/run-zap-baseline.ps1 `
  -TargetUrl "http://localhost:5296/swagger" `
  -OutputPrefix "zap-baseline-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

# ZAP authenticated API scan
./scripts/phase4/run-zap-api.ps1 `
  -OpenApiUrl "http://localhost:5296/swagger/v1/swagger.json" `
  -BaseUrl "http://localhost:5296" `
  -Username "admin" -Password "Admin@123" `
  -OutputPrefix "zap-api-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

# JMeter profiles 50 and 100
./scripts/phase4/run-jmeter-profile.ps1 -Profile p50 `
  -BaseUrl "http://localhost:5296" `
  -Username "admin" -Password "Admin@123" `
  -PeriodId 202601 -AccountId 1

./scripts/phase4/run-jmeter-profile.ps1 -Profile p100 `
  -BaseUrl "http://localhost:5296" `
  -Username "admin" -Password "Admin@123" `
  -PeriodId 202601 -AccountId 1
```

### Tier 3: Pre-Release / Thesis Evidence (Full Suite)

```powershell
# Single command runs everything: seed → unit tests → integration tests →
# ZAP scans → JMeter full matrix → consolidated report
./scripts/phase4/run-thesis-suite.ps1 `
  -BaseUrl "http://localhost:5296" `
  -Username "admin" -Password "Admin@123" `
  -PeriodId 202601 -AccountId 1
```

### Individual JMeter Profiles (if running selectively)

```powershell
# Full matrix (all 5 profiles in sequence)
./scripts/phase4/run-jmeter-thesis-matrix.ps1 `
  -BaseUrl "http://localhost:5296" `
  -Username "admin" -Password "Admin@123" `
  -PeriodId 202601 -AccountId 1
```

### Script Reference

| Script | Purpose |
|--------|---------|
| `scripts/phase4/install-tools.ps1` | Pull and start Docker containers for JMeter and ZAP |
| `scripts/phase4/seed-test-data.ps1` | Seed deterministic test data into the database |
| `scripts/phase4/run-zap-baseline.ps1` | Execute ZAP passive baseline scan |
| `scripts/phase4/run-zap-api.ps1` | Execute ZAP active authenticated API scan |
| `scripts/phase4/run-jmeter.ps1` | Execute a single JMeter test plan |
| `scripts/phase4/run-jmeter-profile.ps1` | Execute a named JMeter profile (p50, p100, p500, soak, spike) |
| `scripts/phase4/run-jmeter-thesis-matrix.ps1` | Execute all 5 JMeter profiles in sequence |
| `scripts/phase4/run-thesis-suite.ps1` | Master orchestrator — runs the complete test suite end-to-end |

### Rule Configuration Files

| File | Purpose |
|------|---------|
| `scripts/phase4/zap-baseline-rules.tsv` | ZAP rule actions for passive baseline scan |
| `scripts/phase4/zap-api-rules.tsv` | ZAP rule actions for active API scan |

### Test Plan Files

| File | Used By |
|------|---------|
| `Document/performance/jmeter/financial-api-load-test.jmx` | p50, p100, p500 profiles |
| `Document/performance/jmeter/financial-api-soak-test.jmx` | Soak profile |
| `Document/performance/jmeter/financial-api-spike-test.jmx` | Spike profile |
