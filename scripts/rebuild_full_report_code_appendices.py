from __future__ import annotations

import argparse
import json
import subprocess
import textwrap
from pathlib import Path

from docx import Document
from docx.document import Document as DocumentObject
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Inches, Pt

try:
    from scripts.add_thesis_appendices_to_full_report import (
        APPENDIX_MARKER,
        ensure_bullet_style,
        ensure_code_style,
        remove_existing_appendices,
        set_cell_shading,
    )
    from scripts.update_full_report_fresh_results import load_fresh_evidence
except ModuleNotFoundError:
    from add_thesis_appendices_to_full_report import (
        APPENDIX_MARKER,
        ensure_bullet_style,
        ensure_code_style,
        remove_existing_appendices,
        set_cell_shading,
    )
    from update_full_report_fresh_results import load_fresh_evidence


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_REPORT = ROOT / "Document" / "outputs" / "final-report-gpt55-comparison.docx"
IMAGE_WIDTH = Inches(6.1)

BASELINE_COMMIT = "7a0469d9401a3061941b44fcd46b3beca1c9c729"
SONAR_COMMIT = "a2279bcbdc20751529335cf72f8baac1bc6f994b"
ZAP_COMMIT = "5f3bd3ccd9e0d460f52cac6a8a0d5fdceff1ce3d"
JMETER_COMMIT = "78b08b62570dcf6fe436354e8e6b770ab2074445"
REPRO_COMMIT = "efa19cea58c7746f88d1efd83fa34719673d1881"


APPENDIX_TITLES = {
    "A": "Environment and Repository Provenance",
    "B": "Authentication, JWT, and RBAC Source Code",
    "C": "Journal-Entry Accounting Source Code",
    "D": "Audit Logging and Traceability Source Code",
    "E": "SonarQube Remediation Source Code",
    "F": "OWASP ZAP Security-Hardening Source Code",
    "G": "JMeter Performance and Query-Optimization Source Code",
    "H": "Database Schema and Deterministic Seed Source Code",
    "I": "Automated Test Source Code",
    "J": "React Web Application and API Integration Source Code",
    "K": "Reproduction and Evidence-Automation Source Code",
    "L": "SonarQube, OWASP ZAP, and JMeter Dashboards",
    "M": "Result Traceability",
    "N": "Limitations and Complete Source Index",
}


LISTINGS = [
    {
        "id": "B.1",
        "title": "JWT Authentication Configuration",
        "purpose": "Configures JWT bearer validation at the API boundary so issuer, audience, signing key, and token lifetime are checked by ASP.NET Core.",
        "verification": "Related evidence: authenticated API scans, role-aware browser demonstration, and token unit tests.",
        "fragments": [
            {"label": "Remediated authentication registration", "ref": SONAR_COMMIT, "branch": "origin/baseline-sonarqube-v1", "path": "API/Program.cs", "ranges": [(77, 104)]},
        ],
    },
    {
        "id": "B.2",
        "title": "Controller-Level Role Enforcement",
        "purpose": "Requires authentication for the journal-entry controller and narrows posting and reversal operations to Admin and FinanceManager roles.",
        "verification": "Related evidence: RBAC integration matrix and browser role-restriction workflow.",
        "fragments": [
            {"label": "Controller and draft-creation authorization", "ref": SONAR_COMMIT, "branch": "origin/baseline-sonarqube-v1", "path": "API/Controllers/JournalEntriesController.cs", "ranges": [(9, 32)]},
            {"label": "Posting authorization and actor propagation", "ref": SONAR_COMMIT, "branch": "origin/baseline-sonarqube-v1", "path": "API/Controllers/JournalEntriesController.cs", "ranges": [(68, 87)]},
        ],
    },
    {
        "id": "C.1",
        "title": "Balanced Journal-Entry Posting",
        "purpose": "Prevents posting into a closed period, enforces debit-credit equality to two decimal places, persists the state transition, and records the actor and totals.",
        "verification": "Related evidence: posted-entry seed data, journal-line browser evidence, and audit-log output.",
        "fragments": [
            {"label": "Posting invariant and audit write", "ref": SONAR_COMMIT, "branch": "origin/baseline-sonarqube-v1", "path": "BAL/Services/JournalEntryService.cs", "ranges": [(198, 240)]},
        ],
    },
    {
        "id": "C.2",
        "title": "Journal-Entry Reversal",
        "purpose": "Creates a reversing draft by swapping debit and credit values, prevents duplicate reversal, and writes the resulting relationship to the audit trail.",
        "verification": "Related evidence: journal-entry service behavior and double-entry database constraints.",
        "fragments": [
            {"label": "Reversal workflow", "ref": SONAR_COMMIT, "branch": "origin/baseline-sonarqube-v1", "path": "BAL/Services/JournalEntryService.cs", "ranges": [(243, 310)]},
        ],
    },
    {
        "id": "D.1",
        "title": "Structured Audit-Log Writer",
        "purpose": "Serializes structured details and records the user, action, entity, identifier, timestamp, and network address for sensitive operations.",
        "verification": "Related evidence: audit-log API/browser screenshots and GENERATE_REPORT/POST_ENTRY audit records.",
        "fragments": [
            {"label": "Audit service", "ref": SONAR_COMMIT, "branch": "origin/baseline-sonarqube-v1", "path": "BAL/Services/AuditLogService.cs", "ranges": [(10, 45)]},
        ],
    },
    {
        "id": "D.2",
        "title": "Auditor-Role Read Boundary",
        "purpose": "Restricts audit-log retrieval to Admin and Auditor roles while keeping filtering and paging in the service layer.",
        "verification": "Related evidence: auditor navigation screenshot and RBAC matrix.",
        "fragments": [
            {"label": "Audit-log controller", "ref": SONAR_COMMIT, "branch": "origin/baseline-sonarqube-v1", "path": "API/Controllers/AuditLogsController.cs", "ranges": [(7, 32)]},
        ],
    },
    {
        "id": "E.1",
        "title": "S107 Controller-Parameter Remediation",
        "purpose": "Replaces eight query parameters with one request DTO, directly addressing the SonarQube S107 maintainability finding without changing the route.",
        "verification": "Fresh SonarQube result: 17 unique issues reduced to 0; Quality Gate remained OK.",
        "fragments": [
            {"label": "Before: long action signature", "ref": BASELINE_COMMIT, "branch": "origin/baseline-v0.1", "path": "API/Controllers/JournalEntriesController.cs", "ranges": [(61, 74)]},
            {"label": "After: DTO-bound action", "ref": SONAR_COMMIT, "branch": "origin/baseline-sonarqube-v1", "path": "API/Controllers/JournalEntriesController.cs", "ranges": [(61, 67)]},
            {"label": "Query DTO", "ref": SONAR_COMMIT, "branch": "origin/baseline-sonarqube-v1", "path": "MODEL/DTOs/FinancialAccountingDTOs.cs", "ranges": [(148, 166)]},
        ],
    },
    {
        "id": "E.2",
        "title": "S6966 Asynchronous Host Shutdown",
        "purpose": "Uses await app.RunAsync() instead of the blocking host call identified by the analyzer.",
        "verification": "Fresh remediation scan reported zero remaining issues.",
        "fragments": [
            {"label": "Before: blocking host call", "ref": BASELINE_COMMIT, "branch": "origin/baseline-v0.1", "path": "API/Program.cs", "ranges": [(176, 188)]},
            {"label": "After: asynchronous host call", "ref": SONAR_COMMIT, "branch": "origin/baseline-sonarqube-v1", "path": "API/Program.cs", "ranges": [(180, 190)]},
        ],
    },
    {
        "id": "F.1",
        "title": "Response Security-Headers Middleware",
        "purpose": "Applies CSP, framing, MIME-sniffing, permissions, and cross-origin policies immediately before each response is sent.",
        "verification": "Fresh passive ZAP scan: Medium 3 to 0 and Low 6 to 0.",
        "fragments": [
            {"label": "Security-header middleware", "ref": ZAP_COMMIT, "branch": "origin/baseline-zap-v1", "path": "API/Middleware/SecurityHeadersMiddleware.cs", "ranges": [(17, 63)]},
        ],
    },
    {
        "id": "F.2",
        "title": "Middleware Ordering and Swagger Exposure",
        "purpose": "Places response hardening before Swagger/OpenAPI and separates the Swagger document switch from the browser UI switch.",
        "verification": "Configured ZAP rules passed; one raw HTTP Only Site Medium observation remains disclosed for local HTTP transport.",
        "fragments": [
            {"label": "Before: baseline pipeline", "ref": BASELINE_COMMIT, "branch": "origin/baseline-v0.1", "path": "API/Program.cs", "ranges": [(135, 166)]},
            {"label": "After: hardened pipeline", "ref": ZAP_COMMIT, "branch": "origin/baseline-zap-v1", "path": "API/Program.cs", "ranges": [(135, 166)]},
        ],
    },
    {
        "id": "G.1",
        "title": "Concurrency-Safe Account-Ledger Cache",
        "purpose": "Uses a concurrent dictionary and Lazy<Task<T>> so simultaneous requests share one in-flight calculation and failed entries can be retried.",
        "verification": "Fresh performance evidence is mixed: spike improved, account-ledger soak regressed, and the core gate failed.",
        "fragments": [
            {"label": "Cache implementation", "ref": JMETER_COMMIT, "branch": "origin/baseline-jmeter-v1", "path": "BAL/Shared/AccountLedgerCache.cs", "ranges": [(8, 37)]},
        ],
    },
    {
        "id": "G.2",
        "title": "Read-Only Ledger Query and Running Balance",
        "purpose": "Aggregates the opening balance in SQL, retrieves the period lines without tracking, and computes a deterministic running balance.",
        "verification": "Table 4.4 reports the fresh endpoint-level soak and spike behavior rather than assuming universal improvement.",
        "fragments": [
            {"label": "Ledger payload query", "ref": JMETER_COMMIT, "branch": "origin/baseline-jmeter-v1", "path": "BAL/Services/FinancialReportService.cs", "ranges": [(154, 215)]},
        ],
    },
    {
        "id": "G.3",
        "title": "Idempotent SQL Server Performance Indexes",
        "purpose": "Creates the composite indexes required by report and journal-entry access paths only when SQL Server is the active provider.",
        "verification": "Related evidence: deterministic database initialization and JMeter branch provenance.",
        "fragments": [
            {"label": "Index startup component", "ref": JMETER_COMMIT, "branch": "origin/baseline-jmeter-v1", "path": "BAL/Shared/SqlServerPerformanceIndexStartup.cs", "ranges": [(1, 53)]},
        ],
    },
    {
        "id": "H.1",
        "title": "Deterministic Dataset Parameters",
        "purpose": "Pins the accounting period and dataset sizes while intentionally omitting credential values from the thesis listing.",
        "verification": "Fresh runs used 120 accounts, 30,000 journal entries, and at least 5,000 posted entries.",
        "fragments": [
            {"label": "Seed profile without credential parameters", "ref": BASELINE_COMMIT, "branch": "origin/baseline-v0.1", "path": "scripts/phase4/seed-test-data.ps1", "ranges": [(1, 2), (5, 10), (13, 27)]},
        ],
    },
    {
        "id": "H.2",
        "title": "Double-Entry Schema Constraints and Indexes",
        "purpose": "Defines journal headers and lines, enforces one-sided debit/credit values, and indexes the transaction access paths.",
        "verification": "Related evidence: balanced journal lines and report-generation database records.",
        "fragments": [
            {"label": "Journal schema", "ref": BASELINE_COMMIT, "branch": "origin/baseline-v0.1", "path": "Document/sql/financial_accounting_schema.sql", "ranges": [(363, 424)]},
        ],
    },
    {
        "id": "I.1",
        "title": "Role-by-Endpoint Integration Matrix",
        "purpose": "Generates test cases across every protected endpoint and role, authenticates the caller, and asserts the expected HTTP status.",
        "verification": "The matrix covers Admin, FinanceManager, User, Auditor, and Anonymous callers.",
        "fragments": [
            {"label": "RBAC matrix test", "ref": BASELINE_COMMIT, "branch": "origin/baseline-v0.1", "path": "tests/FinancialAccounting.IntegrationTests/RbacMatrixTests.cs", "ranges": [(23, 71)]},
        ],
    },
    {
        "id": "I.2",
        "title": "Security and Performance Configuration Defaults Test",
        "purpose": "Locks down the expected security-header defaults and the 50 and 500 VU gate thresholds used by the application configuration.",
        "verification": "Related evidence: fresh JMeter remediation failure against the configured 100 and 500 VU thresholds.",
        "fragments": [
            {"label": "Configuration defaults test", "ref": BASELINE_COMMIT, "branch": "origin/baseline-v0.1", "path": "tests/FinancialAccounting.UnitTests/AppSettingsTests.cs", "ranges": [(7, 19)]},
        ],
    },
    {
        "id": "J.1",
        "title": "Authenticated API Client",
        "purpose": "Adds the bearer token only when present, centralizes JSON headers and error parsing, and keeps the API base URL configurable.",
        "verification": "Related evidence: browser login, report, audit-log, and journal-line demonstrations.",
        "fragments": [
            {"label": "API request implementation", "ref": REPRO_COMMIT, "branch": "origin/codex/thesis-reproducibility-v1", "path": "WEB/src/lib/api.ts", "ranges": [(238, 270)]},
        ],
    },
    {
        "id": "J.2",
        "title": "Role-Aware Navigation and Mutation Rules",
        "purpose": "Maps server roles to visible routes and mutation permissions so the user interface mirrors, but does not replace, server-side authorization.",
        "verification": "Related evidence: Admin and Auditor browser screenshots plus server-side RBAC tests.",
        "fragments": [
            {"label": "Client permission map", "ref": REPRO_COMMIT, "branch": "origin/codex/thesis-reproducibility-v1", "path": "WEB/src/lib/permissions.ts", "ranges": [(13, 56)]},
        ],
    },
    {
        "id": "K.1",
        "title": "Exact-Commit Research Verification",
        "purpose": "Rejects the wrong commit or a dirty measurement checkout, binds runtime evidence to the live process, and dispatches only the tool appropriate to the evidence role.",
        "verification": "The thesis-script suite verifies exact-ref, clean-checkout, runtime-evidence, and failure-propagation behavior.",
        "fragments": [
            {"label": "Research verification guardrails", "ref": REPRO_COMMIT, "branch": "origin/codex/thesis-reproducibility-v1", "path": "scripts/thesis/Invoke-ResearchVerification.ps1", "ranges": [(1, 75)]},
        ],
    },
    {
        "id": "K.2",
        "title": "Environment and Tool Readiness Checks",
        "purpose": "Checks required files and tools, treats Docker as optional in Fast mode, and blocks Full mode when the research-tool environment is unavailable.",
        "verification": "The thesis-script suite verifies Fast/Full mode behavior and portable run records.",
        "fragments": [
            {"label": "Environment audit", "ref": REPRO_COMMIT, "branch": "origin/codex/thesis-reproducibility-v1", "path": "scripts/thesis/Test-ThesisEnvironment.ps1", "ranges": [(1, 25), (44, 70)]},
        ],
    },
]


DASHBOARDS = [
    ("sonarqube/sonarqube-baseline-overview.png", "SonarQube baseline overview"),
    ("sonarqube/sonarqube-baseline-issues.png", "SonarQube baseline issues"),
    ("sonarqube/sonarqube-remediation-overview.png", "SonarQube remediation overview"),
    ("sonarqube/sonarqube-remediation-issues.png", "SonarQube remediation issues"),
    ("zap/zap-baseline-before-summary.png", "OWASP ZAP passive baseline before remediation"),
    ("zap/zap-baseline-after-summary.png", "OWASP ZAP passive baseline after remediation"),
    ("zap/zap-api-before-summary.png", "OWASP ZAP authenticated API before remediation"),
    ("zap/zap-api-after-summary.png", "OWASP ZAP authenticated API after remediation"),
    ("jmeter/jmeter-baseline-p50-dashboard.png", "Apache JMeter baseline 50 VU"),
    ("jmeter/jmeter-baseline-p100-dashboard.png", "Apache JMeter baseline 100 VU"),
    ("jmeter/jmeter-baseline-p500-dashboard.png", "Apache JMeter baseline 500 VU"),
    ("jmeter/jmeter-baseline-soak-dashboard.png", "Apache JMeter baseline soak"),
    ("jmeter/jmeter-baseline-spike-dashboard.png", "Apache JMeter baseline spike"),
    ("jmeter/jmeter-remediation-p50-dashboard.png", "Apache JMeter remediation 50 VU"),
    ("jmeter/jmeter-remediation-p100-dashboard.png", "Apache JMeter remediation 100 VU"),
    ("jmeter/jmeter-remediation-p500-dashboard.png", "Apache JMeter remediation 500 VU"),
    ("jmeter/jmeter-remediation-soak-dashboard.png", "Apache JMeter remediation soak"),
    ("jmeter/jmeter-remediation-spike-dashboard.png", "Apache JMeter remediation spike"),
]


def read_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8-sig"))


def add_heading(doc: DocumentObject, text: str, level: int, *, page_break: bool = False):
    paragraph = doc.add_paragraph(text, style=f"Heading {level}")
    paragraph.paragraph_format.keep_with_next = True
    paragraph.paragraph_format.page_break_before = page_break
    return paragraph


def add_paragraph(doc: DocumentObject, text: str, *, bold_label: str | None = None):
    paragraph = doc.add_paragraph()
    paragraph.paragraph_format.space_after = Pt(6)
    if bold_label:
        run = paragraph.add_run(bold_label)
        run.bold = True
    paragraph.add_run(text)
    return paragraph


def add_table(doc: DocumentObject, rows: list[list[str]]) -> None:
    table = doc.add_table(rows=0, cols=len(rows[0]))
    table.style = "Table Grid"
    table.autofit = True
    for row_index, values in enumerate(rows):
        row = table.add_row()
        for cell, value in zip(row.cells, values, strict=True):
            cell.text = value
            if row_index == 0:
                set_cell_shading(cell, "D9EAF7")
            for paragraph in cell.paragraphs:
                paragraph.paragraph_format.space_before = Pt(0)
                paragraph.paragraph_format.space_after = Pt(0)
                for run in paragraph.runs:
                    run.font.name = "Times New Roman"
                    run.font.size = Pt(10)
                    run.bold = row_index == 0
    doc.add_paragraph()


def git_lines(root: Path, ref: str, path: str) -> list[str]:
    result = subprocess.run(
        ["git", "show", f"{ref}:{path}"],
        cwd=root,
        check=True,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    return result.stdout.splitlines()


def excerpt(root: Path, ref: str, path: str, ranges: list[tuple[int, int]]) -> list[tuple[int | None, str]]:
    lines = git_lines(root, ref, path)
    output: list[tuple[int | None, str]] = []
    for range_index, (start, end) in enumerate(ranges):
        if start < 1 or end < start or end > len(lines):
            raise RuntimeError(f"Invalid excerpt range {start}-{end} for {ref}:{path} ({len(lines)} lines)")
        if range_index:
            output.append((None, "// ... unrelated lines omitted ..."))
        output.extend((line_number, lines[line_number - 1]) for line_number in range(start, end + 1))

    joined = "\n".join(line for _, line in output)
    forbidden = ("Admin@123", "User@12345!", "gho_", "Bearer eyJ")
    if any(value in joined for value in forbidden):
        raise RuntimeError(f"Credential-shaped value detected in excerpt {ref}:{path}")
    return output


def add_code_block(doc: DocumentObject, lines: list[tuple[int | None, str]], style_name: str) -> None:
    for line_number, text in lines:
        leading_spaces = len(text) - len(text.lstrip(" "))
        wrapped = textwrap.wrap(
            text,
            width=84,
            subsequent_indent=" " * min(leading_spaces + 4, 24),
            replace_whitespace=False,
            drop_whitespace=True,
            break_long_words=False,
            break_on_hyphens=False,
        ) or [" "]
        for segment_index, segment in enumerate(wrapped):
            paragraph = doc.add_paragraph(style=style_name)
            shading = OxmlElement("w:shd")
            shading.set(qn("w:fill"), "F3F4F6")
            shading.set(qn("w:val"), "clear")
            paragraph._p.get_or_add_pPr().append(shading)
            prefix = "     " if line_number is None or segment_index else f"{line_number:4} "
            run = paragraph.add_run(prefix + segment)
            run.font.name = "Courier New"
            run.font.size = Pt(9)


def add_listing(doc: DocumentObject, root: Path, listing: dict, style_name: str, index: int) -> None:
    add_heading(doc, f"{listing['id']} {listing['title']}", 2)
    add_paragraph(doc, listing["purpose"], bold_label="Purpose: ")
    for fragment in listing["fragments"]:
        ranges = ", ".join(f"{start}-{end}" for start, end in fragment["ranges"])
        add_paragraph(
            doc,
            f"{fragment['label']}; file {fragment['path']}; branch {fragment['branch']}; commit {fragment['ref'][:8]}; lines {ranges}.",
            bold_label="Source: ",
        )
        add_code_block(
            doc,
            excerpt(root, fragment["ref"], fragment["path"], fragment["ranges"]),
            style_name,
        )
    verification = listing["verification"]
    if verification.startswith("Related evidence: "):
        verification = verification[len("Related evidence: ") :]
        verification = verification[:1].upper() + verification[1:]
    add_paragraph(doc, verification, bold_label="Verification: ")


def add_appendix_heading(doc: DocumentObject, letter: str) -> None:
    add_heading(doc, f"Appendix {letter} - {APPENDIX_TITLES[letter]}", 1)


def replace_cross_references(doc: DocumentObject) -> None:
    replacements = {
        "Appendices A-E provide the exact environment, branch and commit provenance, selected code listings, reproduction commands, and claim-to-artifact traceability.": "Appendices A-N provide the environment, exact branch and commit provenance, twenty curated source-code listings, reproduction automation, dashboards, traceability, and limitations directly in this full report.",
        "Appendices C and F": "Appendices E, L, and M",
        "Appendices C, E, and F": "Appendices F, L, and M",
        "Appendices D-F": "Appendices G and K-M",
    }
    for paragraph in doc.paragraphs:
        text = paragraph.text
        updated = text
        for old, new in replacements.items():
            updated = updated.replace(old, new)
        if updated != text:
            paragraph.clear()
            paragraph.add_run(updated)


def add_dashboard(
    doc: DocumentObject,
    image_path: Path,
    title: str,
    number: int,
    metadata: dict | None,
) -> None:
    add_heading(doc, f"L.{number} {title}", 2)
    picture = doc.add_paragraph()
    picture.alignment = WD_ALIGN_PARAGRAPH.CENTER
    picture.paragraph_format.keep_with_next = True
    picture.add_run().add_picture(str(image_path), width=IMAGE_WIDTH)
    caption = doc.add_paragraph(f"Figure L.{number}. {title} dashboard.", style="Caption")
    caption.alignment = WD_ALIGN_PARAGRAPH.CENTER
    caption.paragraph_format.keep_with_next = True
    for run in caption.runs:
        run.font.name = "Times New Roman"
        run.font.size = Pt(12)
    if metadata:
        add_paragraph(
            doc,
            f"Classification: {metadata.get('evidenceClassification')}; role: {metadata.get('evidenceRole')}; branch: {metadata.get('branch')}; commit: {str(metadata.get('commit', ''))[:8]}; run: {metadata.get('runId')}; tool version: {metadata.get('toolVersion')}; machine-readable source: {metadata.get('sourceArtifact')}.",
        )


def rebuild_code_appendices(report_path: Path, root: Path = ROOT) -> int:
    doc = Document(report_path)
    remove_existing_appendices(doc)
    replace_cross_references(doc)
    code_style = ensure_code_style(doc)
    doc.styles[code_style].font.name = "Courier New"
    doc.styles[code_style].font.size = Pt(9)
    bullet_style = ensure_bullet_style(doc)
    evidence = load_fresh_evidence(root)

    marker = add_heading(doc, APPENDIX_MARKER, 1, page_break=True)
    marker.paragraph_format.keep_with_next = True
    add_paragraph(
        doc,
        "These appendices are self-contained. They reproduce the essential implementation excerpts, explanations, commands, dashboards, and result provenance required to assess the study. The repository remains the authoritative complete source, but no external Markdown appendix is required to understand the evidence presented here.",
    )

    add_appendix_heading(doc, "A")
    add_paragraph(
        doc,
        "The study evaluates ChatGPT (Codex 5.4) against one ASP.NET Core financial-accounting API using branch-isolated baseline and remediation evidence. Exact refs prevent later branch movement from changing the evaluated source.",
    )
    add_table(
        doc,
        [
            ["Evidence role", "Reference", "Exact commit", "Purpose"],
            ["Baseline", "origin/baseline-v0.1", BASELINE_COMMIT, "Common pre-remediation source"],
            ["SonarQube remediation", "origin/baseline-sonarqube-v1", SONAR_COMMIT, "Static-analysis changes"],
            ["ZAP remediation", "origin/baseline-zap-v1", ZAP_COMMIT, "Security-hardening changes"],
            ["JMeter remediation", "origin/baseline-jmeter-v1", JMETER_COMMIT, "Performance changes"],
            ["Reproducibility package", "origin/codex/thesis-reproducibility-v1", REPRO_COMMIT, "Evidence automation and dashboard capture"],
        ],
    )
    for text in (
        "Platform: Windows 11; PowerShell; .NET 8; Node.js/npm; SQL Server LocalDB; Docker for SonarQube, OWASP ZAP, and JMeter. The fresh records do not pin CPU/RAM capacity or container resource limits.",
        "Dataset: 120 accounts; 30,000 journal entries; at least 5,000 posted entries; accounting period 202601.",
        "Fresh reproduction date: September 22, 2026. Historical values are retained only for comparison and provenance.",
    ):
        paragraph = doc.add_paragraph(style=bullet_style)
        paragraph.add_run(text)

    listing_index = 0
    for letter in "BCDEFGHIJK":
        add_appendix_heading(doc, letter)
        appendix_listings = [listing for listing in LISTINGS if listing["id"].startswith(f"{letter}.")]
        for local_index, listing in enumerate(appendix_listings):
            add_listing(doc, root, listing, code_style, local_index)
            listing_index += 1
        if letter == "K":
            add_heading(doc, "K.3 Reproduction Command Sequence", 2)
            add_paragraph(doc, "The following commands execute the self-contained fast verification and local demonstration workflow. Secrets are supplied through process-local environment variables and are not printed in this report.")
            commands = [
                (None, ".\\scripts\\thesis\\Test-ThesisEnvironment.ps1 -Mode Fast"),
                (None, ".\\scripts\\thesis\\Initialize-ThesisDatabase.ps1"),
                (None, ".\\scripts\\thesis\\Invoke-ThesisVerification.ps1 -Mode Fast"),
                (None, ".\\scripts\\thesis\\Invoke-ThesisDemo.ps1 -KeepRunning"),
                (None, ".\\scripts\\thesis\\New-DashboardCaptureCases.ps1 -OutputPath '.tmp/dashboard-cases.json'"),
                (None, "$env:THESIS_DASHBOARD_CASES = '.tmp/dashboard-cases.json'"),
                (None, "npm run capture:appendix --prefix WEB"),
            ]
            add_code_block(doc, commands, code_style)

    add_appendix_heading(doc, "L")
    manifest = read_json(root / "docs" / "appendix" / "dashboard-capture-manifest.json")
    captures = {capture["imagePath"]: capture for capture in manifest.get("captures", [])}
    dashboard_root = root / "docs" / "appendix" / "dashboards"
    for number, (relative_path, title) in enumerate(DASHBOARDS, start=1):
        image_path = dashboard_root / relative_path
        if not image_path.exists():
            raise FileNotFoundError(image_path)
        add_dashboard(doc, image_path, title, number, captures.get(relative_path))

    add_appendix_heading(doc, "M")
    sonar = evidence["sonar"]
    zap = evidence["zap"]
    jmeter = evidence["jmeter"]
    add_paragraph(
        doc,
        "Current conclusions use the fresh September 22 reproduction. Historical measurements are retained in the comparison column so the evolution of the study remains auditable.",
    )
    add_table(
        doc,
        [
            ["Tool", "Current fresh result", "Historical comparison", "Machine-readable evidence"],
            ["SonarQube", f"{sonar['baseline_issues']} unique issues to {sonar['remediation_issues']}; coverage {sonar['baseline_coverage']}% to {sonar['remediation_coverage']}%; gates {sonar['baseline_gate']}/{sonar['remediation_gate']}", "28 retained findings to 0; coverage reported as 74.3%", "docs/appendix/verification-runs/research/sonar/*"],
            ["OWASP ZAP", "Passive M3/L6 to M0/L0; API M1/L3 to M1/L0; configured gate passed", "Earlier scans reported all gated Medium/Low alerts cleared", "docs/appendix/verification-runs/research/zap/*"],
            ["Apache JMeter", "Core gate FAIL; 50 VU 33 to 199.9 ms; 100 VU 255.9 to 1146.9 ms; 500 VU 106 to 1547.95 ms; soak/spike aggregates improved", "Earlier run reported core and stress p95 improvements", "docs/appendix/verification-runs/research/jmeter/*"],
            ["Application demonstration", "API health, frontend smoke, and browser role workflow PASS", "Role-aware React client added as a validation artifact", "docs/appendix/verification-runs/demo-*.json"],
        ],
    )

    add_appendix_heading(doc, "N")
    for text in (
        "The study covers one ASP.NET Core application, one dataset profile, one AI assistant configuration, and one fresh measurement run per evidence branch.",
        "SonarQube MQR Reliability, Security, and Maintainability impacts overlap and must not be added together as unique issues.",
        "The fresh authenticated ZAP scan retains one raw Medium HTTP Only Site observation because the local reproduction uses HTTP instead of a production TLS endpoint.",
        "The fresh JMeter remediation core gate fails even though soak and spike aggregate p95 improve; this prevents a general performance-improvement claim.",
        "The fresh run records do not preserve CPU model or core count, installed RAM, per-run CPU and memory utilization, or application, database, and Docker resource limits. The local setup did not evaluate a managed-cloud service tier; results cannot be generalized to differently sized devices or hosted tiers. Future work should record these capacities and repeat matched runs with variability or confidence intervals.",
        "The listings below are deliberately curated. The complete repository at the pinned commits remains authoritative for files not reproduced in full.",
    ):
        paragraph = doc.add_paragraph(style=bullet_style)
        paragraph.add_run(text)

    index_rows = [["Listing and purpose", "File", "Branch/ref", "Commit"]]
    for listing in LISTINGS:
        seen: set[tuple[str, str, str]] = set()
        for fragment in listing["fragments"]:
            key = (fragment["path"], fragment["branch"], fragment["ref"])
            if key in seen:
                continue
            seen.add(key)
            index_rows.append(
                [
                    f"{listing['id']} - {listing['title']}",
                    fragment["path"],
                    fragment["branch"],
                    fragment["ref"][:8],
                ]
            )
    add_table(doc, index_rows)

    doc.save(report_path)
    return len(LISTINGS)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Rebuild the full-report appendices directly around curated source-code listings."
    )
    parser.add_argument("report", nargs="?", type=Path, default=DEFAULT_REPORT)
    args = parser.parse_args()
    report_path = args.report.resolve()
    count = rebuild_code_appendices(report_path, ROOT)
    print(report_path)
    print(f"Curated source-code listings: {count}")


if __name__ == "__main__":
    main()
