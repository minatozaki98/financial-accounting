from __future__ import annotations

import argparse
import importlib.util
import re
from copy import deepcopy
from pathlib import Path

from docx import Document
from docx.document import Document as DocumentObject
from docx.enum.table import WD_CELL_VERTICAL_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Inches, Pt, Twips
from docx.text.paragraph import Paragraph

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_REPORT = ROOT / "Document" / "outputs" / "final-report-gpt55-comparison.docx"
BODY_STYLES = {"Normal", "List Paragraph"}
CHAPTER_PATTERN = re.compile(r"^Chapter\s+\d+", re.IGNORECASE)
SECTION_PATTERN = re.compile(r"^\d+\.\d+(?:\.\d+)?\s")


def load_report_formatter():
    try:
        import format_final_report_docx

        return format_final_report_docx
    except ModuleNotFoundError:
        path = Path(__file__).with_name("format_final_report_docx.py")
        spec = importlib.util.spec_from_file_location("format_final_report_docx", path)
        if spec is None or spec.loader is None:
            raise RuntimeError(f"Could not load {path}")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module


report_formatter = load_report_formatter()


def normalized(text: str) -> str:
    return " ".join(text.split())


def has_page_break(paragraph) -> bool:
    return bool(paragraph._p.xpath('.//w:br[@w:type="page"]'))


def has_drawing(paragraph) -> bool:
    return bool(paragraph._p.xpath(".//w:drawing"))


def is_empty_paragraph(paragraph) -> bool:
    return (
        not paragraph.text.strip()
        and not has_drawing(paragraph)
        and not has_page_break(paragraph)
        and not paragraph._p.xpath(".//w:fldChar")
    )


def remove_paragraph(paragraph) -> None:
    parent = paragraph._element.getparent()
    if parent is not None:
        parent.remove(paragraph._element)


def remove_page_breaks(paragraph) -> None:
    for page_break in list(paragraph._p.xpath('.//w:br[@w:type="page"]')):
        parent = page_break.getparent()
        if parent is not None:
            parent.remove(page_break)


def set_cell_margins(cell, *, top: int = 72, start: int = 90, bottom: int = 72, end: int = 90) -> None:
    tc_pr = cell._tc.get_or_add_tcPr()
    tc_mar = tc_pr.first_child_found_in("w:tcMar")
    if tc_mar is None:
        tc_mar = OxmlElement("w:tcMar")
        tc_pr.append(tc_mar)
    for margin_name, value in (("top", top), ("start", start), ("bottom", bottom), ("end", end)):
        margin = tc_mar.find(qn(f"w:{margin_name}"))
        if margin is None:
            margin = OxmlElement(f"w:{margin_name}")
            tc_mar.append(margin)
        margin.set(qn("w:w"), str(value))
        margin.set(qn("w:type"), "dxa")


def is_signature_table(table) -> bool:
    if not table.rows:
        return False
    first_row = [normalized(cell.text) for cell in table.rows[0].cells]
    return not any(first_row) or all(not text or set(text) <= {"_"} for text in first_row)


def is_code_table(table) -> bool:
    return len(table.rows) == 1 and len(table.columns) == 1


def table_header(table) -> tuple[str, ...]:
    if not table.rows:
        return ()
    return tuple(normalized(cell.text) for cell in table.rows[0].cells)


def set_fixed_table_widths(table, widths) -> None:
    table.autofit = False
    tbl_pr = table._tbl.tblPr
    layout = tbl_pr.find(qn("w:tblLayout"))
    if layout is None:
        layout = OxmlElement("w:tblLayout")
        tbl_pr.append(layout)
    layout.set(qn("w:type"), "fixed")

    grid_columns = list(table._tbl.tblGrid.gridCol_lst)
    for grid_column, width in zip(grid_columns, widths, strict=True):
        grid_column.set(qn("w:w"), str(width.twips))

    for row in table.rows:
        for cell, width in zip(row.cells, widths, strict=True):
            cell.width = width
            tc_width = cell._tc.get_or_add_tcPr().get_or_add_tcW()
            tc_width.set(qn("w:w"), str(width.twips))
            tc_width.set(qn("w:type"), "dxa")


def prevent_row_split(row) -> None:
    tr_pr = row._tr.get_or_add_trPr()
    cant_split = tr_pr.find(qn("w:cantSplit"))
    if cant_split is None:
        tr_pr.append(OxmlElement("w:cantSplit"))


def normalize_source_index_table(table) -> None:
    header = table_header(table)
    if header == ("Listing", "Purpose", "File", "Branch/ref", "Commit"):
        for row_index, row in enumerate(table.rows):
            cells = row.cells
            cells[0].text = (
                "Listing and purpose"
                if row_index == 0
                else f"{normalized(cells[0].text)} - {normalized(cells[1].text)}"
            )
            row._tr.remove(cells[1]._tc)
        grid_columns = table._tbl.tblGrid.gridCol_lst
        table._tbl.tblGrid.remove(grid_columns[1])

    if table_header(table) == ("Listing and purpose", "File", "Branch/ref", "Commit"):
        set_fixed_table_widths(
            table,
            (Inches(1.8), Inches(2.65), Inches(1.3), Inches(0.75)),
        )
        for row in table.rows:
            prevent_row_split(row)


def format_code_table(table) -> None:
    try:
        table.style = "Table Grid"
    except KeyError:
        pass
    table.autofit = True
    cell = table.cell(0, 0)
    cell.vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.TOP
    set_cell_margins(cell, top=72, start=108, bottom=72, end=108)
    for paragraph in cell.paragraphs:
        paragraph.paragraph_format.space_before = Pt(0)
        paragraph.paragraph_format.space_after = Pt(0)
        paragraph.paragraph_format.line_spacing = 1.0
        for run in paragraph.runs:
            run.font.name = "Courier New"
            run.font.size = Pt(9.5)
            run.bold = False


def format_data_tables(doc: DocumentObject) -> None:
    section = doc.sections[0]
    usable_twips = round(
        (section.page_width - section.left_margin - section.right_margin) / 635
    )
    for table in doc.tables:
        normalize_source_index_table(table)
        if is_signature_table(table):
            continue
        if is_code_table(table):
            format_code_table(table)
            continue

        report_formatter.format_data_table(table)
        for row_index, row in enumerate(table.rows):
            for cell in row.cells:
                cell.vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER
                set_cell_margins(cell)
                for paragraph in cell.paragraphs:
                    paragraph.paragraph_format.line_spacing = 1.0
                    paragraph.paragraph_format.first_line_indent = Inches(0)
                    paragraph.alignment = (
                        WD_ALIGN_PARAGRAPH.CENTER
                        if row_index == 0
                        else WD_ALIGN_PARAGRAPH.LEFT
                    )
                    for run in paragraph.runs:
                        technical = run.font.name == "Courier New"
                        run.font.name = "Courier New" if technical else "Times New Roman"
                        run.font.size = Pt(10)
                        run.bold = row_index == 0
        if table_header(table) == ("Listing and purpose", "File", "Branch/ref", "Commit"):
            normalize_source_index_table(table)
        else:
            grid = list(table._tbl.tblGrid.gridCol_lst)
            widths = [int(column.get(qn("w:w"))) for column in grid]
            if sum(widths) > usable_twips:
                scale = usable_twips / sum(widths)
                widths = [round(width * scale) for width in widths]
                widths[-1] += usable_twips - sum(widths)
            set_fixed_table_widths(table, tuple(Twips(width) for width in widths))


def body_bounds(doc: DocumentObject) -> tuple[int, int]:
    paragraphs = doc.paragraphs
    chapter_one = next(
        i for i, p in enumerate(paragraphs)
        if normalized(p.text) == "Chapter 1 - Introduction"
        and p.style.name == "Heading 1"
    )
    appendices = next(
        i for i, p in enumerate(paragraphs)
        if normalized(p.text) == "APPENDICES"
        and p.style.name == "Heading 1"
    )
    return chapter_one, appendices


def ensure_section_3_1(doc: DocumentObject) -> None:
    if any(normalized(p.text) == "3.1 Research Design and Workflow" for p in doc.paragraphs):
        return
    chapter_three = next(
        p for p in doc.paragraphs
        if normalized(p.text) == "Chapter 3: Proposed Methodology"
        and p.style.name == "Heading 1"
    )
    caption = next(
        p for p in doc.paragraphs
        if normalized(p.text).startswith("Table 3.1.")
        and p.style.name == "Caption"
    )
    if chapter_three._p.getparent() is not caption._p.getparent():
        raise RuntimeError("Chapter 3 and Table 3.1 are not in the same document body")
    new_p = OxmlElement("w:p")
    caption._p.addprevious(new_p)
    heading = Paragraph(new_p, caption._parent)
    heading.style = "Heading 2"
    heading.add_run("3.1 Research Design and Workflow")
    heading.paragraph_format.keep_with_next = True


def normalize_heading_pagination(doc: DocumentObject) -> None:
    start, _ = body_bounds(doc)
    for paragraph in list(doc.paragraphs[start:]):
        text = normalized(paragraph.text)
        if CHAPTER_PATTERN.match(text):
            paragraph.text = text
            paragraph.style = "Heading 1"
            paragraph.paragraph_format.page_break_before = True
        elif text in {"REFERENCES", "References", "APPENDICES"}:
            paragraph.style = "Heading 1"
            paragraph.paragraph_format.page_break_before = True
        elif SECTION_PATTERN.match(text):
            remove_page_breaks(paragraph)

    paragraphs = list(doc.paragraphs)
    for index, paragraph in enumerate(paragraphs[:-1]):
        if not has_page_break(paragraph) or paragraph.text.strip() or has_drawing(paragraph):
            continue
        next_text = normalized(paragraphs[index + 1].text)
        if CHAPTER_PATTERN.match(next_text) or next_text in {"REFERENCES", "References", "APPENDICES"}:
            remove_paragraph(paragraph)
        elif SECTION_PATTERN.match(next_text):
            remove_paragraph(paragraph)

    paragraphs = list(doc.paragraphs)
    for index, paragraph in enumerate(paragraphs[1:], start=1):
        if not paragraph.paragraph_format.page_break_before:
            continue
        previous = paragraphs[index - 1]
        if is_empty_paragraph(previous):
            remove_paragraph(previous)


def normalize_body_paragraphs(doc: DocumentObject) -> None:
    start, end = body_bounds(doc)
    for paragraph in doc.paragraphs[start:end]:
        text = normalized(paragraph.text)
        if not text or paragraph.style.name not in BODY_STYLES:
            continue

        paragraph.paragraph_format.space_before = Pt(0)
        paragraph.paragraph_format.space_after = Pt(6)
        for run in paragraph.runs:
            if run.font.name != "Courier New":
                run.font.name = "Times New Roman"
            run.font.size = Pt(12)

        visible_runs = [run for run in paragraph.runs if run.text.strip()]
        if len(text) >= 55 and visible_runs and all(run.bold is True for run in visible_runs):
            for run in visible_runs:
                run.bold = False


def release_unnecessary_image_page_breaks(doc: DocumentObject) -> None:
    start, end = body_bounds(doc)
    for paragraph in doc.paragraphs[start:end]:
        if has_drawing(paragraph) and paragraph.paragraph_format.page_break_before:
            paragraph.paragraph_format.page_break_before = False


def collapse_repeated_blank_paragraphs(doc: DocumentObject) -> None:
    start, end = body_bounds(doc)
    body = list(doc.paragraphs[start:end])
    previous_empty = False
    for paragraph in body:
        empty = is_empty_paragraph(paragraph)
        if empty and previous_empty:
            remove_paragraph(paragraph)
        previous_empty = empty


def normalize_report(path: Path) -> None:
    doc = Document(path)
    report_formatter.configure_caption_style(doc)
    report_formatter.configure_heading_styles(doc)
    report_formatter.apply_heading_styles(doc)
    ensure_section_3_1(doc)
    normalize_heading_pagination(doc)
    report_formatter.normalize_heading_runs(doc)
    normalize_body_paragraphs(doc)
    release_unnecessary_image_page_breaks(doc)
    collapse_repeated_blank_paragraphs(doc)
    format_data_tables(doc)
    report_formatter.enforce_document_typography(doc)
    report_formatter.enable_field_update_on_open(doc)
    doc.save(path)


def compact_appendices(doc: DocumentObject) -> None:
    marker = next(
        paragraph for paragraph in doc.paragraphs
        if normalized(paragraph.text) == "APPENDICES"
        and paragraph.style.name == "Heading 1"
    )
    appendix_paragraphs = doc.paragraphs[
        next(i for i, paragraph in enumerate(doc.paragraphs) if paragraph._p is marker._p) + 1 :
    ]

    for paragraph in appendix_paragraphs:
        if "\nFresh reproduction date:" not in paragraph.text or not paragraph.text.startswith("Dataset:"):
            continue
        dataset, fresh = paragraph.text.split("\n", 1)
        next_p = OxmlElement("w:p")
        paragraph._p.addnext(next_p)
        if paragraph._p.pPr is not None:
            next_p.append(deepcopy(paragraph._p.pPr))
        fresh_paragraph = Paragraph(next_p, paragraph._parent)
        paragraph.clear()
        paragraph.add_run(dataset)
        fresh_paragraph.add_run(fresh)

    marker_index = next(i for i, paragraph in enumerate(doc.paragraphs) if paragraph._p is marker._p)
    for paragraph in doc.paragraphs[marker_index + 1 :]:
        text = normalized(paragraph.text)
        if re.match(r"^Appendix [A-N] - ", text):
            paragraph.style = "Heading 1"
            num_pr = paragraph._p.xpath("./w:pPr/w:numPr")
            for element in num_pr:
                element.getparent().remove(element)
        style_name = paragraph.style.name
        paragraph.paragraph_format.page_break_before = False
        if style_name in {"Heading 1", "Heading 2", "Heading 3"}:
            paragraph.alignment = WD_ALIGN_PARAGRAPH.LEFT
            paragraph.paragraph_format.left_indent = Inches(0)
            paragraph.paragraph_format.first_line_indent = Inches(0)
            paragraph.paragraph_format.line_spacing = 2.0
            paragraph.paragraph_format.keep_with_next = True
            size = {"Heading 1": 16, "Heading 2": 14, "Heading 3": 12}[style_name]
        elif style_name == "Appendix Code":
            paragraph.alignment = WD_ALIGN_PARAGRAPH.LEFT
            paragraph.paragraph_format.line_spacing = 1.0
            size = 9.5
        elif style_name == "Caption":
            paragraph.alignment = WD_ALIGN_PARAGRAPH.CENTER
            paragraph.paragraph_format.first_line_indent = Inches(0)
            paragraph.paragraph_format.line_spacing = 2.0
            size = 12
        elif text:
            paragraph.paragraph_format.line_spacing = 2.0
            size = 12
            if text.startswith(("Source.", "Source:", "Classification:")) or style_name == "Appendix Bullet":
                paragraph.alignment = WD_ALIGN_PARAGRAPH.LEFT
                if style_name == "Normal":
                    paragraph.paragraph_format.first_line_indent = Inches(0)
            else:
                paragraph.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
                if style_name == "Normal":
                    paragraph.paragraph_format.first_line_indent = Inches(0.5)
        else:
            continue

        for run in paragraph.runs:
            font_name = "Courier New" if style_name == "Appendix Code" or run.font.name == "Courier New" else "Times New Roman"
            run.font.name = font_name
            run.font.size = Pt(size)

    report_formatter.normalize_numbering_fonts(doc)


def compact_appendices_file(path: Path) -> None:
    doc = Document(path)
    compact_appendices(doc)
    report_formatter.enable_field_update_on_open(doc)
    doc.save(path)


def tidy_examples_and_evidence(doc: DocumentObject) -> None:
    paragraphs = list(doc.paragraphs)
    for index, paragraph in enumerate(paragraphs[:-1]):
        if (
            normalized(paragraph.text) == "Example:"
            and normalized(paragraphs[index + 1].text) == "Security Enhancement:"
        ):
            paragraph.clear()
            paragraph.add_run("Example: Security Enhancement")
            remove_paragraph(paragraphs[index + 1])

    for paragraph in list(doc.paragraphs):
        text = normalized(paragraph.text)
        if text == "3.1.2 Selected Source-Code Evidence" and paragraph.text != text:
            paragraph.clear()
            paragraph.add_run(text)
            continue
        if text == "Performance Optimization:":
            text = "Example: Performance Optimization"
        if text in report_formatter.EXAMPLE_LABELS:
            paragraph.clear()
            run = paragraph.add_run(text)
            run.bold = True
            run.font.name = "Times New Roman"
            run.font.size = Pt(12)
            paragraph.style = "Normal"
            paragraph.alignment = WD_ALIGN_PARAGRAPH.LEFT
            paragraph.paragraph_format.left_indent = Inches(0.5)
            paragraph.paragraph_format.first_line_indent = Inches(0)
            paragraph.paragraph_format.line_spacing = 2.0
            paragraph.paragraph_format.space_before = Pt(0)
            paragraph.paragraph_format.space_after = Pt(0)
            paragraph.paragraph_format.keep_with_next = True
        elif text.startswith(report_formatter.EXAMPLE_DETAIL_PREFIXES):
            for element in paragraph._p.xpath("./w:pPr/w:numPr"):
                element.getparent().remove(element)
            paragraph.style = "Normal"
            paragraph.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
            paragraph.paragraph_format.left_indent = Inches(0.5)
            paragraph.paragraph_format.first_line_indent = Inches(0)
            paragraph.paragraph_format.line_spacing = 2.0
        elif text.startswith("Source-code evidence "):
            paragraph.alignment = WD_ALIGN_PARAGRAPH.LEFT
            paragraph.paragraph_format.left_indent = Inches(0)
            paragraph.paragraph_format.first_line_indent = Inches(0)
            paragraph.paragraph_format.line_spacing = 2.0
            paragraph.paragraph_format.keep_with_next = True

    paragraphs = list(doc.paragraphs)
    for index, paragraph in enumerate(paragraphs[1:-1], start=1):
        if not is_empty_paragraph(paragraph):
            continue
        previous = normalized(paragraphs[index - 1].text)
        following = normalized(paragraphs[index + 1].text)
        if (
            previous.startswith("Financial Accounting API:")
            and following.startswith("The API features role-based access control")
        ) or (
            previous.startswith("Performance: Run JMeter")
            and has_drawing(paragraphs[index + 1])
        ):
            remove_paragraph(paragraph)


def tidy_examples_and_evidence_file(path: Path) -> None:
    doc = Document(path)
    tidy_examples_and_evidence(doc)
    report_formatter.enable_field_update_on_open(doc)
    doc.save(path)


PHASE_TECHNICAL_PATTERN = re.compile(
    r"\b(?:GET|POST|PUT|DELETE|PATCH)\s+/(?:api/)?[A-Za-z0-9_{}?&=./:\-]+"
    r"|\bdotnet test\b"
)


def set_phase_prose(paragraph: Paragraph, text: str) -> None:
    paragraph.clear()
    cursor = 0
    for match in PHASE_TECHNICAL_PATTERN.finditer(text):
        if match.start() > cursor:
            paragraph.add_run(text[cursor : match.start()])
        run = paragraph.add_run(match.group(0))
        run.font.name = "Courier New"
        cursor = match.end()
    if cursor < len(text):
        paragraph.add_run(text[cursor:])
    paragraph.style = "Normal"
    paragraph.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
    paragraph.paragraph_format.left_indent = Inches(0)
    paragraph.paragraph_format.first_line_indent = Inches(0.5)
    paragraph.paragraph_format.line_spacing = 2.0
    paragraph.paragraph_format.space_before = Pt(0)
    paragraph.paragraph_format.space_after = Pt(6)
    paragraph.paragraph_format.keep_with_next = False
    for run in paragraph.runs:
        run.font.size = Pt(12)
        if run.font.name != "Courier New":
            run.font.name = "Times New Roman"


def smooth_phase_narrative(doc: DocumentObject) -> None:
    paragraphs = doc.paragraphs
    start = next(i for i, p in enumerate(paragraphs) if normalized(p.text) == "3.1.1 Testing Environment and Reproducibility")
    end = next(i for i, p in enumerate(paragraphs[start + 1 :], start + 1) if normalized(p.text) == "3.1.2 Selected Source-Code Evidence")
    section = paragraphs[start:end]
    if any(
        normalized(p.text).startswith("Initial security, performance, and code-quality testing is conducted")
        for p in section
    ):
        return

    def find(prefix: str) -> Paragraph:
        matches = [p for p in section if normalized(p.text).startswith(prefix)]
        if len(matches) != 1:
            raise RuntimeError(f"Expected one Phase 1-4 paragraph beginning {prefix!r}; found {len(matches)}")
        return matches[0]

    headings = [find(f"Phase {number}:") for number in range(1, 5)]
    for heading in headings:
        heading.style = "Normal"
        heading.alignment = WD_ALIGN_PARAGRAPH.LEFT
        heading.paragraph_format.left_indent = Inches(0)
        heading.paragraph_format.first_line_indent = Inches(0)
        heading.paragraph_format.line_spacing = 2.0
        heading.paragraph_format.space_after = Pt(0)
        heading.paragraph_format.keep_with_next = True
        for run in heading.runs:
            run.bold = True
            run.font.name = "Times New Roman"
            run.font.size = Pt(12)

    baseline = find("Initial security and performance testing")
    set_phase_prose(
        baseline,
        "Initial security, performance, and code-quality testing is conducted on the financial accounting ASP.NET Core RESTful API. Its endpoints cover authentication, chart of accounts, journal entries, accounting periods, financial reports, and audit logs. SonarQube analyzes source-code quality, OWASP ZAP runs baseline and authenticated API security scans, and Apache JMeter runs load, soak, and spike profiles at 50, 100, and 500 concurrent users. Measurements from the common baseline branch provide the reference for evaluating subsequent changes.",
    )
    example_api = find("Example: Financial Accounting API:")
    set_phase_prose(
        example_api,
        "The evaluation API uses a multi-tier architecture comprising API, BAL/Services, MODEL/Entities, and Tests. It has role-based access control for Admin, FinanceManager, User, and Auditor roles, JWT authentication, and comprehensive audit logging.",
    )

    generated = find("Code recommendations are generated using ChatGPT")
    set_phase_prose(
        generated,
        "ChatGPT (Codex 5.4), accessed through OpenAI’s Codex coding environment, receives tool findings, relevant code snippets, and expected constraints before suggesting candidate fixes. Its guidance includes parameterized queries to prevent SQL injection, more efficient loops, and secure session management. A human reviewer applies each candidate on a dedicated branch, runs dotnet test, and measures it again with the same tool used at baseline. The recommendation is evaluated against its target metric and regression tests rather than accepted automatically.",
    )
    security = find("Example: Security Enhancement")
    set_phase_prose(
        security,
        "For the security example, write endpoints such as POST /journal-entries and POST /journal-entries/bulk must prevent untrusted input from changing database-query behavior or bypassing authorization. The candidate guidance preserves Entity Framework parameterization, validates DTO input, rejects unauthorized roles, and protects write operations with JWT authentication and role policies.",
    )
    performance = find("Example: Performance Optimization")
    set_phase_prose(
        performance,
        "For the performance example, slow p95 latency on GET /reports/trial-balance, GET /reports/profit-loss, GET /reports/balance-sheet, and GET /reports/account-ledger during soak and spike workloads motivates a caching proposal. The illustrative recommendation is to cache frequently requested report results in memory for ten minutes. Table 3.4 then records selected SonarQube code-quality remediation evidence.",
    )

    post_testing = find("With ChatGPT-guided changes implemented")
    set_phase_prose(
        post_testing,
        "After candidate changes are implemented on separate branches, the same tools and configurations are used for another round of testing. SonarQube rechecks code quality, OWASP ZAP repeats baseline and authenticated API scans across the endpoint groups on its remediation branch, and JMeter repeats the 50-, 100-, and 500-user load tests together with soak and spike profiles on its remediation branch. Security, performance, and code-quality measurements are then compared with the common baseline branch.",
    )
    comparison = find("The data collected from the baseline")
    set_phase_prose(
        comparison,
        "Finally, results from the common baseline branch are compared with the SonarQube, OWASP ZAP, and JMeter remediation branches to judge the effect of each ChatGPT-guided change. The comparison considers security findings, performance metrics, and code-quality outcomes, including acceptance targets that were not met. Appendices A–N provide the environment, exact branch and commit provenance, curated source-code listings, reproduction automation, dashboards, result traceability, and limitations in this full report.",
    )

    remove_targets = [
        find("Tools: SonarQube"),
        find("The API features role-based access control"),
        find("Example Guidance from ChatGPT:"),
        find("Baseline Issue: Security and validation risk"),
        find("ChatGPT Recommendation: preserve Entity Framework"),
        find("Baseline Issue: Slow p95 latency"),
        find("ChatGPT Recommendation: Implement caching"),
        find("Example Adjustment: Use in-memory caching"),
        find("Example: Security: Run ZAP"),
    ]
    for paragraph in remove_targets:
        remove_paragraph(paragraph)
    for paragraph in section:
        if is_empty_paragraph(paragraph):
            previous = paragraph._p.getprevious()
            following = paragraph._p.getnext()
            if previous is not None and following is not None:
                remove_paragraph(paragraph)


def smooth_phase_narrative_file(path: Path) -> None:
    doc = Document(path)
    smooth_phase_narrative(doc)
    report_formatter.enable_field_update_on_open(doc)
    doc.save(path)


def main() -> None:
    parser = argparse.ArgumentParser(description="Normalize tables, paragraph emphasis, and pagination in the full thesis report.")
    parser.add_argument("target", nargs="?", type=Path, default=DEFAULT_REPORT)
    parser.add_argument(
        "--appendices-only",
        action="store_true",
        help="Improve appendix flow and metadata alignment without rewriting the report body.",
    )
    parser.add_argument(
        "--examples-only",
        action="store_true",
        help="Tidy example labels and source-code evidence captions without rewriting other sections.",
    )
    parser.add_argument(
        "--phases-only",
        action="store_true",
        help="Convert Phase 1-4 methodology text into connected prose.",
    )
    args = parser.parse_args()
    target = args.target.resolve()
    if sum((args.appendices_only, args.examples_only, args.phases_only)) > 1:
        parser.error("Select only one targeted formatting mode.")
    if args.appendices_only:
        compact_appendices_file(target)
    elif args.examples_only:
        tidy_examples_and_evidence_file(target)
    elif args.phases_only:
        smooth_phase_narrative_file(target)
    else:
        normalize_report(target)
    print(target)


if __name__ == "__main__":
    main()
