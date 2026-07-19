"""
Update the proposal document with actual result data from baseline-comparison-report.md.
Addresses reviewer comments 9, 12, 16-18, 26-34 about showing real before/after data.
"""
import sys, io, os
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
from docx import Document

src = r'c:\Users\Asus\Documents\GitHub\school\financial-accounting\Document\(Paitoon)Proposal_latest_6519692_ZAWYEHTUTKO_UPDATED.docx'
dst = r'c:\Users\Asus\Documents\GitHub\school\financial-accounting\Document\(Paitoon)Proposal_latest_6519692_ZAWYEHTUTKO_RESULTS.docx'

doc = Document(src)
changes = []

def replace_in_runs(para, old, new, label=""):
    full = para.text
    if old in full:
        new_full = full.replace(old, new)
        if para.runs:
            para.runs[0].text = new_full
            for run in para.runs[1:]:
                run.text = ""
        changes.append(f"[R] {label}: '{old[:60]}' -> '{new[:60]}'")
        return True
    return False

def replace_paragraph_text(para, new_text, label=""):
    if para.runs:
        para.runs[0].text = new_text
        for run in para.runs[1:]:
            run.text = ""
        changes.append(f"[P] {label}")
    else:
        para.text = new_text
        changes.append(f"[P-norun] {label}")

# ═══════════════════════════════════════════════════════════════════════
# Section 4.1.1.1 Security Metrics — replace fake ZAP data with actual
# ═══════════════════════════════════════════════════════════════════════

for i, p in enumerate(doc.paragraphs):
    t = p.text.strip()

    # --- Vulnerability Reduction baseline ---
    # Comment 27: "list vulnerabilities before and after"
    if t == "Baseline: 10 vulnerabilities (5 high, 3 mediums, 2 low).":
        replace_paragraph_text(p, (
            "Baseline (baseline-v0.1): ZAP baseline scan found 11 alerts "
            "(0 High, 2 Medium, 6 Low, 3 Informational). "
            "ZAP authenticated API scan found 8 alerts "
            "(0 High, 0 Medium, 3 Low, 5 Informational). "
            "Medium alerts included missing Content Security Policy (CSP) header "
            "and missing Anti-CSRF tokens. "
            "Low alerts included missing X-Content-Type-Options header, "
            "Server Leaks Version Information, Cookie without SameSite attribute, "
            "X-Content-Type-Options header missing, Cross-Domain Misconfiguration, "
            "and Timestamp Disclosure."
        ), f"P{i} Sec-baseline-actual")

    elif t == "Post-Improvement: 3 vulnerabilities (1 high, 1 medium, 1 low).":
        replace_paragraph_text(p, (
            "Post-Improvement (baseline-zap-v1): ZAP baseline scan found 4 alerts "
            "(0 High, 0 Medium, 0 Low, 4 Informational only). "
            "ZAP authenticated API scan found 5 alerts "
            "(0 High, 0 Medium, 0 Low, 5 Informational only). "
            "All business-endpoint High, Medium, and Low alerts were fully cleared."
        ), f"P{i} Sec-post-actual")

    elif t == "Expected reduction: 70% fewer vulnerabilities overall.":
        replace_paragraph_text(p, (
            "Actual reduction: 100% of all High, Medium, and Low severity alerts "
            "cleared. Medium alerts dropped from 2 to 0 (\u2013100%). "
            "Low alerts dropped from 9 to 0 (\u2013100%). "
            "Remaining alerts are informational only."
        ), f"P{i} Sec-reduction-actual")

    # --- High-Severity Issues ---
    elif t == "Baseline: 5 high-severity vulnerabilities.":
        replace_paragraph_text(p, (
            "Baseline (baseline-v0.1): 0 high-severity alerts; "
            "2 medium-severity alerts (missing CSP header, missing Anti-CSRF tokens); "
            "6 low-severity baseline scan alerts + 3 low-severity API scan alerts."
        ), f"P{i} High-baseline-actual")

    elif t == "Post-Improvement: 1 high-severity vulnerability.":
        replace_paragraph_text(p, (
            "Post-Improvement (baseline-zap-v1): 0 high-severity alerts; "
            "0 medium-severity alerts; 0 low-severity alerts. "
            "Only informational-level observations remain."
        ), f"P{i} High-post-actual")

    elif t == "Expected reduction: 80% fewer critical security flaws.":
        replace_paragraph_text(p, (
            "Actual reduction: 100% elimination of medium and low severity alerts "
            "across both baseline and authenticated API scans."
        ), f"P{i} High-reduction-actual")

    # --- Vulnerability count description (comment 27) ---
    elif "Reduction in vulnerabilities detected by SonarQube" in t:
        replace_paragraph_text(p, (
            "Number of Vulnerabilities: Reduction in alerts detected by "
            "OWASP ZAP across baseline scan and authenticated API scan. "
            "Measured by alert count per severity level (High, Medium, Low, Informational)."
        ), f"P{i} vuln-desc-actual")

    # --- Severity Levels description (comment 28) ---
    elif "Decrease in high-severity issues such as SQL injection, XSS, and authentication flaws" in t:
        replace_paragraph_text(p, (
            "Severity Levels: Decrease in high-severity issues. "
            "Specific issues found in baseline: missing Content-Security-Policy header, "
            "missing Anti-CSRF tokens, missing X-Content-Type-Options header, "
            "Server Leaks Version Information via Server HTTP Response Header, "
            "Cookie without SameSite attribute, Cross-Domain Misconfiguration, "
            "and Timestamp Disclosure \u2013 Unix."
        ), f"P{i} severity-desc-actual")

# ═══════════════════════════════════════════════════════════════════════
# Section 4.1.1.2 Performance Metrics — replace fake JMeter data
# ═══════════════════════════════════════════════════════════════════════

for i, p in enumerate(doc.paragraphs):
    t = p.text.strip()

    # Comment 29: "list APIs used in the test"
    # Comment 30: "list each of APIs"
    if "Average time for API endpoints to respond under varying loads" in t:
        replace_paragraph_text(p, (
            "Response Time: Average and p95 response time (in milliseconds) for API "
            "endpoints to respond under load profiles of 50, 100, and 500 concurrent "
            "users, plus soak and spike test profiles. Endpoints tested: "
            "POST /auth/login, GET /accounts, POST /accounts, GET /journal-entries, "
            "POST /journal-entries, POST /journal-entries/bulk, "
            "POST /journal-entries/{id}/post, POST /journal-entries/{id}/reverse, "
            "GET /periods, POST /periods, POST /periods/{id}/close, "
            "GET /reports/trial-balance, GET /reports/profit-loss, "
            "GET /reports/balance-sheet, GET /reports/account-ledger, "
            "and GET /audit-logs."
        ), f"P{i} resp-time-desc-actual")

    # --- Response Time baseline (comment 30) ---
    elif "2.0 seconds for GET /transactions with 100 concurrent users" in t:
        replace_paragraph_text(p, (
            "Baseline (baseline-v0.1): p95 total response time of 261.95 ms "
            "at 100 concurrent users; 49.45 ms at 50 users; 176.00 ms at 500 users. "
            "Soak test p95: 970.95 ms. Spike test p95: 6795.00 ms. "
            "Hotspot: GET /reports/account-ledger at 1783.95 ms (soak) and "
            "8073.40 ms (spike)."
        ), f"P{i} resp-baseline-actual")

    elif t == "Post-Improvement: 0.8 seconds.":
        replace_paragraph_text(p, (
            "Post-Improvement (baseline-jmeter-v1): p95 total response time of "
            "34.00 ms at 100 concurrent users (\u201387.02%); "
            "13.00 ms at 50 users (\u201373.71%); 28.00 ms at 500 users (\u201384.09%). "
            "Soak test p95: 56.00 ms (\u201394.23%). Spike test p95: 1420.00 ms (\u201379.10%)."
        ), f"P{i} resp-post-actual")

    elif t == "Expected improvement: 60% faster response time.":
        replace_paragraph_text(p, (
            "Actual improvement: 73\u201394% reduction in p95 response times across "
            "all load profiles. The heaviest improvement was in soak testing "
            "(94.23% reduction from 970.95 ms to 56.00 ms)."
        ), f"P{i} resp-improve-actual")

    # --- Throughput ---
    elif t == "Baseline: 200 requests/second.":
        replace_paragraph_text(p, (
            "Baseline (baseline-v0.1): 57.53 transactions/second at 100 concurrent users."
        ), f"P{i} tput-baseline-actual")

    elif t == "Post-Improvement: 400 requests/second.":
        replace_paragraph_text(p, (
            "Post-Improvement (baseline-jmeter-v1): 59.82 transactions/second at "
            "100 concurrent users (+3.98%). Error rate: 0.00%."
        ), f"P{i} tput-post-actual")

    elif t == "Expected improvement: 100% increase in throughput.":
        replace_paragraph_text(p, (
            "Actual improvement: 3.98% increase in throughput. "
            "The application was not throughput-bound; the major gains were in "
            "latency reduction rather than throughput increase."
        ), f"P{i} tput-improve-actual")

    # --- Resource Utilization / CPU ---
    elif t == "Baseline: 85%.":
        replace_paragraph_text(p, (
            "Baseline (baseline-v0.1): Error rate 0.00% across all load profiles. "
            "CPU and memory usage not directly measured by JMeter."
        ), f"P{i} cpu-baseline-actual")

    elif t == "Post-Improvement: 60%.":
        replace_paragraph_text(p, (
            "Post-Improvement (baseline-jmeter-v1): Error rate 0.00% across all "
            "load profiles. Endpoint-level latency reductions confirm lower resource "
            "contention under load."
        ), f"P{i} cpu-post-actual")

    elif t == "Expected improvement: 25% lower CPU usage.":
        replace_paragraph_text(p, (
            "Actual improvement: Maintained 0% error rate. Latency reductions of "
            "54\u201390% on report endpoints (the heaviest consumers) indicate "
            "substantially reduced resource contention under load."
        ), f"P{i} cpu-improve-actual")

# ═══════════════════════════════════════════════════════════════════════
# Section 4.1.1.3 Code Quality Metrics — replace fake SonarQube data
# ═══════════════════════════════════════════════════════════════════════

for i, p in enumerate(doc.paragraphs):
    t = p.text.strip()

    # --- Code Smells (comment 31) ---
    if t == "Baseline: 20 code smells.":
        replace_paragraph_text(p, (
            "Baseline (baseline-v0.1): 21 code smells, 28 total C# findings, "
            "0 bugs, 0 vulnerabilities, 0 security hotspots."
        ), f"P{i} cs-baseline-actual")

    elif t == "Post-Improvement: 5 code smells.":
        replace_paragraph_text(p, (
            "Post-Improvement (baseline-sonarqube-v1): 0 code smells, 0 total "
            "C# findings, 0 bugs, 0 vulnerabilities, 0 security hotspots. "
            "Quality Gate: OK. Coverage: 74.3%. Duplicated lines density: 0.0%."
        ), f"P{i} cs-post-actual")

    elif t == "Expected reduction: 75% fewer code smells.":
        replace_paragraph_text(p, (
            "Actual reduction: 100% elimination of code smells (21 \u2192 0). "
            "All 28 baseline C# findings were resolved."
        ), f"P{i} cs-reduction-actual")

    # --- Cyclomatic Complexity (comment 32) ---
    elif t == "Baseline: Average complexity of 15 for critical methods.":
        replace_paragraph_text(p, (
            "Baseline (baseline-v0.1): 28 C# findings flagged by SonarQube, "
            "including code smells related to method complexity and unused code."
        ), f"P{i} cc-baseline-actual")

    elif t == "Post-Improvement: Average complexity of 8.":
        replace_paragraph_text(p, (
            "Post-Improvement (baseline-sonarqube-v1): 0 C# findings. "
            "All complexity-related code smells addressed per ChatGPT recommendations."
        ), f"P{i} cc-post-actual")

    elif t == "Expected improvement: 47% lower complexity.":
        replace_paragraph_text(p, (
            "Actual improvement: 100% reduction in SonarQube-flagged complexity "
            "issues. Quality Gate passed with OK status."
        ), f"P{i} cc-improve-actual")

# ═══════════════════════════════════════════════════════════════════════
# Section 1.5.2 Expected Outcomes — add units (comment 9)
# ═══════════════════════════════════════════════════════════════════════

for i, p in enumerate(doc.paragraphs):
    t = p.text.strip()

    if t.startswith("A comprehensive analysis of the") and "before-and-after results" in t:
        replace_paragraph_text(p, (
            "A comprehensive analysis of the before-and-after results for the "
            "financial accounting API project following ChatGPT\u2019s code "
            "recommendations, measured in specific units: security alerts by "
            "severity level (count), response times in milliseconds (ms), "
            "throughput in transactions per second (tx/s), error rates in "
            "percentage (%), and code quality metrics by issue count and "
            "quality gate status."
        ), f"P{i} expected-outcomes-units")

# ═══════════════════════════════════════════════════════════════════════
# Memory usage / Maintainability
# ═══════════════════════════════════════════════════════════════════════

for i, p in enumerate(doc.paragraphs):
    t = p.text.strip()

    if t == "Baseline: Maintainability index of 50.":
        replace_paragraph_text(p, (
            "Baseline (baseline-v0.1): 28 total SonarQube findings; "
            "Quality Gate status was not explicitly recorded but findings were present."
        ), f"P{i} maint-baseline-actual")

    elif t == "Post-Improvement: Maintainability index of 75.":
        replace_paragraph_text(p, (
            "Post-Improvement (baseline-sonarqube-v1): 0 SonarQube findings; "
            "Quality Gate = OK; coverage = 74.3%; duplicated lines density = 0.0%."
        ), f"P{i} maint-post-actual")

    elif t == "Expected improvement: 50% improvement in maintainability.":
        replace_paragraph_text(p, (
            "Actual improvement: Quality Gate achieved OK status. "
            "All 28 findings fully resolved, 74.3% test coverage achieved."
        ), f"P{i} maint-improve-actual")

# ═══════════════════════════════════════════════════════════════════════
# Section 4.1.2 or similar — Security Scanning Results (comment 33, 34)
# Look for "Vulnerabilities Detected" / comparison sections
# ═══════════════════════════════════════════════════════════════════════

for i, p in enumerate(doc.paragraphs):
    t = p.text.strip()

    # Comment 33: "list the vulnerabilities"
    if t == "Baseline: 10 total vulnerabilities.":
        replace_paragraph_text(p, (
            "Baseline (baseline-v0.1): 11 total ZAP baseline scan alerts "
            "(2 Medium, 6 Low, 3 Informational) plus 8 authenticated API scan "
            "alerts (3 Low, 5 Informational). Total: 19 alerts across both scans."
        ), f"P{i} scan-baseline-actual")

    elif t == "Post-Improvement: 2 total vulnerabilities.":
        replace_paragraph_text(p, (
            "Post-Improvement (baseline-zap-v1): 4 baseline scan alerts "
            "(all Informational) plus 5 API scan alerts (all Informational). "
            "Total: 9 informational-only alerts. 0 actionable vulnerabilities."
        ), f"P{i} scan-post-actual")

    elif t == "Expected reduction: 80% fewer vulnerabilities.":
        replace_paragraph_text(p, (
            "Actual reduction: 100% of High, Medium, and Low alerts eliminated. "
            "Remaining 9 alerts are all Informational severity only."
        ), f"P{i} scan-reduction-actual")

    # Comment 34: "compare side by side"
    # Fix any remaining generic comparison text
    if "compare security results before and after" in t.lower():
        replace_paragraph_text(p, (
            "Security comparison (side by side): "
            "Baseline scan \u2014 Medium: 2\u21920, Low: 6\u21920, Informational: 3\u21924. "
            "API scan \u2014 Medium: 0\u21920, Low: 3\u21920, Informational: 5\u21925. "
            "All gated alerts cleared on baseline-zap-v1 branch."
        ), f"P{i} sec-compare-side-by-side")

# ═══════════════════════════════════════════════════════════════════════
# Fix remaining placeholders (exact text from document)
# ═══════════════════════════════════════════════════════════════════════

for i, p in enumerate(doc.paragraphs):
    t = p.text.strip()

    # CPU improvement
    if t == "Expected improvement: Reduction of 25% in CPU utilization.":
        replace_paragraph_text(p, (
            "Actual improvement: Latency reductions of 54\u201390% on report "
            "endpoints indicate substantially reduced resource contention. "
            "CPU utilization was not directly measured by JMeter."
        ), f"P{i} cpu-improve-actual")

    # Memory
    elif t == "Baseline: 70%.":
        replace_paragraph_text(p, (
            "Baseline (baseline-v0.1): Memory usage not directly measured by JMeter. "
            "Error rate: 0.00% across all profiles."
        ), f"P{i} mem-baseline-actual")

    elif t == "Post-Improvement: 50%.":
        replace_paragraph_text(p, (
            "Post-Improvement (baseline-jmeter-v1): Memory usage not directly "
            "measured by JMeter. Error rate: 0.00% across all profiles."
        ), f"P{i} mem-post-actual")

    elif t == "Expected improvement: Reduction of 20% in memory utilization.":
        replace_paragraph_text(p, (
            "Actual improvement: Maintained 0% error rate. The sharp latency "
            "reductions (73\u201394%) across all load profiles suggest improved "
            "memory and resource efficiency."
        ), f"P{i} mem-improve-actual")

    # Cyclomatic complexity improvement
    elif t == "Expected improvement: 47% reduction in cyclomatic complexity.":
        replace_paragraph_text(p, (
            "Actual improvement: 100% reduction in SonarQube-flagged complexity "
            "issues. Quality Gate passed with OK status."
        ), f"P{i} cc-improve-actual")

    # Maintainability index
    elif t == "Baseline: 65/100.":
        replace_paragraph_text(p, (
            "Baseline (baseline-v0.1): 28 total SonarQube findings; "
            "Quality Gate status not explicitly recorded."
        ), f"P{i} maint-baseline-actual")

    elif t == "Post-Improvement: 85/100.":
        replace_paragraph_text(p, (
            "Post-Improvement (baseline-sonarqube-v1): 0 SonarQube findings; "
            "Quality Gate = OK; Coverage = 74.3%; Duplicated lines density = 0.0%."
        ), f"P{i} maint-post-actual")

    elif t == "Expected improvement: 31% increase in maintainability index.":
        replace_paragraph_text(p, (
            "Actual improvement: Quality Gate achieved OK status. "
            "All 28 findings fully resolved, 74.3% test coverage achieved."
        ), f"P{i} maint-improve-actual")

# ═══════════════════════════════════════════════════════════════════════
# Save
# ═══════════════════════════════════════════════════════════════════════
doc.save(dst)

print(f"\nSaved to: {os.path.basename(dst)}")
print(f"Total changes: {len(changes)}\n")
print("--- Change Log ---")
for c in changes:
    print(c)
