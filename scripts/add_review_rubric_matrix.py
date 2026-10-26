"""Add an evidence-backed decision matrix to both final-report variants."""

from pathlib import Path

from docx import Document


ROOT = Path(__file__).resolve().parents[1]
TARGETS = (
    ROOT / "Document/outputs/final-report.docx",
    ROOT / "Document/outputs/final-report-gpt55-comparison.docx",
)
HEADER = ("Review dimension", "Decision rule", "Observed evidence", "Disposition")
ROWS = (
    (
        "SonarQube code quality",
        "Raw Quality Gate OK; no retained blocker/critical findings",
        "28→0 retained C# findings; dashboard smells 21→0; raw gate OK",
        "PASS on scanned branch",
    ),
    (
        "ZAP security",
        "No High/Medium alerts after; reduce Low findings",
        "Baseline 2 Medium/6 Low→0; authenticated API 3 Low→0",
        "PASS on tested routes",
    ),
    (
        "50-user load",
        "p95 ≤300 ms; errors ≤0.5%; valid 50-user hold",
        "After median p95 29 ms; 0% errors; 3/3 valid passes",
        "PASS",
    ),
    (
        "100-user load",
        "p95 ≤500 ms; errors ≤1%; valid 100-user hold",
        "After median p95 47 ms; 0% errors; 3/3 valid passes",
        "PASS",
    ),
    (
        "500-user load",
        "p95 ≤1,200 ms; errors ≤2%; valid 500-user hold",
        "After median p95 1,294 ms; 0% errors; p95 gate 0/3",
        "FAIL p95; errors PASS",
    ),
    (
        "Soak stability",
        "First-to-last ten-minute p95 drift ≤20%; errors ≤1%",
        "After relative drift gate 1/3; 0% scored errors",
        "FAIL drift; errors PASS",
    ),
    (
        "Spike recovery",
        "Recovery/base p95 drift ≤20%; scored errors ≤3%",
        "After relative drift gate 0/3; 0% scored errors",
        "FAIL drift; errors PASS",
    ),
    (
        "p99 and resource use",
        "Report p99, CPU/RAM, spread and validity; no p99 pass limit",
        "50-user paired p99 +23.50%; CPU/RAM in Tables 4.6–4.7",
        "DESCRIPTIVE; not scored",
    ),
)

for path in TARGETS:
    doc = Document(path)
    for paragraph in doc.paragraphs:
        if paragraph.text.startswith((
            "Did ChatGPT’s recommendations achieve measurable improvements?",
            "Decision rule. PASS means",
        )) and "Table 3.10 links" in paragraph.text:
            paragraph.text = paragraph.text.replace(
                "Table 3.10 links",
                "The operational review rubric table in §3.4.1 links",
            )
    if any(
        tuple(cell.text for cell in table.rows[0].cells) == HEADER
        for table in doc.tables
        if table.rows
    ):
        if "gpt55" in path.name:
            for paragraph in doc.paragraphs:
                if paragraph.text.startswith("Table 3.") and "Operational review rubric" in paragraph.text:
                    paragraph.paragraph_format.page_break_before = True
        doc.save(path)
        print(f"matrix already present: {path}")
        continue

    status = next(
        (p for p in doc.paragraphs if p.text.startswith("Status vocabulary. PASS means")),
        None,
    )
    if status is None:
        raise RuntimeError(f"Could not find review rubric in {path}")
    status.text = (
        status.text
        + " No proposal-level numeric score or independent reviewer rating was recorded; "
        "the matrix below applies measured tool gates and a documented human decision, "
        "not a weighted ChatGPT-quality score. The exact load limits are study-specific "
        "pre-scoring choices, not thresholds supplied by a cited paper."
    )

    old = next(
        (p for p in doc.paragraphs if p.text.startswith("Did ChatGPT’s recommendations achieve measurable improvements?")),
        None,
    )
    if old is not None:
        old.text = (
            "Did ChatGPT’s recommendations achieve measurable improvements? Each dimension "
            "is evaluated against its predeclared success criteria. PASS means its required "
            "checks and gate were met; PARTIAL means improvement with a required dimension "
            "still open; FAIL identifies a missed required gate. Invalid JMeter runs are "
            "EXCLUDED and rerun. The operational review rubric table in §3.4.1 links each measure to its observed value and "
            "decision; the categories do not constitute a numerical score for ChatGPT."
        )
    else:
        decision = next(
            (p for p in doc.paragraphs if p.text.startswith("Decision rule. In this report")),
            None,
        )
        if decision is None:
            raise RuntimeError(f"Could not find effectiveness vocabulary in {path}")
        decision.text = (
            "Decision rule. PASS means the complete predeclared target and required "
            "checks were met; PARTIAL means the primary measure improved while a "
            "required dimension remains open; FAIL means a required gate was missed. "
            "An invalid JMeter run is EXCLUDED and rerun. The operational review rubric table in §3.4.1 links each "
            "measure to its observed result. These categories are not a numerical "
            "score for ChatGPT. Sections 4.2–4.5 explain the measured outcomes."
        )
        for paragraph in doc.paragraphs:
            if paragraph.text.startswith("Outcome judgment: Achieved."):
                paragraph.text = paragraph.text.replace("Outcome judgment: Achieved.", "Outcome judgment: PASS.", 1)
            elif paragraph.text.startswith("Outcome judgment: Achieved within"):
                paragraph.text = paragraph.text.replace("Outcome judgment: Achieved within", "Outcome judgment: PASS within", 1)
            elif paragraph.text.startswith("Outcome judgment: The after revision"):
                paragraph.text = paragraph.text.replace("Not Achieved", "FAIL")
            elif paragraph.text.startswith("Overall, the code-quality criterion"):
                paragraph.text = paragraph.text.replace("were achieved", "passed").replace("Not Achieved", "FAIL")

    table = doc.add_table(rows=1, cols=len(HEADER))
    for cell, value in zip(table.rows[0].cells, HEADER):
        cell.text = value
    for values in ROWS:
        for cell, value in zip(table.add_row().cells, values):
            cell.text = value
    status._p.addnext(table._tbl)
    doc.save(path)
    print(f"added {len(ROWS)} rubric rows: {path}")
