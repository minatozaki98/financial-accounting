# Performance & Security Test Summary Report

**Run Date:** 2026-03-08
**Branch:** baseline-v0.1
**API URL:** http://localhost:5296 (ASP.NET Core 8.0, Development mode)
**Database:** SQL Server (localhost, `Financial`)

---

## 1. Executive Summary

| Category | Tests Run | Passed | Failed | Result |
|----------|-----------|--------|--------|--------|
| Security (ZAP Baseline) | 1 | 1 | 0 | **PASS** |
| Security (ZAP API Scan) | 1 | 1 | 0 | **PASS** |
| Performance (JMeter p50) | 1 | 1 | 0 | **PASS** |
| Performance (JMeter p100) | 1 | 1 | 0 | **PASS** |
| **Overall** | **4** | **4** | **0** | **ALL PASS** |

---

## 2. Security Testing Results (OWASP ZAP)

### 2.1 Baseline Scan (Passive)

**Target:** http://localhost:5296/swagger
**Scanner:** OWASP ZAP (ghcr.io/zaproxy/zaproxy:stable)
**Mode:** Passive (no attack payloads sent)
**URLs Scanned:** 13
**Rules Evaluated:** 58 PASS, 9 WARN, 0 FAIL

| Risk Level | Alerts Found |
|------------|-------------|
| High | 0 |
| Medium | 3 |
| Low | 6 |
| Informational | 3 |

**Medium Alerts (all on Swagger UI, not business API):**

| Alert | Instances | Affected | Assessment |
|-------|-----------|----------|------------|
| Content Security Policy (CSP) Header Not Set | 3 | `/`, `/swagger`, `/swagger/index.html` | Swagger UI pages only — API JSON responses not affected |
| Missing Anti-clickjacking Header | 2 | `/`, `/swagger` | Swagger UI pages only — irrelevant for JSON API |
| Vulnerable JS Library (DOMPurify 3.1.4) | 1 | `/swagger/swagger-ui-bundle.js` | Third-party Swagger UI dependency, not application code |

**Low Alerts:**

| Alert | Assessment |
|-------|------------|
| Cross-Origin-Embedder-Policy Header Missing | Swagger UI pages only |
| Cross-Origin-Opener-Policy Header Missing | Swagger UI pages only |
| Cross-Origin-Resource-Policy Header Missing | Static assets only |
| Permissions Policy Header Not Set | Swagger UI pages only |
| Timestamp Disclosure - Unix | Constants in Swagger UI JS (not application data) |
| X-Content-Type-Options Header Missing | Swagger UI static files |

**Verdict:** **PASS** — Zero alerts on business API endpoints. All findings are on Swagger UI static assets which are excluded from security gates per the test plan.

### 2.2 Authenticated API Scan (Active)

**Target:** OpenAPI spec at http://localhost:5296/swagger/v1/swagger.json
**Mode:** Active (attack payloads injected against all endpoints)
**Endpoints Imported:** 27 (from OpenAPI spec)
**URLs Scanned:** 291 (including fuzzed variants)
**Total Endpoints Probed:** 324
**Rules Evaluated:** 117 PASS, 3 WARN, 0 FAIL

| Risk Level | Alerts Found |
|------------|-------------|
| High | 0 |
| Medium | 0 |
| Low | 3 |
| Informational | 5 |

**Critical Injection Tests — All PASS:**

| Rule ID | Test | Result |
|---------|------|--------|
| 40018 | SQL Injection | **PASS** |
| 40019 | SQL Injection - MySQL (Time Based) | **PASS** |
| 40020 | SQL Injection - Hypersonic SQL (Time Based) | **PASS** |
| 40021 | SQL Injection - Oracle (Time Based) | **PASS** |
| 40022 | SQL Injection - PostgreSQL (Time Based) | **PASS** |
| 40027 | SQL Injection - MsSQL (Time Based) | **PASS** |
| 40012 | Cross Site Scripting (Reflected) | **PASS** |
| 40014 | Cross Site Scripting (Persistent) | **PASS** |
| 40026 | Cross Site Scripting (DOM Based) | **PASS** |
| 6 | Path Traversal | **PASS** |
| 7 | Remote File Inclusion | **PASS** |
| 90020 | Remote OS Command Injection | **PASS** |
| 90037 | Remote OS Command Injection (Time Based) | **PASS** |
| 90019 | Server Side Code Injection | **PASS** |
| 90023 | XML External Entity Attack | **PASS** |
| 90035 | Server Side Template Injection | **PASS** |
| 40003 | CRLF Injection | **PASS** |

**Pre-scan Authentication & RBAC Verification:**

| Check | Result |
|-------|--------|
| Unauthenticated access to `/users/me` | 401 (correct) |
| Unauthenticated access to `/accounts` | 401 (correct) |
| Unauthenticated access to `/periods` | 401 (correct) |
| Unauthenticated access to `/journal-entries` | 401 (correct) |
| Unauthenticated access to `/reports/trial-balance` | 401 (correct) |
| Unauthenticated access to `/audit-logs` | 401 (correct) |
| User role → POST /accounts | 403 (correct) |
| User role → POST /periods | 403 (correct) |
| User role → GET /reports/trial-balance | 403 (correct) |
| FinanceManager role → POST /users | 403 (correct) |
| FinanceManager role → POST /accounts | 403 (correct) |
| Auditor role → POST /journal-entries | 403 (correct) |
| Auditor role → GET /audit-logs | 200 (correct) |

**Verdict:** **PASS** — Zero High/Medium alerts on business endpoints. Zero FAIL-rule hits. All injection attack categories defeated. RBAC boundaries verified.

---

## 3. Performance Testing Results (Apache JMeter)

### 3.1 Test Environment

| Parameter | Value |
|-----------|-------|
| JMeter Image | justb4/jmeter:5.5 |
| Test Data | 120 accounts, 30,000 journal entries, 5,000+ posted |
| Period Under Test | 202601 |
| Auth User | admin (Admin role) |

### 3.2 p50 — Baseline Load (50 Users)

**Configuration:** 50 users, 30s ramp-up, 10 loops, core mode (CRUD only)
**Duration:** ~38 seconds
**Total Requests:** 2,050

| Endpoint | Samples | Errors | Error % | Avg (ms) | p95 (ms) | p99 (ms) | Max (ms) |
|----------|---------|--------|---------|----------|----------|----------|----------|
| POST /auth/login | 50 | 0 | 0.0% | 54 | 35 | 1,070 | 1,070 |
| GET /users/me | 500 | 0 | 0.0% | 8 | 12 | 27 | 142 |
| GET /accounts | 500 | 0 | 0.0% | 8 | 11 | 37 | 73 |
| GET /periods | 500 | 0 | 0.0% | 6 | 8 | 29 | 37 |
| GET /journal-entries | 500 | 0 | 0.0% | 19 | 22 | 69 | 328 |
| **Total** | **2,050** | **0** | **0.0%** | **11** | **18** | **44** | **1,070** |

**Throughput:** 54.5 requests/sec

| Metric | Result | Threshold | Status |
|--------|--------|-----------|--------|
| Error Rate | 0.0% | ≤ 0.5% | **PASS** |
| p95 Response Time | 18 ms | ≤ 300 ms | **PASS** |

### 3.3 p100 — Peak Load (100 Users, Mixed Mode)

**Configuration:** 100 users (70 core + 30 complex), 60s ramp-up, 10 loops, mixed mode
**Duration:** ~81 seconds
**Total Requests:** 4,700

| Endpoint | Samples | Errors | Error % | Avg (ms) | p95 (ms) | p99 (ms) | Max (ms) |
|----------|---------|--------|---------|----------|----------|----------|----------|
| POST /auth/login | 100 | 0 | 0.0% | 15 | 23 | 116 | 116 |
| GET /users/me | 1,000 | 0 | 0.0% | 7 | 10 | 42 | 235 |
| GET /accounts | 700 | 0 | 0.0% | 7 | 10 | 33 | 50 |
| GET /periods | 700 | 0 | 0.0% | 5 | 7 | 37 | 74 |
| GET /journal-entries | 700 | 0 | 0.0% | 14 | 20 | 137 | 275 |
| POST /journal-entries/bulk | 300 | 0 | 0.0% | 17 | 34 | 132 | 233 |
| GET /reports/trial-balance | 300 | 0 | 0.0% | 48 | 80 | 143 | 146 |
| GET /reports/profit-loss | 300 | 0 | 0.0% | 48 | 80 | 126 | 163 |
| GET /reports/balance-sheet | 300 | 0 | 0.0% | 45 | 65 | 118 | 127 |
| GET /reports/account-ledger | 300 | 0 | 0.0% | 110 | 186 | 343 | 423 |
| **Total** | **4,700** | **0** | **0.0%** | **23** | **60** | **175** | **423** |

**Throughput:** 58.6 requests/sec

| Metric | Result | Threshold | Status |
|--------|--------|-----------|--------|
| Error Rate | 0.0% | ≤ 1.0% | **PASS** |
| p95 Response Time | 60 ms | ≤ 500 ms | **PASS** |

### 3.4 Performance Observations

**CRUD Endpoints (core):** Consistently fast across both load levels. Average response times remain under 20ms even at 100 concurrent users. No degradation observed.

**Report Endpoints (complex):** The account-ledger endpoint is the slowest (avg 110ms at p100), which is expected as it queries journal entry lines filtered by account and period. All report endpoints remain well within the 500ms p95 threshold.

**Throughput:** Stable at ~55-59 requests/sec across both profiles, indicating the system is not saturated at these load levels.

**Error Rate:** Zero errors across all endpoints in both profiles — the system handles both baseline and peak loads without any failures.

---

## 4. Test Artifacts

### Security Reports

| File | Description |
|------|-------------|
| `Document/security/zap-baseline-20260308-183932.html` | ZAP Baseline Scan — Interactive HTML Report |
| `Document/security/zap-baseline-20260308-183932.json` | ZAP Baseline Scan — Machine-readable JSON |
| `Document/security/zap-baseline-20260308-183932.md` | ZAP Baseline Scan — Markdown Summary |
| `Document/security/zap-api-20260308-184530.html` | ZAP API Scan — Interactive HTML Report |
| `Document/security/zap-api-20260308-184530.json` | ZAP API Scan — Machine-readable JSON |
| `Document/security/zap-api-20260308-184530.md` | ZAP API Scan — Markdown Summary |

### Performance Reports

| File | Description |
|------|-------------|
| `Document/performance/jmeter-20260308-184418.jtl` | JMeter p50 — Raw JTL Results |
| `Document/performance/report-20260308-184418/` | JMeter p50 — HTML Dashboard |
| `Document/performance/report-20260308-184418/statistics.json` | JMeter p50 — Statistics JSON |
| `Document/performance/jmeter-20260308-190328.jtl` | JMeter p100 — Raw JTL Results |
| `Document/performance/report-20260308-190328/` | JMeter p100 — HTML Dashboard |
| `Document/performance/report-20260308-190328/statistics.json` | JMeter p100 — Statistics JSON |

---

## 5. Issues Found & Resolved During Testing

### JMeter Query Parameter Bug (Fixed)

**Problem:** All 3 JMeter test plans (load, soak, spike) had query parameters for report endpoints (`periodId`, `accountId`) defined in the JMeter HTTPArgument panel. When using full URLs in the `HTTPSampler.path` field (e.g., `${baseUrl}/reports/trial-balance`), JMeter did not append these parameters as query strings, causing all report endpoints to return HTTP 400 (`"Accounting period '0' was not found"`).

**Impact:** 100% error rate on all 4 report endpoints in mixed mode (previously masked because p50 uses core-only mode with 0 complex users).

**Fix:** Moved query parameters directly into the URL path:
- `${baseUrl}/reports/trial-balance?periodId=${periodId}`
- `${baseUrl}/reports/profit-loss?periodId=${periodId}`
- `${baseUrl}/reports/balance-sheet?periodId=${periodId}`
- `${baseUrl}/reports/account-ledger?accountId=${accountId}&periodId=${periodId}`

**Files Modified:**
- `Document/performance/jmeter/financial-api-load-test.jmx`
- `Document/performance/jmeter/financial-api-soak-test.jmx`
- `Document/performance/jmeter/financial-api-spike-test.jmx`

---

## 6. Pass/Fail Gate Summary

| Gate | Criteria | Result | Status |
|------|----------|--------|--------|
| ZAP Baseline — FAIL-rule hits | 0 | 0 | **PASS** |
| ZAP Baseline — High alerts on business endpoints | 0 | 0 | **PASS** |
| ZAP Baseline — Medium alerts on business endpoints | 0 | 0 | **PASS** |
| ZAP API — FAIL-rule hits (SQLi, XSS) | 0 | 0 | **PASS** |
| ZAP API — High alerts on business endpoints | 0 | 0 | **PASS** |
| ZAP API — Medium alerts on business endpoints | 0 | 0 | **PASS** |
| JMeter p50 — Error Rate | ≤ 0.5% | 0.0% | **PASS** |
| JMeter p50 — p95 Response Time | ≤ 300 ms | 18 ms | **PASS** |
| JMeter p100 — Error Rate | ≤ 1.0% | 0.0% | **PASS** |
| JMeter p100 — p95 Response Time | ≤ 500 ms | 60 ms | **PASS** |
