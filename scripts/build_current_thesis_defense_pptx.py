from __future__ import annotations

import json
import re
from pathlib import Path

from PIL import Image
from docx import Document
from pptx import Presentation
from pptx.dml.color import RGBColor
from pptx.enum.shapes import MSO_CONNECTOR, MSO_SHAPE
from pptx.enum.text import MSO_ANCHOR, PP_ALIGN
from pptx.util import Inches, Pt


ROOT = Path(__file__).resolve().parents[1]
REPORT = ROOT / "Document" / "outputs" / "final-report-23SEPv2-1.docx"
OUTPUT = (
    ROOT
    / "Document"
    / "outputs"
    / "final-defense"
    / "G6519692_Zaw_Ye_Htut_Ko_Final_Thesis_Defense.pptx"
)
DASHBOARD_ROOT = ROOT / "docs" / "appendix" / "dashboards"
WEB_ROOT = ROOT / "Document" / "outputs" / "web-app-evidence"
MANIFEST = ROOT / "docs" / "appendix" / "dashboard-capture-manifest.json"
EVIDENCE_ROOT = ROOT / "docs" / "appendix" / "verification-runs" / "research"

W = 13.333
H = 7.5
FONT = "Arial"
CODE_FONT = "Courier New"
PROFILE_DISPLAY = {"p50": "50 VU", "p100": "100 VU", "p500": "500 VU"}
JMETER_REQUEST_ORDER = (
    "Total", "GET /accounts", "GET /journal-entries", "GET /periods",
    "GET /reports/account-ledger", "GET /reports/balance-sheet",
    "GET /reports/profit-loss", "GET /reports/trial-balance",
    "GET /users/me", "POST /auth/login", "POST /journal-entries/bulk",
)
INK = RGBColor(37, 43, 51)
MUTED = RGBColor(91, 104, 116)
LIGHT = RGBColor(247, 249, 252)
BORDER = RGBColor(216, 224, 233)
TEAL = RGBColor(15, 103, 109)
TEAL_LIGHT = RGBColor(231, 246, 246)
ORANGE = RGBColor(190, 116, 20)
ORANGE_LIGHT = RGBColor(255, 246, 231)
GREEN = RGBColor(36, 111, 70)
GREEN_LIGHT = RGBColor(232, 247, 238)
RED = RGBColor(179, 55, 61)
RED_LIGHT = RGBColor(253, 239, 240)
NAVY = RGBColor(36, 70, 108)
NAVY_LIGHT = RGBColor(235, 243, 251)
WHITE = RGBColor(255, 255, 255)

EVIDENCE_CUES: dict[int, tuple[str, str]] = {
    1: ("backup slide 27 (claim-to-evidence map)", "Appendix M"),
    2: ("next slides 3-7 (problem and method)", "Appendices A and M"),
    3: ("backup slides 29-31 (the three risks)", "Appendices E-G"),
    4: ("backup slides 29-31 (one answer per tool)", "Appendix M"),
    5: ("backup slides 34 and 42-44 (API behavior)", "Appendices B-D, H, and J"),
    6: ("backup slide 28 (branch details)", "Appendix A"),
    7: ("backup slides 28 and 32-33 (source and tests)", "Appendices A, E-G, I, and K"),
    8: ("next slide 9 (seed and run records)", "Appendix H; Tables 3.10-3.11"),
    9: ("backup slide 27 (evidence map)", "Appendix H"),
    10: ("backup slides 29-31 (results and rules)", "Appendices K and M"),
    11: ("slide 15; backup slides 32-33 (before/after code)", "Appendices E-G, I, and K"),
    12: ("slide 15; backup slides 32-33 (actual changes)", "Appendices E-G"),
    13: ("next slides 14-15 (scan and code proof)", "Appendices E and L"),
    14: ("next slide 15; backup slides 29 and 35-36", "Appendix L, Figures L.1-L.4"),
    15: ("backup slide 32 (larger S107 example)", "Appendix E, Listings E.1-E.2"),
    16: ("next slide 17 (fresh ZAP proof)", "Appendices F and M"),
    17: ("backup slide 30 (raw ZAP counts)", "Appendix F"),
    18: ("backup slides 31 and 37-41 (JMeter profiles)", "Appendices K and L"),
    19: ("next slides 20-21 (native 100/500 VU dashboards)", "Appendices G, K, L, and N"),
    20: ("backup slide 38 (larger 100 VU dashboard)", "Appendix L, Figures L.10 and L.15"),
    21: ("backup slide 39 (larger 500 VU dashboard)", "Appendix L, Figures L.11 and L.16"),
    22: ("backup slides 31 and 40-41 (soak and spike); per-request slides 46-47", "Appendix L, Figures L.12-L.13 and L.17-L.18"),
    23: ("backup slides 33 and 40-41 (mixed endpoint behavior); per-request slides 46-47", "Appendix G; Table 4.4"),
    24: ("backup slides 42-44 (browser views)", "Appendix J; Figures 4.2-4.7"),
    25: ("backup slides 29-31 (outcome details)", "Appendices M and N"),
    26: ("backup slide 27 (claim-to-evidence map)", "Appendix N"),
    27: ("backup slide 27 (where every claim is checked)", "Appendices A, M, and N"),
}


def shift_backup_references(value: str) -> str:
    """Account for the new main slide without changing appendix figure numbers."""
    pattern = r"(backup slides?\s+)(\d+(?:-\d+)?(?:\s*(?:,|and)\s*\d+(?:-\d+)?)*)"

    def replace(match: re.Match[str]) -> str:
        numbers = re.sub(r"\d+", lambda number: str(int(number.group()) + 1), match.group(2))
        return match.group(1) + numbers

    return re.sub(pattern, replace, value, flags=re.IGNORECASE)


def read_facts() -> dict:
    report = Document(REPORT)
    title = " ".join(report.paragraphs[1].text.split()).replace("\xa0", "")
    tables = report.tables
    sonar_rows = {row.cells[0].text.strip(): (row.cells[1].text.strip(), row.cells[2].text.strip()) for row in tables[21].rows[1:]}
    closure = {row.cells[0].text.strip(): row.cells[3].text.strip() for row in tables[24].rows[1:]}
    if sonar_rows["Total unique issues"] != ("17", "0") or "FAIL" not in closure["JMeter core profiles"]:
        raise RuntimeError("The current report does not match the expected fresh-result baseline.")

    sonar = {}
    zap = {}
    jmeter = {}
    for role in ("baseline", "remediation"):
        sonar[role] = json.loads((EVIDENCE_ROOT / "sonar" / role / "summary.json").read_text(encoding="utf-8-sig"))
        zap[role] = json.loads((EVIDENCE_ROOT / "zap" / role / "summary.json").read_text(encoding="utf-8-sig"))
        jmeter[role] = json.loads((EVIDENCE_ROOT / "jmeter" / role / "summary.json").read_text(encoding="utf-8-sig"))
    dataset = json.loads((EVIDENCE_ROOT / "branch-verification.json").read_text(encoding="utf-8-sig"))["dataset"]
    for role in ("baseline", "remediation"):
        if any(jmeter[role]["dataset"][key] != dataset[key] for key in ("accounts", "journalEntries", "postedEntries")):
            raise RuntimeError(f"JMeter {role} dataset counts disagree with branch verification.")
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8-sig"))
    captures = {capture["imagePath"]: capture for capture in manifest["captures"]}
    return {
        "title": title,
        "sonar": sonar,
        "zap": zap,
        "jmeter": jmeter,
        "dataset": dataset,
        "sonar_rows": sonar_rows,
        "closure": closure,
        "captures": captures,
    }


def box(slide, x, y, w, h, fill=WHITE, line=None, radius=False):
    shape = slide.shapes.add_shape(
        MSO_SHAPE.ROUNDED_RECTANGLE if radius else MSO_SHAPE.RECTANGLE,
        Inches(x), Inches(y), Inches(w), Inches(h),
    )
    shape.fill.solid()
    shape.fill.fore_color.rgb = fill
    if line is None:
        shape.line.fill.background()
    else:
        shape.line.color.rgb = line
        shape.line.width = Pt(1)
    return shape


def text(slide, value, x, y, w, h, size=20, color=INK, bold=False, align=PP_ALIGN.LEFT,
         font=FONT, margin=0.02, valign=MSO_ANCHOR.MIDDLE):
    shape = slide.shapes.add_textbox(Inches(x), Inches(y), Inches(w), Inches(h))
    frame = shape.text_frame
    frame.clear()
    frame.word_wrap = True
    frame.margin_left = frame.margin_right = Inches(margin)
    frame.margin_top = frame.margin_bottom = Inches(margin)
    frame.vertical_anchor = valign
    paragraph = frame.paragraphs[0]
    paragraph.alignment = align
    paragraph.space_before = paragraph.space_after = Pt(0)
    run = paragraph.add_run()
    run.text = str(value)
    run.font.name = font
    run.font.size = Pt(size)
    run.font.bold = bold
    run.font.color.rgb = color
    return shape


def line(slide, x1, y1, x2, y2, color=BORDER, width=1):
    shape = slide.shapes.add_connector(MSO_CONNECTOR.STRAIGHT, Inches(x1), Inches(y1), Inches(x2), Inches(y2))
    shape.line.color.rgb = color
    shape.line.width = Pt(width)
    return shape


def header(prs, section, title, source, accent=TEAL):
    slide = prs.slides.add_slide(prs.slide_layouts[6])
    slide.background.fill.solid()
    slide.background.fill.fore_color.rgb = LIGHT
    box(slide, 0, 0, 0.16, H, accent)
    text(slide, section.upper(), 0.64, 0.22, 11.9, 0.24, 11, accent, bold=True)
    text(slide, title, 0.64, 0.55, 12.0, 0.58, 29, INK, bold=True)
    line(slide, 0.64, 1.18, 12.67, 1.18)
    line(slide, 0.64, 7.03, 12.67, 7.03)
    text(slide, source, 0.64, 7.08, 11.4, 0.20, 10, MUTED)
    text(slide, len(prs.slides), 12.16, 7.08, 0.48, 0.20, 11, accent, bold=True, align=PP_ALIGN.RIGHT)
    return slide


def add_notes(slide, seconds, key, script, source, caution=""):
    slide.notes_slide.notes_text_frame.text = (
        f"TIMING: {seconds} seconds\nKEY MESSAGE: {key}\n\nSCRIPT:\n{script}\n\n"
        f"SOURCE: {source}"
        + (f"\nCAUTION: {caution}" if caution else "")
    )


def add_evidence_cues(prs: Presentation) -> None:
    if set(EVIDENCE_CUES) != set(range(1, 28)):
        raise RuntimeError("Every main slide needs an evidence cue.")
    for slide_number, (slides, appendix) in EVIDENCE_CUES.items():
        notes = prs.slides[slide_number - 1].notes_slide.notes_text_frame
        marker = "\n\nSCRIPT:\n"
        if marker not in notes.text:
            raise RuntimeError(f"Slide {slide_number} has no speaker script.")
        notes.text = notes.text.replace(
            marker,
            f"\nSHOW IF ASKED: {shift_backup_references(slides)}\nAPPENDIX: {appendix}{marker}",
            1,
        )


def image_contain(slide, path: Path, x, y, w, h, border=True, visible_top_px: int | None = None):
    with Image.open(path) as image:
        px_w, px_h = image.size
    shown_h = min(px_h, visible_top_px) if visible_top_px else px_h
    scale = min(w / px_w, h / shown_h)
    placed_w = px_w * scale
    placed_h = shown_h * scale
    placed_x = x + (w - placed_w) / 2
    placed_y = y + (h - placed_h) / 2
    picture = slide.shapes.add_picture(str(path), Inches(placed_x), Inches(placed_y), width=Inches(placed_w), height=Inches(placed_h))
    if shown_h < px_h:
        picture.crop_bottom = (px_h - shown_h) / px_h
    if border:
        frame = box(slide, placed_x, placed_y, placed_w, placed_h, fill=WHITE, line=BORDER)
        frame.fill.background()
    return (placed_x, placed_y, placed_w, placed_h)


def metric(slide, x, y, w, label, value, sub="", fill=WHITE, color=INK):
    box(slide, x, y, w, 1.22, fill, BORDER, radius=True)
    text(slide, label.upper(), x+0.18, y+0.12, w-0.36, 0.22, 11, MUTED, bold=True)
    text(slide, value, x+0.18, y+0.39, w-0.36, 0.45, 25, color, bold=True)
    if sub:
        text(slide, sub, x+0.18, y+0.93, w-0.36, 0.18, 11, MUTED)


def table(slide, rows, x, y, w, h, widths=None, font_size=15, header_fill=INK):
    grid = slide.shapes.add_table(len(rows), len(rows[0]), Inches(x), Inches(y), Inches(w), Inches(h)).table
    if widths:
        for column, fraction in zip(grid.columns, widths, strict=True):
            column.width = Inches(w * fraction)
    for row_index, values in enumerate(rows):
        for column_index, value in enumerate(values):
            cell = grid.cell(row_index, column_index)
            cell.text = str(value)
            cell.fill.solid()
            cell.fill.fore_color.rgb = header_fill if row_index == 0 else (WHITE if row_index % 2 else LIGHT)
            cell.margin_left = Inches(0.12)
            cell.margin_right = Inches(0.10)
            cell.margin_top = cell.margin_bottom = Inches(0.04)
            for paragraph in cell.text_frame.paragraphs:
                paragraph.alignment = PP_ALIGN.LEFT
                paragraph.space_after = Pt(0)
                for run in paragraph.runs:
                    run.font.name = FONT
                    run.font.size = Pt(font_size)
                    run.font.bold = row_index == 0
                    run.font.color.rgb = WHITE if row_index == 0 else INK
    return grid


def list_items(slide, items, x, y, w, row_h=0.68, size=19, accent=TEAL):
    for index, item in enumerate(items):
        top = y + index * row_h
        box(slide, x, top+0.12, 0.12, 0.12, accent, radius=True)
        text(slide, item, x+0.28, top, w-0.28, row_h-0.02, size, INK)


def source_line(slide, label, value, x, y, w, color=INK):
    text(slide, label, x, y, w, 0.28, 12, MUTED, bold=True)
    text(slide, value, x, y+0.27, w, 0.42, 18, color, bold=True)


def profile_map(summary):
    return {profile["profile"]: profile for profile in summary["profiles"]}


def percent_lower(before, after):
    return round((before - after) * 100.0 / before)


def core_jmeter_evidence_slide(prs: Presentation, profile: str, before: float, after: float,
                               limit: int, baseline_figure: int, after_figure: int) -> None:
    label = PROFILE_DISPLAY[profile]
    source = f"Appendix L Figures L.{baseline_figure} and L.{after_figure}; fresh JMeter summary.json"
    slide = header(prs, "Evidence", f"JMeter {label}: native dashboard proof", source, RED)
    text(slide, "BASELINE", 0.88, 1.39, 5.62, 0.34, 17, NAVY, bold=True)
    text(slide, "AFTER FIXES", 6.83, 1.39, 5.62, 0.34, 17, RED, bold=True)
    image_contain(slide, DASHBOARD_ROOT / "jmeter" / f"jmeter-baseline-{profile}-dashboard.png",
                  0.86, 1.83, 5.64, 3.94)
    image_contain(slide, DASHBOARD_ROOT / "jmeter" / f"jmeter-remediation-{profile}-dashboard.png",
                  6.82, 1.83, 5.64, 3.94)
    box(slide, 0.84, 5.98, 11.64, 0.70, RED_LIGHT, radius=True)
    text(slide, f"TOTAL row, 95th pct: {before:g} → {after:g} ms; study limit {limit:,} ms — target not met.",
         1.02, 6.05, 11.28, 0.49, 17, RED, bold=True)
    add_notes(slide, 40, f"At {label}, the after-fix p95 exceeded the study limit.",
              f"These are the native JMeter statistics views for {label}. Point to the Total row and the 95th-percentile column. "
              f"It changed from {before:g} to {after:g} milliseconds; the study limit was {limit:,} milliseconds. "
              "The screenshots show the measured time, while the test rule supplies the not-met judgment. "
              "They do not establish why the code ran slower.",
              f"{source}; Document/JMETER_ZAP_TEST_PLAN.md §4.6.")


def build_main_slides(prs: Presentation, facts: dict) -> int:
    sonar = facts["sonar"]
    zap = facts["zap"]
    jmeter = facts["jmeter"]
    baseline_profiles = profile_map(jmeter["baseline"])
    after_profiles = profile_map(jmeter["remediation"])

    # 1. Title
    slide = prs.slides.add_slide(prs.slide_layouts[6])
    slide.background.fill.solid()
    slide.background.fill.fore_color.rgb = LIGHT
    box(slide, 0, 0, 0.20, H, TEAL)
    text(slide, "FINAL THESIS DEFENSE", 0.72, 0.55, 11.8, 0.32, 15, TEAL, bold=True)
    text(slide, facts["title"], 0.72, 1.22, 11.78, 2.10, 31, INK, bold=True, valign=MSO_ANCHOR.TOP)
    line(slide, 0.72, 3.55, 12.52, 3.55, TEAL, 2)
    text(slide, "Zaw Ye Htut Ko  |  G6519692", 0.72, 3.93, 9.5, 0.45, 23, INK, bold=True)
    text(slide, "Master of Science in Information Technology  |  Assumption University", 0.72, 4.52, 11.3, 0.35, 18, MUTED)
    text(slide, "Advisor: Asst. Prof. Dr. Darun Kesrarat", 0.72, 5.05, 10.9, 0.34, 18, MUTED)
    box(slide, 0.72, 6.20, 11.78, 0.66, TEAL_LIGHT, radius=True)
    text(slide, "One existing API · one shared baseline · three independent measurements", 0.95, 6.30, 11.30, 0.43, 19, TEAL, bold=True)
    add_notes(slide, 45, "This is an evidence-based evaluation of ChatGPT as an advisor.",
              "Good morning. I evaluate whether ChatGPT can help improve an existing financial accounting API. The assistant suggests changes; I review and apply selected ones; SonarQube, OWASP ZAP, and JMeter show what the measured results support.",
              "Current full report title page and Abstract.")

    # 2. Opening question, with outcomes intentionally reserved for the results section.
    slide = header(prs, "Opening", "When is an AI suggestion an improvement?", "Current report §§1.1-1.5 and Chapter 3", TEAL)
    box(slide, 0.80, 1.55, 11.72, 1.70, WHITE, BORDER, radius=True)
    text(slide, "A plausible code change is not enough for a financial API.",
         1.13, 1.79, 11.08, 0.49, 27, INK, bold=True)
    text(slide, "The question is whether a reviewed ChatGPT suggestion survives functional and independent tool checks.",
         1.13, 2.47, 11.08, 0.49, 19, TEAL)
    opening_cards = [
        (0.80, "01", "Existing system", "One accounting API with real routes and roles", NAVY, NAVY_LIGHT),
        (4.78, "02", "Human review", "I accept or reject each proposed change", TEAL, TEAL_LIGHT),
        (8.76, "03", "Independent checks", "Tests, SonarQube, ZAP, and JMeter", GREEN, GREEN_LIGHT),
    ]
    for x, number, title, body, accent, fill in opening_cards:
        box(slide, x, 3.73, 3.76, 2.21, fill, BORDER, radius=True)
        text(slide, number, x+0.23, 4.01, 0.51, 0.35, 17, accent, bold=True)
        text(slide, title, x+0.23, 4.49, 3.28, 0.43, 22, accent, bold=True)
        text(slide, body, x+0.23, 5.10, 3.28, 0.61, 17, INK)
    text(slide, "The measurements—not the assistant's confidence—will answer the question.",
         0.86, 6.32, 11.60, 0.42, 19, TEAL, bold=True)
    add_notes(slide, 55, "The opening question is whether reviewed AI advice withstands measurement.",
              "Before I show any result, I want to define the question. ChatGPT can suggest a code change that looks reasonable, but that does not mean the accounting API is better. I use one existing API, review each candidate change myself, run functional tests, and compare independent tool measurements with a saved baseline. I will explain the problem and the method first, then let the results answer whether the suggestions helped.",
              "Current report §§1.1-1.5 and Chapter 3; next slides 3-7; Appendices A and M.")

    # 3. Practical problem
    slide = header(prs, "Problem", "One financial API has three different risks", "Current report §§1.1-1.4 and §3.1", NAVY)
    for x, title, body, color, pale in [
        (0.78, "Maintainability", "Code smells, complex controller signatures, and repeated logic", TEAL, TEAL_LIGHT),
        (4.78, "Security", "Headers, authorization boundaries, and scanner observations", RED, RED_LIGHT),
        (8.78, "Performance", "Tail latency, throughput, errors, and sustained load", ORANGE, ORANGE_LIGHT),
    ]:
        box(slide, x, 1.72, 3.78, 3.65, pale, BORDER, radius=True)
        box(slide, x, 1.72, 0.10, 3.65, color)
        text(slide, title, x+0.25, 2.10, 3.25, 0.50, 24, color, bold=True)
        text(slide, body, x+0.25, 2.94, 3.20, 1.72, 21, INK)
    text(slide, "No one scanner can stand in for all three dimensions.", 0.78, 5.84, 11.8, 0.55, 24, INK, bold=True)
    add_notes(slide, 60, "Code, security, and speed need different checks.",
              "A program can have confusing code, unsafe web settings, and slow requests at the same time. One tool cannot check all three. I used SonarQube to read code, ZAP to test the running API, and JMeter to send load. I also ran tests to check that accounting behavior still worked.",
              "Current report Chapter 1 and §3.1.")

    # 4. Research questions
    slide = header(prs, "Problem", "Three questions, three independent answers", "Current report §1.5 and Table 4.1", NAVY)
    questions = [
        ("RQ1", "Can static issues be closed without material control-metric regression?", TEAL),
        ("RQ2", "Can configured security alerts be cleared and residual raw alerts disclosed?", RED),
        ("RQ3", "Can latency targets pass under core load as well as stress profiles?", ORANGE),
    ]
    for i, (tag, question, color) in enumerate(questions):
        y = 1.54 + i*1.62
        box(slide, 0.80, y, 11.73, 1.33, WHITE, BORDER, radius=True)
        box(slide, 0.80, y, 1.30, 1.33, color)
        text(slide, tag, 0.96, y+0.40, 0.96, 0.44, 24, WHITE, bold=True, align=PP_ALIGN.CENTER)
        text(slide, question, 2.38, y+0.24, 9.80, 0.84, 22, INK)
    add_notes(slide, 65, "I ask one measurable question for each tool.",
              "First, did the code warnings decrease, and did coverage or complexity get worse? Second, did security alerts decrease, and what remained? Third, did the API stay within the response-time limits at the three different user counts? I answer each question with the tool's before-and-after result, not with an AI opinion.",
              "Current report §1.5 and Table 4.1.")

    # 5. Research design and assistant selection
    slide = header(prs, "Method", "An applied case study of one existing API", "Current report §§1.6 and 3.1-3.3; OpenAI adoption study", TEAL)
    research_cards = [
        (0.80, NAVY_LIGHT, NAVY, "WHAT I STUDIED", "Applied case study",
         "One ASP.NET Core financial API with accounts, journal entries, reports, and four user roles."),
        (4.78, TEAL_LIGHT, TEAL, "WHY THIS ASSISTANT", "Why ChatGPT?",
         "ChatGPT is widely used and recognizable. It is one case to study deeply—not uniquely capable of coding fixes."),
        (8.76, GREEN_LIGHT, GREEN, "HOW I JUDGED IT", "Measured comparison",
         "One baseline and isolated branches; tests, SonarQube, ZAP, and JMeter judge the changes."),
    ]
    for x, fill, accent, tag, title, body in research_cards:
        box(slide, x, 1.62, 3.76, 3.93, fill, BORDER, radius=True)
        text(slide, tag, x+0.22, 1.90, 3.30, 0.28, 14, accent, bold=True)
        text(slide, title, x+0.22, 2.42, 3.30, 0.58, 24, accent, bold=True)
        text(slide, body, x+0.22, 3.22, 3.30, 1.91, 20, INK)
    box(slide, 0.84, 5.88, 11.64, 0.75, WHITE, BORDER, radius=True)
    text(slide, "Contribution: evidence-backed AI-assisted remediation—not a new algorithm, matrix, or model comparison.",
         1.06, 6.04, 11.20, 0.42, 18, TEAL, bold=True)
    add_notes(slide, 75, "This is an applied single-case evaluation, not a new algorithm.",
              "This is applied research: I study one existing financial accounting API and ask what happens when ChatGPT helps me address measured problems. I am not inventing a new algorithm or a scoring matrix. Why ChatGPT rather than Claude or Copilot? ChatGPT is widely used and recognizable, making it a relevant case to examine. Claude and Copilot can also analyze code and suggest changes. I held ChatGPT fixed as the one assistant so I could trace findings, suggestions, my review, and independent results in depth. I am not comparing AI assistants, and I cannot claim ChatGPT is better or uniquely capable. I also would not call it the first AI coding tool. I review the proposed edits; tests and the three independent tools judge the outcomes.",
              "Current report §§1.6 and 3.1-3.3, Table 3.3 and §3.6; OpenAI adoption study: https://openai.com/business/guides-and-resources/chatgpt-usage-and-adoption-patterns-at-work/ ; Claude Code overview: https://code.claude.com/docs/en/overview ; GitHub Copilot GA: https://github.blog/news-insights/product-news/github-copilot-is-generally-available-to-all-developers/ .")

    # 6. Branch isolation
    slide = header(prs, "Method", "Every remediation branch starts from one baseline", "Current report Table 3.1 and Appendix A", TEAL)
    metric(slide, 4.65, 1.45, 4.03, "Common starting point", "baseline-v0.1", "Code before the changes", NAVY_LIGHT, NAVY)
    paths = [
        ("SonarQube", "baseline-sonarqube-v1", TEAL, 0.80),
        ("OWASP ZAP", "baseline-zap-v1", RED, 4.78),
        ("JMeter", "baseline-jmeter-v1", ORANGE, 8.76),
    ]
    for label, branch, color, x in paths:
        line(slide, 6.67, 2.68, x+1.90, 3.30, color, 2)
        box(slide, x, 3.34, 3.80, 2.10, WHITE, BORDER, radius=True)
        box(slide, x, 3.34, 0.10, 2.10, color)
        text(slide, label, x+0.22, 3.63, 3.32, 0.42, 22, color, bold=True)
        text(slide, branch, x+0.22, 4.18, 3.32, 0.38, 16, INK, bold=True)
        text(slide, "Compared with the same baseline", x+0.22, 4.74, 3.32, 0.28, 13, MUTED)
    text(slide, "Compare each changed branch with the same starting code—one tool at a time.", 0.80, 5.96, 11.8, 0.50, 19, INK)
    add_notes(slide, 70, "Each tool's change has its own branch.",
              "I used one saved baseline version as the starting point. I put the code-quality, security, and performance changes on separate branches. That lets me compare each changed version with the same starting code, one tool at a time. The exact technical references are available in Appendix A if the committee wants them.",
              "Current report Appendix A and Table 3.1.")

    # 7. Workflow
    slide = header(prs, "Method", "Four phases turn suggestions into evidence", "Current report §3.1.1; Figures 3.1-3.4", TEAL)
    phases = [
        ("01", "Capture baseline", "Freeze code, dataset, and raw tool output"),
        ("02", "Propose bounded fix", "Give ChatGPT the finding, source context, and constraints"),
        ("03", "Review and re-test", "I review, run tests, and rerun the same tool"),
        ("04", "Compare and report", "Apply gates; disclose residuals and unmet targets"),
    ]
    for i, (number, title, body) in enumerate(phases):
        x = 0.76 + i*3.13
        box(slide, x, 1.83, 2.91, 3.65, WHITE, BORDER, radius=True)
        text(slide, number, x+0.20, 2.08, 0.80, 0.57, 30, TEAL, bold=True)
        text(slide, title, x+0.20, 2.91, 2.48, 0.70, 20, INK, bold=True)
        text(slide, body, x+0.20, 3.88, 2.48, 1.16, 17, MUTED)
    text(slide, "The model does not approve its own output.", 0.78, 5.98, 11.8, 0.50, 23, TEAL, bold=True)
    add_notes(slide, 70, "A suggestion must be checked before it becomes a result.",
              "First I saved the baseline result. Next I gave ChatGPT a specific tool warning and the relevant code. Then I reviewed the suggested edit, ran tests, and ran the same tool again. Finally I compared the new number with the baseline and the study rule. A patch that looks good is not automatically a success.",
              "Current report §3.1.1 and Figures 3.1-3.4.")

    # 8. Dataset and environment
    slide = header(prs, "Method", "One local setup and a seeded dataset", "Current report Tables 3.2 and 3.11; Appendix H", TEAL)
    metric(slide, 0.78, 1.58, 3.77, "Accounts", str(facts["dataset"]["accounts"]), "Seeded count in run record", NAVY_LIGHT, NAVY)
    metric(slide, 4.78, 1.58, 3.77, "Journal entries", f"{facts['dataset']['journalEntries']:,}", f"At least {facts['dataset']['postedEntries']:,} posted", NAVY_LIGHT, NAVY)
    metric(slide, 8.78, 1.58, 3.77, "Test host", "Local ", ".NET 8 · local SQL Server", NAVY_LIGHT, NAVY)
    for shape in slide.shapes:
        if shape.has_text_frame and shape.text == "Local ":
            shape.top = 1796281
            shape.height = 421654
            break
    box(slide, 0.78, 3.27, 11.77, 2.45, WHITE, BORDER, radius=True)
    text(slide, "Tool versions in the fresh reproduction", 1.06, 3.57, 11.05, 0.42, 21, TEAL, bold=True)
    text(slide, "SonarQube 26.7     |     OWASP ZAP 2.17     |     Apache JMeter 5.5", 1.06, 4.22, 11.04, 0.60, 24, INK, bold=True)
    text(slide, "The next slide shows the seed settings and recorded counts (Appendix H).", 1.06, 5.03, 11.04, 0.35, 17, MUTED)
    add_notes(slide, 60, "The 120 accounts are seeded test data, not customer records.",
              "The test scripts created 120 accounts and 30,000 journal entries. At least 5,000 entries were posted, so the report endpoints had data to process. This is not a screenshot of 120 individual accounts: the count is recorded in the run record. We used one local computer and one fresh run per branch, so the result is limited to this setup.",
              "Next slide 9; branch-verification.json dataset counts; current report Tables 3.10-3.11 and Appendix H.")

    # 9. Dataset proof immediately after the dataset claim.
    slide = header(prs, "Evidence", "Where the 120-account count comes from", "Appendix H; Tables 3.10-3.11; branch-verification.json", TEAL)
    box(slide, 0.80, 1.58, 5.65, 4.60, WHITE, BORDER, radius=True)
    box(slide, 6.84, 1.58, 5.65, 4.60, WHITE, BORDER, radius=True)
    text(slide, "Seed script settings", 1.08, 1.91, 5.10, 0.40, 21, TEAL, bold=True)
    text(slide, "scripts/phase4/seed-test-data.ps1", 1.08, 2.42, 5.10, 0.42, 15, MUTED, font=CODE_FONT)
    text(slide, "AccountCount = 120\nJournalEntryCount = 30000\nMinimumPostedEntries = 5000",
         1.08, 3.05, 5.08, 2.13, 19, INK, font=CODE_FONT, valign=MSO_ANCHOR.TOP)
    text(slide, "Recorded in the run", 7.12, 1.91, 5.10, 0.40, 21, TEAL, bold=True)
    text(slide, "docs/appendix/verification-runs/research/branch-verification.json", 7.12, 2.42, 5.10, 0.70, 13, MUTED, font=CODE_FONT)
    text(slide, f"accounts: {facts['dataset']['accounts']}\njournalEntries: {facts['dataset']['journalEntries']:,}\npostedEntries: {facts['dataset']['postedEntries']:,}",
         7.12, 3.15, 5.08, 2.03, 19, INK, font=CODE_FONT, valign=MSO_ANCHOR.TOP)
    add_notes(slide, 40, "The seed settings and the run record agree on the dataset size.",
              "I used the repository seed script to request 120 accounts, 30,000 journal entries, and at least 5,000 posted entries. The run record on the right reports those same counts. I omit the local demo credential from this excerpt. Appendix H has the fuller seed explanation.",
              "Appendix H; current report Tables 3.10-3.11; branch-verification.json and scripts/phase4/seed-test-data.ps1.")

    # 9. Acceptance rules
    slide = header(prs, "Method", "Outcomes were judged by tool-specific measures", "Current report Table 4.1 and §4.1", TEAL)
    table(slide, [
        ["Area", "Primary decision", "Control metric"],
        ["SonarQube", "Compare unique issues; show gate status", "Coverage and complexity disclosed"],
        ["OWASP ZAP", "Configured-rule gate; report raw alerts", "Residual HTTP-only observation disclosed"],
        ["JMeter", "50/100/500 VU core gate", "100 VU ≤500 ms; 500 VU ≤1200 ms"],
        ["Regression", "Focused tests and role checks", "Accounting and authorization preserved"],
    ], 0.80, 1.58, 11.72, 3.80, widths=[0.21,0.45,0.34], font_size=17)
    box(slide, 0.80, 5.62, 11.72, 0.96, ORANGE_LIGHT, radius=True)
    text(slide, "Study scenarios: 100 VU = planned peak; 500 VU = heavier load. These are not measured production traffic.",
         1.04, 5.76, 11.18, 0.70, 18, ORANGE, bold=True)
    add_notes(slide, 70, "Each tool has a rule, but the measured numbers still matter.",
              "I named 100 simulated users the peak scenario and 500 the heavier-load scenario in the test plan. This was not a measured peak from real customers. The study set p95 targets of 500 milliseconds and 1,200 milliseconds respectively. Those numbers are study choices, not universal standards. I compare the after-fix result with each target and still report the actual time, so the committee can see more than a pass/fail label.",
              "Current report Table 4.1 and §4.1; Document/JMETER_ZAP_TEST_PLAN.md §4.6.")

    # 10. Human-in-the-loop boundary
    slide = header(prs, "Method", "From a tool warning to a measured result", "Current report §§3.1.3-3.1.4; Appendices I and K", TEAL)
    diagram_columns = [
        (0.80, TEAL_LIGHT, TEAL, "01  INPUT", "Start with evidence",
         "Tool finding + relevant code", "Example: SonarQube flags eight controller parameters."),
        (4.79, NAVY_LIGHT, NAVY, "02  HUMAN DECISION", "Review the proposed fix",
         "ChatGPT suggests; I decide.", "I check correctness, accounting behavior, and access control."),
        (8.78, GREEN_LIGHT, GREEN, "03  INDEPENDENT CHECK", "Verify the outcome",
         "Run tests; rerun the same tool.", "Compare with the saved baseline and the study target."),
    ]
    for x, fill, accent, step, title, method, explanation in diagram_columns:
        box(slide, x, 1.74, 3.75, 3.14, fill, BORDER, radius=True)
        text(slide, step, x+0.20, 1.98, 3.33, 0.28, 14, accent, bold=True)
        text(slide, title, x+0.20, 2.41, 3.33, 0.76, 21, accent, bold=True)
        text(slide, method, x+0.20, 3.21, 3.33, 0.50, 17, INK, bold=True)
        text(slide, explanation, x+0.20, 3.86, 3.33, 0.72, 16, INK)
    text(slide, "→", 4.56, 3.05, 0.22, 0.42, 26, MUTED, bold=True)
    text(slide, "→", 8.55, 3.05, 0.22, 0.42, 26, MUTED, bold=True)
    box(slide, 0.84, 5.16, 11.64, 0.68, WHITE, BORDER, radius=True)
    text(slide, "Concrete result: request DTO adopted; SonarQube unique issues 17 → 0.",
         1.12, 5.30, 11.08, 0.38, 19, TEAL, bold=True)
    box(slide, 0.84, 6.01, 11.64, 0.67, ORANGE_LIGHT, radius=True)
    text(slide, "An AI proposal is not proof: the JMeter branch did not meet its main speed target.",
         1.12, 6.15, 11.08, 0.37, 18, ORANGE, bold=True)
    add_notes(slide, 80, "A proposal passes through my review and independent measurement.",
              "Read this diagram from left to right. On the left, I start with a real tool finding and the source code needed to understand it. For example, SonarQube flagged eight controller parameters. In the middle, ChatGPT proposes a change, but it does not decide whether that change is correct. I reviewed the request DTO for accounting behavior and access control before using it. On the right, I run focused tests and rerun the same tool on the changed branch. I compare that result with the saved baseline and the study target. SonarQube's unique issue count went from 17 to zero; JMeter did not meet its main speed target. The arrows represent checks, not automatic acceptance of an AI suggestion.",
              "Current report §§3.1.3-3.1.4, Appendices I and K.")

    # 11. What changed in code
    slide = header(prs, "Method", "The three branches changed different code", "Current report Table 4.3; Appendices E-G", TEAL)
    table(slide, [
        ["Track", "Representative change", "What it was meant to address"],
        ["SonarQube", "Eight query parameters → JournalEntryQueryDto", "Controller maintainability finding S107"],
        ["ZAP", "SecurityHeadersMiddleware before Swagger", "Browser-facing security headers"],
        ["JMeter", "Cache ledger data; avoid repeated report snapshot writes", "Reduce repeated report and database work"],
    ], 0.80, 1.65, 11.72, 3.58, widths=[0.20,0.43,0.37], font_size=18)
    text(slide, "Mechanism and measured outcome are shown separately on the next slides.", 0.83, 5.65, 11.72, 0.50, 20, TEAL, bold=True)
    add_notes(slide, 70, "The three branches changed different parts of the API.",
              "For code quality, I replaced eight controller parameters with one request object. For security, I put security headers before Swagger. For performance, I added ledger caching and stopped saving a new report snapshot on that read path. These are the code changes I made; the next slides show whether the measurements improved.",
              "Current report Table 4.3 and Appendices E-G.")

    # 12. SonarQube result: foreground the change, show the controls without calling zeros gains.
    slide = header(prs, "Results", "SonarQube: 17 findings closed", "Current report §4.2; Table 4.2; Figures L.1-L.4", GREEN)
    box(slide, 0.80, 1.55, 5.47, 4.65, GREEN_LIGHT, BORDER, radius=True)
    text(slide, "PRIMARY OUTCOME", 1.12, 1.88, 4.83, 0.32, 16, GREEN, bold=True)
    text(slide, "17 → 0", 1.10, 2.42, 4.85, 1.01, 53, GREEN, bold=True)
    text(slide, "unique SonarQube issues", 1.12, 3.51, 4.77, 0.46, 24, GREEN, bold=True)
    text(slide, "All 17 baseline issues were legacy Code Smells.", 1.12, 4.30, 4.73, 0.68, 19, INK)
    text(slide, "Example fix: eight controller parameters → one request DTO.",
         1.12, 5.20, 4.73, 0.75, 18, INK)
    box(slide, 6.52, 1.55, 6.00, 4.65, WHITE, BORDER, radius=True)
    text(slide, "CONTROLS MONITORED", 6.82, 1.88, 5.37, 0.34, 16, TEAL, bold=True)
    control_rows = [
        "Coverage 74.4% → 74.3% (−0.1 pp)",
        "Bugs / Vulnerabilities 0 / 0 → 0 / 0",
        "Duplicate density 0.0% → 0.0%",
        "Quality Gate OK → OK",
        "Complexity 886 → 889",
    ]
    for i, row in enumerate(control_rows):
        y = 2.42 + i * 0.72
        text(slide, row, 6.82, y, 5.36, 0.43, 18, INK)
        if i < len(control_rows)-1:
            line(slide, 6.82, y+0.58, 12.18, y+0.58, BORDER, 1)
    box(slide, 0.84, 6.37, 11.64, 0.49, GREEN_LIGHT, radius=True)
    text(slide, "The targeted gain is issue closure; adjacent quality measures stayed close to baseline.",
         1.07, 6.43, 11.18, 0.35, 17, GREEN, bold=True)
    add_notes(slide, 85, "The targeted 17 findings were resolved; other metrics are controls, not improvements.",
              "The main result is 17 distinct SonarQube issues in the baseline and zero after the reviewed fixes. In the legacy issue-type field, all 17 were classified as code smells. I ran tests and repeated the scan on the isolated code-quality branch. The right-hand metrics are controls, not gains: coverage stayed close to baseline at 74.4 versus 74.3 percent; legacy Bugs and Vulnerabilities stayed at zero; duplicated-line density stayed at 0.0 percent; the Quality Gate stayed OK; and complexity rose slightly from 886 to 889. This supports targeted maintainability remediation with adjacent measures monitored. I do not claim the zero Bug or Vulnerability count proves the running API is secure—that is why I test security separately with ZAP. Cyclomatic complexity roughly counts decision paths through code. If asked why newer Reliability and Security impacts appeared, those labels overlap on the same legacy code-smell issues. The saved coverage summary lacks the underlying counts, so I cannot identify the exact cause of the 0.1 percentage-point change.",
              "Next slides 14-15; backup slides 29 and 35-36; SonarQube issues.json, measures.json and quality-gate.json; current report Table 4.2, Appendices E and L.",
              "Do not call the baseline zeros an improvement or treat Quality Gate OK/OK as evidence of issue closure; its captured condition list is empty.")

    # 13. Native Sonar evidence
    slide = header(prs, "Evidence", "The SonarQube dashboards confirm 17 → 0", "Current capture · Appendix L, Figures L.1 and L.3", GREEN)
    text(slide, "Baseline · commit 7a0469d9", 0.88, 1.42, 5.62, 0.38, 17, NAVY, bold=True)
    text(slide, "Remediation · commit a2279bcb", 6.82, 1.42, 5.62, 0.38, 17, GREEN, bold=True)
    image_contain(slide, DASHBOARD_ROOT / "sonarqube" / "sonarqube-baseline-overview.png", 0.86, 1.88, 5.63, 3.85)
    image_contain(slide, DASHBOARD_ROOT / "sonarqube" / "sonarqube-remediation-overview.png", 6.82, 1.88, 5.63, 3.85)
    box(slide, 0.84, 5.92, 11.64, 0.75, GREEN_LIGHT, radius=True)
    text(slide, "17 unique issues → 0; Quality Gate remained OK on both branches.",
         1.07, 6.01, 11.19, 0.55, 16, GREEN, bold=True)
    add_notes(slide, 60, "The saved dashboard views corroborate the issue-count change.",
              "I now point to the two actual SonarQube dashboard captures. The baseline scan reports 17 unique issues; the code-quality branch reports zero. The Quality Gate reads OK in both, so I use the issue count—not a change in gate status—as the evidence of remediation. Slide 15 shows representative source-code changes behind this result, and Appendix L has larger dashboard views.",
              "Next slide 15; backup slides 29 and 35-36; Appendix L Figures L.1-L.4; sonar/baseline and remediation issues.json and quality-gate.json.",
              "The saved Quality Gate responses contain no conditions; do not describe this as a failed-to-passed gate.")

    # 15. Representative SonarQube source changes, shown immediately after the scan evidence.
    slide = header(prs, "Evidence", "Two SonarQube fixes in source code", "Appendix E, Listings E.1-E.2", GREEN)
    box(slide, 0.80, 1.54, 5.70, 4.89, WHITE, BORDER, radius=True)
    box(slide, 6.82, 1.54, 5.70, 4.89, WHITE, BORDER, radius=True)
    text(slide, "BEFORE · shared baseline", 1.05, 1.82, 5.14, 0.38, 18, RED, bold=True)
    text(slide, "AFTER · SonarQube branch", 7.07, 1.82, 5.14, 0.38, 18, GREEN, bold=True)
    text(slide, "S107: eight query inputs", 1.05, 2.38, 5.14, 0.34, 16, MUTED, bold=True)
    text(slide, "S107: one query DTO", 7.07, 2.38, 5.14, 0.34, 16, MUTED, bold=True)
    text(slide, "GetPaged(\n  from, to, status, accountId,\n  search, page, pageSize, sort\n)",
         1.05, 2.86, 5.13, 1.72, 17, INK, font=CODE_FONT, valign=MSO_ANCHOR.TOP)
    text(slide, "GetPaged(\n  JournalEntryQueryDto query\n)",
         7.07, 2.86, 5.13, 1.72, 17, INK, font=CODE_FONT, valign=MSO_ANCHOR.TOP)
    text(slide, "S6966: host startup", 1.05, 4.86, 5.14, 0.31, 16, MUTED, bold=True)
    text(slide, "S6966: async host startup", 7.07, 4.86, 5.14, 0.31, 16, MUTED, bold=True)
    text(slide, "app.Run();", 1.05, 5.34, 5.13, 0.55, 20, INK, font=CODE_FONT)
    text(slide, "await app.RunAsync();", 7.07, 5.34, 5.13, 0.55, 20, INK, font=CODE_FONT)
    text(slide, "These are representative changes, not all 17 issue fixes; the full excerpts are in Appendix E.",
         0.84, 6.48, 11.70, 0.38, 15, GREEN, bold=True)
    add_notes(slide, 45, "These two code excerpts show what changed, but they do not stand for all 17 issues.",
              "Here are two representative before-and-after changes I reviewed. The S107 controller action passed eight query values separately; after the change it accepts one query object. The S6966 startup call changed from app.Run to await app.RunAsync. Appendix E shows fuller excerpts. The SonarQube issue lists on the preceding slide and in backup show the measured 17-to-zero result.",
              "Appendix E Listings E.1-E.2; backup slide 32 for the larger S107 example; Appendix L Figures L.2 and L.4 for the issue lists.")

    # 16-17. Screenshots rendered from the current raw ZAP reports.
    passive_before = next(x for x in zap["baseline"]["scans"] if x["scan"] == "baseline")
    passive_after = next(x for x in zap["remediation"]["scans"] if x["scan"] == "baseline")
    api_before = next(x for x in zap["baseline"]["scans"] if x["scan"] == "api")
    api_after = next(x for x in zap["remediation"]["scans"] if x["scan"] == "api")
    slide = header(prs, "Results", "ZAP passive alerts cleared; raw API Medium remains", "Current report §4.3; ZAP raw scan JSON; Appendix F", RED)
    text(slide, "PASSIVE SCAN · BASELINE", 0.83, 1.42, 11.70, 0.29, 17, NAVY, bold=True)
    image_contain(slide, DASHBOARD_ROOT / "zap/zap-fresh-passive-before-summary.png", 0.84, 1.79, 11.64, 0.88)
    text(slide, "PASSIVE SCAN · AFTER FIXES", 0.83, 2.96, 11.70, 0.29, 17, GREEN, bold=True)
    image_contain(slide, DASHBOARD_ROOT / "zap/zap-fresh-passive-after-summary.png", 0.84, 3.32, 11.64, 0.88)
    text(slide, "Severity-card screenshots rendered from the current ZAP scan JSON.",
         0.84, 4.37, 11.64, 0.36, 15, MUTED)
    box(slide, 0.84, 4.93, 11.64, 1.54, GREEN_LIGHT, radius=True)
    text(slide, f"Medium {passive_before['medium']} → {passive_after['medium']}    |    Low {passive_before['low']} → {passive_after['low']}",
         1.10, 5.14, 11.12, 0.48, 27, GREEN, bold=True)
    text(slide, "This scan observes ordinary responses and headers. The signed-in API scan follows on slide 17.",
         1.10, 5.84, 11.08, 0.40, 17, INK)
    add_notes(slide, 55, "The passive scan improved, but it is only one view of security.",
              "I am showing the passive scan before and after the changes. This scan observes normal responses and their headers; it does not sign in. In the upper screenshot, ZAP reports three Medium and six Low alert types. In the lower screenshot, both counts are zero. These are screenshots of report cards rendered from my current raw ZAP scan data. They are not a claim that the protected API is free of alerts. I will show that separate scan on the next slide.",
              "Next slide 17; backup slide 30; current report §4.3; Appendix F; fresh passive raw ZAP JSON and summaries.")

    slide = header(prs, "Evidence", "Signed-in API scan: Low cleared; one Medium remains", "Current report §4.3; ZAP raw scan JSON and alert 10106; Appendix F", RED)
    text(slide, "AUTHENTICATED API SCAN · BASELINE", 0.83, 1.42, 11.70, 0.29, 17, NAVY, bold=True)
    image_contain(slide, DASHBOARD_ROOT / "zap/zap-fresh-api-before-summary.png", 0.84, 1.79, 11.64, 0.88)
    text(slide, "AUTHENTICATED API SCAN · AFTER FIXES", 0.83, 2.96, 11.70, 0.29, 17, ORANGE, bold=True)
    image_contain(slide, DASHBOARD_ROOT / "zap/zap-fresh-api-after-summary.png", 0.84, 3.32, 11.64, 0.88)
    text(slide, "Severity-card screenshots rendered from the current ZAP scan JSON.",
         0.84, 4.37, 11.64, 0.36, 15, MUTED)
    box(slide, 0.84, 4.93, 11.64, 1.54, ORANGE_LIGHT, radius=True)
    text(slide, f"Medium {api_before['medium']} → {api_after['medium']}    |    Low {api_before['low']} → {api_after['low']}",
         1.10, 5.14, 11.12, 0.48, 27, ORANGE, bold=True)
    text(slide, "Remaining Medium: HTTP Only Site. Configured rules passed; HTTPS needs a separate retest.",
         1.10, 5.84, 11.08, 0.40, 17, INK)
    add_notes(slide, 65, "The signed-in scan improved, but it did not clear every raw alert.",
              "I am showing the signed-in API scan before and after the changes. Unlike the passive scan, this test signs in and exercises protected routes. Low alert types fell from three to zero, while Medium stayed at one. The remaining alert is called HTTP Only Site: my local scan target was served over HTTP. The selected security rules passed, but that pass result is different from saying every raw alert disappeared. I would need a working HTTPS endpoint and another scan before calling this Medium alert cleared. These screenshots were rendered from the current raw ZAP scan data; the raw counts and the alert are in Appendix F.",
              "Backup slide 30; current report §4.3; Appendix F and Appendix M; fresh API raw ZAP JSON, summaries, alert 10106.")

    # 16. JMeter workload definitions
    slide = header(prs, "Results", "JMeter tested three user counts, plus soak and spike", "Current report §§3.8 and 4.4; Appendix K", ORANGE)
    for i, (label, value, detail) in enumerate([
        ("50 VU", "50 users", "Normal scenario"), ("100 VU", "100 users", "Planned peak scenario"),
        ("500 VU", "500 users", "Heavier-load scenario"), ("soak", "steady", "Long-running test"),
        ("spike", "burst", "Sudden-load test"),
    ]):
        x = 0.78 + i*2.49
        box(slide, x, 2.00, 2.30, 2.57, WHITE, BORDER, radius=True)
        text(slide, label.upper(), x+0.18, 2.27, 1.94, 0.45, 25, ORANGE, bold=True, align=PP_ALIGN.CENTER)
        text(slide, value, x+0.18, 3.04, 1.94, 0.45, 20, INK, bold=True, align=PP_ALIGN.CENTER)
        text(slide, detail, x+0.16, 3.79, 1.98, 0.48, 14, MUTED, align=PP_ALIGN.CENTER)
    text(slide, "VU means simulated users; p95 is the time within which 95% of requests finish.", 0.82, 5.35, 11.78, 0.65, 22, ORANGE, bold=True)
    add_notes(slide, 60, "User count and response-time percentile are different things.",
              "VU means simulated users. The 50, 100, and 500 VU tests use different user counts; 100 VU is only the planned peak scenario, not a measured customer peak. Soak keeps traffic going for a long time. Spike sends a sudden burst. p95 is a time in milliseconds: 95 percent of requests finish at or below it. Soak and spike are extra tests; they do not replace the three core user-count checks.",
              "Current report §§3.8 and 4.4, Appendix K.")

    # 17. JMeter core target not met
    slide = header(prs, "Results", "Core performance target was not met", "Current report §4.4; Table 4.5; fresh JMeter summary.json", RED)
    rows = [["Profile", "Baseline p95", "After p95", "Fresh judgment"]]
    for profile in ("p50", "p100", "p500"):
        before = baseline_profiles[profile]["p95Ms"]
        after = after_profiles[profile]["p95Ms"]
        rows.append([PROFILE_DISPLAY[profile], f"{before:g} ms", f"{after:g} ms", "Slower after fixes"])
    table(slide, rows, 0.80, 1.55, 11.72, 3.40, widths=[0.19,0.24,0.24,0.33], font_size=20)
    box(slide, 0.80, 5.26, 11.72, 1.07, RED_LIGHT, radius=True)
    text(slide, "NOT MET: 100 VU 1,146.9 > 500 ms; 500 VU 1,547.95 > 1,200 ms", 1.04, 5.43, 11.21, 0.67, 24, RED, bold=True)
    text(slide, "Fixes: cache ledger data; avoid report snapshot writes. Exact cause of slowdown not isolated.",
         1.04, 6.38, 11.15, 0.51, 16, MUTED)
    add_notes(slide, 90, "The code changes did not meet the core speed target; the precise cause is unknown.",
              "The performance branch cached account-ledger data and stopped saving a new report snapshot on that read path. These changes were intended to reduce repeated work. JMeter measured response times, throughput, and errors. At 100 and 500 simulated users, the p95 response times were higher after the change and exceeded our study limits. CPU, memory, database-query, and cache-hit measurements were outside this study's measured scope, so I can report the slowdown but cannot identify one cause for it.",
              "Next slides 20-21 for native JMeter proof; backup slide 33 and Appendix G for the code; Appendix N for the measurement limits.",
              "Do not say caching or the host caused the slowdown; the evidence does not isolate either cause.")

    # 20-21. Show each failed core profile in the native JMeter view immediately after the conclusion.
    core_jmeter_evidence_slide(prs, "p100", baseline_profiles["p100"]["p95Ms"],
                               after_profiles["p100"]["p95Ms"], 500, 10, 15)
    core_jmeter_evidence_slide(prs, "p500", baseline_profiles["p500"]["p95Ms"],
                               after_profiles["p500"]["p95Ms"], 1200, 11, 16)

    # 18. Stress-profile improvements
    soak_before, soak_after = baseline_profiles["soak"], after_profiles["soak"]
    spike_before, spike_after = baseline_profiles["spike"], after_profiles["spike"]
    slide = header(prs, "Results", "Pooled soak/spike p95 fell; core p95 rose", "Current report §4.4; fresh JMeter summaries and request statistics", ORANGE)
    box(slide, 0.80, 1.70, 5.66, 3.72, ORANGE_LIGHT, BORDER, radius=True)
    text(slide, "SOAK TOTAL p95", 1.10, 2.04, 5.06, 0.32, 16, ORANGE, bold=True)
    text(slide, f"{soak_before['p95Ms']:g} → {soak_after['p95Ms']:g} ms", 1.10, 2.68, 5.05, 0.62, 30, ORANGE, bold=True)
    text(slide, f"{percent_lower(soak_before['p95Ms'],soak_after['p95Ms'])}% lower on the fresh run", 1.10, 3.65, 5.05, 0.52, 21, INK)
    text(slide, "p99 lower; average time and throughput worse", 1.10, 4.44, 5.05, 0.67, 16, MUTED)
    box(slide, 6.84, 1.70, 5.66, 3.72, GREEN_LIGHT, BORDER, radius=True)
    text(slide, "SPIKE TOTAL p95", 7.14, 2.04, 5.05, 0.32, 16, GREEN, bold=True)
    text(slide, f"{spike_before['p95Ms']:,.0f} → {spike_after['p95Ms']:,.0f} ms", 7.14, 2.68, 5.05, 0.62, 29, GREEN, bold=True)
    text(slide, f"{percent_lower(spike_before['p95Ms'],spike_after['p95Ms'])}% lower; errors {spike_before['errorPct']}% → {spike_after['errorPct']}%", 7.14, 3.65, 5.05, 0.52, 19, INK)
    text(slide, "p99 and average time lower; throughput higher", 7.14, 4.44, 5.05, 0.67, 16, MUTED)
    text(slide, "Core 50, 100, and 500 VU p95 all worsened; these separate gains do not reverse that result.",
         0.84, 5.79, 11.70, 0.63, 19, RED, bold=True)
    text(slide, "Soak: 9 of 10 request p95 values higher · Spike: all 10 request p95 values lower.",
         0.84, 6.38, 11.70, 0.39, 16, ORANGE, bold=True)
    add_notes(slide, 85, "The pooled total and individual requests must be read together.",
              "Soak means repeated traffic over time. Spike means many users arrive quickly. The whole-run Total p95 fell in both profiles. But the request-level records add an important distinction: in soak, 9 of 10 individual request p95 values rose after the change, even though the pooled Total p95 fell. The Total is recalculated from all requests; it is not an average of the individual request p95 values. In spike, all 10 individual request p95 values fell and overall errors went from 218 to zero. This is why I do not say every soak request improved. The detailed request tables are on slides 46 and 47, and the native dashboards remain in Appendix L. These whole-run figures are not direct proof of no soak drift or spike recovery. The core 50, 100, and 500 VU p95 results worsened, so I cannot claim overall performance success.",
              "Fresh JMeter baseline/remediation statistics.json and summary.json; current report §4.4; Appendix L Figures L.12-L.13 and L.17-L.18.",
              "Do not claim a fixed three-hour soak or exactly 100 total threads: the runner configures 100 core plus 30 report threads and has no fixed-duration scheduler.")

    # 19. Endpoint-level tradeoff
    slide = header(prs, "Results", "GET /reports/account-ledger behaved differently", "Current report Table 4.4; Appendix G", ORANGE)
    table(slide, [
        ["Account-ledger profile", "Baseline p95", "After p95", "Interpretation"],
        ["Soak", "741.95 ms", "3,825.70 ms", "Regression"],
        ["Spike", "50,288.30 ms", "12,910.20 ms", "Improvement"],
    ], 0.80, 1.62, 11.72, 2.54, widths=[0.29,0.22,0.22,0.27], font_size=19)
    box(slide, 0.80, 4.49, 11.72, 1.72, WHITE, BORDER, radius=True)
    text(slide, "Why this matters", 1.07, 4.73, 10.90, 0.38, 19, ORANGE, bold=True)
    text(slide, "The same endpoint behaved differently under two workloads. These results do not identify one cause.",
         1.07, 5.14, 10.88, 0.77, 20, INK)
    add_notes(slide, 70, "One report endpoint improved in one test and slowed in another.",
              "The GET /reports/account-ledger endpoint got slower during the long soak test: p95 rose from about 742 to 3,826 milliseconds. During the sudden spike test it improved, from about 50.3 seconds to 12.9 seconds. This does not tell us why. It shows that I cannot claim every report request became faster under every workload.",
              "Current report Table 4.4 and Appendix G.")

    # 20. User-visible application evidence
    slide = header(prs, "Results", "The API was exercised through a role-aware client", "Current report §4.6, Figures 4.2 and 4.7", NAVY)
    image_contain(slide, WEB_ROOT / "02-dashboard-admin.png", 0.82, 1.63, 5.69, 3.79, visible_top_px=1000)
    image_contain(slide, WEB_ROOT / "07-journal-entry-details.png", 6.83, 1.63, 5.69, 3.79, visible_top_px=1000)
    text(slide, "Admin dashboard", 0.94, 5.56, 5.49, 0.33, 18, NAVY, bold=True)
    text(slide, "Balanced journal-entry lines", 6.96, 5.56, 5.47, 0.33, 18, NAVY, bold=True)
    box(slide, 0.84, 6.03, 11.65, 0.58, NAVY_LIGHT, radius=True)
    text(slide, "These are browser workflow screenshots; their displayed counts are not benchmark metrics.", 1.04, 6.10, 11.19, 0.39, 16, NAVY, bold=True)
    add_notes(slide, 70, "These are app screens, not speed-test results.",
              "The pictures show the admin dashboard and a journal entry whose debit and credit lines balance. They help demonstrate that I can use the API through the web app. They do not show how fast the API is. For performance evidence, use backup slide 31 or the JMeter dashboards on slides 37-41.",
              "Current report §4.6 and Figures 4.2-4.7.")

    # 25. Decision matrix, followed by a separate scope slide.
    slide = header(prs, "Synthesis", "The three results are different", "Current report Table 4.5; Appendix N", TEAL)
    table(slide, [
        ["Area", "Decision", "Why"],
        ["Code quality", "Achieved", "17 issues → 0; gate OK; small coverage/complexity regressions"],
        ["Security", "Configured gate passed", "Passive cleared; raw API Medium transport alert remains"],
        ["Core performance", "Not achieved", "100 VU and 500 VU p95 exceeded thresholds"],
        ["Soak/spike p95", "Total p95 lower", "Soak: 9/10 requests higher; spike: 10/10 lower"],
    ], 0.80, 1.49, 11.72, 4.12, widths=[0.20,0.28,0.52], font_size=17)
    text(slide, "Next: where these case-study conclusions apply, and what requires another test.",
         0.83, 5.92, 11.68, 0.45, 19, MUTED)
    add_notes(slide, 80, "The study does not support a blanket claim that everything improved.",
              "Code warnings fell from 17 to zero, although coverage fell a little and complexity rose. ZAP's selected checks passed, but the local HTTP alert stayed. JMeter missed the main 100- and 500-user speed targets. The pooled soak and spike p95 values fell, but nine of ten soak request p95 values actually rose; all ten spike request p95 values fell. Each tool therefore answers a different part of the research question. On the next slide I will explain which conclusions apply to this tested case and what would need more validation before generalizing them.",
              "Current report Table 4.5 and Appendix N.")

    # 26. Limitations and next validation
    slide = header(prs, "Scope", "Limitations and next validation", "Current report, Limitations and Future Work; Appendix N", NAVY)
    limit_cards = [
        (0.80, "ONE CASE", "one API · one ChatGPT setup",
         "The findings describe this financial API and dataset, not every API or AI assistant.", NAVY_LIGHT, NAVY),
        (4.78, "LOCAL MEASUREMENT", "one fresh run per branch",
         "CPU/RAM use and hosted service tiers were outside the measured variables.", TEAL_LIGHT, TEAL),
        (8.76, "DEPLOYMENT", "local HTTP target",
         "An HTTPS retest is needed for the remaining ZAP transport observation.", ORANGE_LIGHT, ORANGE),
    ]
    for x, tag, title, detail, fill, accent in limit_cards:
        box(slide, x, 1.57, 3.76, 3.98, fill, BORDER, radius=True)
        text(slide, tag, x+0.23, 1.87, 3.30, 0.30, 15, accent, bold=True)
        text(slide, title, x+0.23, 2.39, 3.30, 0.90, 23, accent, bold=True)
        text(slide, detail, x+0.23, 3.54, 3.30, 1.60, 19, INK)
    box(slide, 0.84, 5.88, 11.64, 0.80, WHITE, BORDER, radius=True)
    text(slide, "Next: repeat matched runs with resource traces; test HTTPS; compare assistants separately.",
         1.06, 6.03, 11.20, 0.47, 18, NAVY, bold=True)
    add_notes(slide, 75, "These boundaries define where the case-study result applies.",
              "This slide states where my conclusions apply. I tested one financial API and one ChatGPT configuration so the branch comparisons are traceable. Each evidence branch has one fresh local run. JMeter measured API response times, but CPU and RAM utilization and managed service tiers were outside my measured variables, so I cannot assign one hardware cause to the slower core profiles or claim the same timing on another machine. ZAP examined a local HTTP target; the remaining HTTP Only Site observation needs a production-like HTTPS retest. To extend this work, I would repeat matched runs while recording resource use and run-to-run variability, test defined hardware or service tiers and HTTPS, and compare another assistant in a separate study. The observed issue closure and tool outputs remain valid for the tested case; broader claims need replication.",
              "Current report, Limitations and Future Work; Appendix N; backup claim-to-evidence map.")

    # 27. Conclusion
    slide = header(prs, "Closing", "The strongest contribution is the traceable check-and-fix method", "Current report Chapter 5; Appendices A-N", TEAL)
    for index, (number, title, body, color) in enumerate([
        ("01", "The model can help", "Seventeen fresh static issues closed; security rule gate passed.", GREEN),
        ("02", "Measurement can reject it", "The primary JMeter target was not met despite lower soak and spike p95.", RED),
        ("03", "Provenance makes it auditable", "Pinned branches, tests, dashboard captures, and raw records remain available.", TEAL),
    ]):
        y = 1.51 + index*1.58
        box(slide, 0.80, y, 11.72, 1.35, WHITE, BORDER, radius=True)
        text(slide, number, 1.05, y+0.31, 0.70, 0.51, 26, color, bold=True)
        text(slide, title, 1.95, y+0.15, 10.20, 0.43, 22, color, bold=True)
        text(slide, body, 1.95, y+0.68, 10.20, 0.45, 18, INK)
    text(slide, "Thank you. Questions?", 0.82, 6.36, 11.72, 0.39, 25, TEAL, bold=True)
    add_notes(slide, 80, "The contribution is a way to check AI suggestions, including when they do not work.",
              "This was an applied case study, not a new algorithm, scoring matrix, or comparison of AI assistants. ChatGPT helped me propose code changes. I reviewed them, and the original tools measured the results. Code warnings reached zero and selected security checks passed, but the main performance target was not met. My contribution is the traceable process and this honest mixed result, not a claim that ChatGPT always improves an API. Thank you; I welcome questions.",
              "Current report Chapter 5 and Appendices A-N.")

    return len(prs.slides)


def backup_notes(slide, title, source, caveat="", explanation=""):
    add_notes(slide, 0, f"Backup evidence: {title}.",
              explanation or "Open this slide if asked for proof. Point to the relevant number or code change, then name the source shown on the slide.",
              source, caveat)


def dashboard_pair(prs, title, before_path: str, after_path: str, summary: str, source: str,
                   classification: str, accent=TEAL, explanation=""):
    slide = header(prs, "Backup · native dashboards", title, source, accent)
    text(slide, "BASELINE", 0.88, 1.40, 5.62, 0.34, 17, NAVY, bold=True)
    text(slide, "REMEDIATION", 6.83, 1.40, 5.62, 0.34, 17, accent, bold=True)
    image_contain(slide, DASHBOARD_ROOT / before_path, 0.86, 1.84, 5.64, 3.97)
    image_contain(slide, DASHBOARD_ROOT / after_path, 6.82, 1.84, 5.64, 3.97)
    box(slide, 0.84, 5.99, 11.64, 0.68, ORANGE_LIGHT if classification == "rendered-historical" else TEAL_LIGHT, radius=True)
    text(slide, summary, 1.02, 6.06, 11.28, 0.49, 17,
         ORANGE if classification == "rendered-historical" else accent, bold=True)
    before = facts_capture(before_path)
    after = facts_capture(after_path)
    backup_notes(slide, title, source,
                 f"Capture classification: {classification}. Baseline {before['branch']} @ {before['commit'][:8]}, run {before['runId']}; remediation {after['branch']} @ {after['commit'][:8]}, run {after['runId']}.",
                 explanation)
    return slide


CAPTURES: dict[str, dict] = {}


def facts_capture(relative_path: str) -> dict:
    if relative_path not in CAPTURES:
        raise RuntimeError(f"Dashboard image is not registered in the capture manifest: {relative_path}")
    return CAPTURES[relative_path]


def app_pair(prs, title, left_file: str, left_label: str, right_file: str | None,
             right_label: str | None, source: str):
    slide = header(prs, "Backup · application evidence", title, source, NAVY)
    if right_file:
        image_contain(slide, WEB_ROOT / left_file, 0.85, 1.82, 5.65, 4.28, visible_top_px=1000)
        image_contain(slide, WEB_ROOT / right_file, 6.82, 1.82, 5.65, 4.28, visible_top_px=1000)
        text(slide, left_label, 0.89, 6.20, 5.57, 0.39, 16, NAVY, bold=True)
        text(slide, right_label or "", 6.87, 6.20, 5.57, 0.39, 16, NAVY, bold=True)
    else:
        image_contain(slide, WEB_ROOT / left_file, 1.20, 1.63, 10.85, 4.79, visible_top_px=1000)
        text(slide, left_label, 1.24, 6.39, 10.80, 0.28, 16, NAVY, bold=True)
    backup_notes(slide, title, source,
                 "These are browser workflow captures; visible live application counts are not JMeter benchmark metrics.",
                 "These pictures show that I can use the application and see its accounting screens. They do not measure speed. For JMeter response times, open backup slide 31 or dashboards 38-42.")


def request_detail_slide(prs: Presentation, facts: dict, profile: str) -> None:
    """Expose every recorded request while retaining the native dashboard slides."""
    summaries = {
        role: profile_map(facts["jmeter"][role])[profile]
        for role in ("baseline", "remediation")
    }
    records = {
        role: json.loads((ROOT / summary["statisticsPath"]).read_text(encoding="utf-8-sig"))
        for role, summary in summaries.items()
    }
    before, after = records["baseline"], records["remediation"]
    if set(before) != set(JMETER_REQUEST_ORDER) or set(after) != set(JMETER_REQUEST_ORDER):
        raise RuntimeError(f"The {profile} request labels differ from the saved JMeter profile.")
    if any(before[request]["sampleCount"] != after[request]["sampleCount"] for request in JMETER_REQUEST_ORDER):
        raise RuntimeError(f"The {profile} before/after request counts are not matched.")
    for role, record in records.items():
        if abs(record["Total"]["pct2ResTime"] - summaries[role]["p95Ms"]) > 0.02:
            raise RuntimeError(f"The {profile} {role} summary disagrees with statistics.json.")

    source = ("Fresh JMeter baseline/remediation statistics.json; "
              f"Appendix L Figures L.{12 if profile == 'soak' else 13} and "
              f"L.{17 if profile == 'soak' else 18}")
    slide = header(prs, "Backup evidence", f"JMeter {profile} · every request", source, ORANGE)
    rows = [["Request", "Baseline p95", "After p95", "Failures B→A", "p95"]]
    for request in JMETER_REQUEST_ORDER:
        baseline, remediation = before[request], after[request]
        direction = "Lower" if remediation["pct2ResTime"] < baseline["pct2ResTime"] else "Higher"
        rows.append([
            request,
            f"{baseline['pct2ResTime']:,.2f}",
            f"{remediation['pct2ResTime']:,.2f}",
            f"{baseline['errorCount']}→{remediation['errorCount']}",
            direction,
        ])
    grid = table(slide, rows, 0.80, 1.47, 11.72, 4.77,
                 widths=[0.37, 0.17, 0.17, 0.15, 0.14], font_size=15)
    for row_index in range(1, len(rows)):
        cell = grid.cell(row_index, 4)
        for paragraph in cell.text_frame.paragraphs:
            for run in paragraph.runs:
                run.font.bold = True
                run.font.color.rgb = GREEN if rows[row_index][4] == "Lower" else RED

    higher = sum(after[request]["pct2ResTime"] > before[request]["pct2ResTime"]
                 for request in JMETER_REQUEST_ORDER if request != "Total")
    lower = 10 - higher
    if profile == "soak":
        if (higher, lower) != (9, 1):
            raise RuntimeError("The soak request-level p95 direction changed.")
        takeaway = "Soak: Total p95 lower, but 9/10 request p95 values higher; failures remained zero."
        explanation = ("The pooled Total p95 fell, but nine of ten individual request p95 values rose. "
                       "Total p95 is a pooled percentile, not the average of the request p95 values. "
                       "Only profit-loss had a lower request p95. All requests had zero failures before and after. "
                       "The before/after sample count matches for every request. Point to the requested endpoint "
                       "in this table, then to the native soak dashboards on slide 41 if asked for the tool view.")
    else:
        if (higher, lower) != (0, 10):
            raise RuntimeError("The spike request-level p95 direction changed.")
        takeaway = "Spike: all 10 request p95 values lower; total failures 218 → 0."
        explanation = ("All ten individual request p95 values fell in the spike run. The total failed samples "
                       "fell from 218 to zero. The before/after sample count matches for every request. "
                       "This is a burst-specific improvement, not proof that the core 100- and 500-user "
                       "targets passed. Open the native spike dashboards on slide 42 if asked for the tool view.")
    box(slide, 0.84, 6.34, 11.64, 0.45, ORANGE_LIGHT, radius=True)
    text(slide, takeaway, 1.04, 6.39, 11.25, 0.33, 16, ORANGE, bold=True)
    backup_notes(slide, f"{profile} request-level JMeter results", source, explanation=explanation)


def build_appendix_slides(prs: Presentation, facts: dict) -> None:
    sonar = facts["sonar"]
    zap = facts["zap"]
    jmeter = facts["jmeter"]
    sb, sa = profile_map(jmeter["baseline"]), profile_map(jmeter["remediation"])

    # 23. Evidence map
    slide = header(prs, "Backup evidence", "Where each defense claim can be checked", "Current report Appendices A-N and fresh run summaries", NAVY)
    table(slide, [
        ["Claim", "Machine-readable record", "Report evidence"],
        [f"Dataset: {facts['dataset']['accounts']} accounts", "branch-verification.json", "Tables 3.10-3.11 · Appendix H"],
        ["Static issues", "sonar/*/summary.json", "Table 4.2 · Appendix E · Figures L.1-L.4"],
        ["ZAP raw/gate", "zap/*/summary.json", "§4.3 · Appendices F and M"],
        ["JMeter p95/gate", "jmeter/*/summary.json", "§4.4 · Appendix G · Figures L.9-L.18"],
        ["Working API", "role/browser run records", "§4.6 · Figures 4.2-4.7"],
    ], 0.80, 1.52, 11.72, 4.58, widths=[0.23,0.30,0.47], font_size=16)
    backup_notes(slide, "evidence map", "branch-verification.json dataset counts; current report Appendices A-N.",
                 explanation="Start with the claim in the left column. The middle column names the raw result file; the right column names the report section. The first row confirms the 120 seeded accounts used by the tests.")

    # 24. Provenance
    slide = header(prs, "Backup evidence", "Exact baseline and remediation commits", "Current report Appendix A; Table 3.1", NAVY)
    table(slide, [
        ["Role", "Branch", "Tested commit"],
        ["Shared baseline", "baseline-v0.1", "7a0469d9"],
        ["Static quality", "baseline-sonarqube-v1", "a2279bcb"],
        ["Security", "baseline-zap-v1", "5f3bd3cc"],
        ["Performance", "baseline-jmeter-v1", "78b08b62"],
    ], 0.80, 1.51, 11.72, 4.85, widths=[0.25,0.47,0.28], font_size=17)
    backup_notes(slide, "branch provenance", "Current report Appendix A and Table 3.1.")

    # 25. Full Sonar metrics
    slide = header(prs, "Backup evidence", "Fresh SonarQube metric detail", "Current report Table 4.2; fresh SonarQube summaries", GREEN)
    rows = [["Metric", "Baseline", "After", "Meaning"]]
    important = [
        "Total unique issues", "Code smells (legacy type)", "Bugs (legacy type)",
        "Vulnerabilities (legacy type)", "Reliability impacts (MQR)*", "Security impacts (MQR)*",
        "Maintainability impacts (MQR)*", "Security hotspots", "Coverage",
        "Duplicated lines", "Cyclomatic complexity", "Cognitive complexity", "Quality Gate",
    ]
    interpretation = {
        "Total unique issues": "Distinct issue count", "Code smells (legacy type)": "Legacy type",
        "Bugs (legacy type)": "Legacy type", "Vulnerabilities (legacy type)": "Legacy type",
        "Reliability impacts (MQR)*": "Overlapping impact", "Security impacts (MQR)*": "Overlapping impact",
        "Maintainability impacts (MQR)*": "Overlapping impact", "Security hotspots": "Scanner finding",
        "Coverage": "Down 0.1 point", "Duplicated lines": "Unchanged", "Cyclomatic complexity": "Up 3",
        "Cognitive complexity": "Unchanged", "Quality Gate": "OK/OK; no conditions saved",
    }
    for name in important:
        before, after = facts["sonar_rows"][name]
        rows.append([name.replace(" (legacy type)", "").replace(" impacts (MQR)*", " impact*"), before, after, interpretation[name]])
    table(slide, rows, 0.79, 1.40, 11.75, 5.39, widths=[0.36,0.15,0.15,0.34], font_size=12)
    backup_notes(slide, "full fresh SonarQube metrics", "Current report Table 4.2; fresh SonarQube summary.json and quality-gate.json.",
                 "* MQR impacts overlap; do not sum them as unique issues. Both saved gate files have an empty conditions list.",
                 "Point to Total unique issues: 17 before, zero after. The gate status is OK on both, but no gate conditions were saved, so do not use that status alone to claim improvement. Coverage slipped by 0.1 percentage point.")

    # 26. Full ZAP raw outcomes
    slide = header(prs, "Backup evidence", "Fresh ZAP raw alert counts and gate", "Current report §4.3; fresh ZAP summaries; Appendix F", RED)
    rows = [["Scan", "Role", "High", "Medium", "Low", "Info", "Gate"]]
    for role in ("baseline", "remediation"):
        for scan in zap[role]["scans"]:
            rows.append(["Passive" if scan["scan"] == "baseline" else "Auth API", role,
                         str(scan["high"]), str(scan["medium"]), str(scan["low"]),
                         str(scan["informational"]), "PASS"])
    table(slide, rows, 0.79, 1.48, 11.75, 4.18, widths=[0.19,0.20,0.10,0.12,0.10,0.10,0.19], font_size=16)
    box(slide, 0.83, 5.91, 11.66, 0.63, ORANGE_LIGHT, radius=True)
    text(slide, "Raw API Medium after remediation = 1 (HTTP Only Site); configured rule gate = PASS.",
         1.03, 5.99, 11.20, 0.42, 17, ORANGE, bold=True)
    backup_notes(slide, "full fresh ZAP outcomes", "Current report §4.3 and fresh ZAP summary.json.",
                 "Configured gate PASS does not mean every raw API Medium alert cleared.",
                 "Point to the Auth API after-fix row: Medium is still one, while Low is zero. The Medium is HTTP Only Site because the local scan used HTTP. The configured rule gate passed, but this raw alert was not cleared; an HTTPS retest is needed.")

    # 27. Full JMeter profiles
    slide = header(prs, "Backup evidence", "Fresh JMeter profile matrix", "Current report §4.4; fresh JMeter summaries", ORANGE)
    rows = [["Profile", "Baseline p95", "After p95", "Before err", "After err", "After tx/s"]]
    for profile in ("p50", "p100", "p500", "soak", "spike"):
        before, after = sb[profile], sa[profile]
        rows.append([PROFILE_DISPLAY.get(profile, profile), f"{before['p95Ms']:,.2f}", f"{after['p95Ms']:,.2f}",
                     f"{before['errorPct']:.4f}%", f"{after['errorPct']:.4f}%", f"{after['throughput']:.2f}"])
    table(slide, rows, 0.79, 1.53, 11.75, 4.53, widths=[0.14,0.19,0.19,0.17,0.17,0.14], font_size=16)
    text(slide, "Baseline core gate PASS; remediation core gate FAIL (100 VU and 500 VU thresholds).", 0.83, 6.29, 11.67, 0.41, 17, RED, bold=True)
    backup_notes(slide, "full fresh JMeter matrix", "Fresh JMeter baseline/remediation summary.json and current report §4.4.",
                 explanation="Point to the 100- and 500-VU rows. Their after-fix p95 values are higher than before and exceed the study limits, so the core target was not met. Soak and spike have lower p95 after the fix, but those are separate tests.")

    # 28. Source-code example: S107
    slide = header(prs, "Backup evidence", "S107 source: eight parameters to one DTO", "Current report Listing E.1; Tables 3.4 and 4.3", TEAL)
    box(slide, 0.80, 1.55, 5.70, 3.97, WHITE, BORDER, radius=True)
    box(slide, 6.82, 1.55, 5.70, 3.97, WHITE, BORDER, radius=True)
    text(slide, "BEFORE · baseline-v0.1", 1.03, 1.78, 5.22, 0.34, 17, RED, bold=True)
    text(slide, "AFTER · baseline-sonarqube-v1", 7.05, 1.78, 5.22, 0.34, 17, GREEN, bold=True)
    text(slide, "GetPaged(\n  from, to, status, accountId,\n  search, page, pageSize, sort\n)\n\n// 8 query parameters", 1.03, 2.31, 5.16, 2.72, 18, INK, font=CODE_FONT, valign=MSO_ANCHOR.TOP)
    text(slide, "GetPaged(\n  JournalEntryQueryDto query\n)\n\n// DTO carries the query inputs", 7.05, 2.31, 5.15, 2.72, 18, INK, font=CODE_FONT, valign=MSO_ANCHOR.TOP)
    text(slide, "Measured result: fresh SonarQube issues 17 → 0; the route remains GET /journal-entries.",
         0.86, 5.83, 11.58, 0.58, 18, TEAL, bold=True)
    backup_notes(slide, "S107 controller DTO change", "Current report Listing E.1, Table 4.3, Appendix E.")

    # 29. Source-code paths for security and performance
    slide = header(prs, "Backup evidence", "Source examples: security order and report persistence", "Current report Listings F.1-F.2 and G.1-G.3", TEAL)
    box(slide, 0.80, 1.55, 5.70, 4.55, WHITE, BORDER, radius=True)
    box(slide, 6.82, 1.55, 5.70, 4.55, WHITE, BORDER, radius=True)
    text(slide, "SECURITY · API/Program.cs", 1.04, 1.82, 5.12, 0.36, 17, RED, bold=True)
    text(slide, "SecurityHeadersMiddleware\n→ before Swagger/OpenAPI\n\nSwagger UI exposed only when the separate UI flag allows it.",
         1.04, 2.37, 5.13, 2.70, 20, INK, valign=MSO_ANCHOR.TOP)
    text(slide, "PERFORMANCE · FinancialReportService.cs", 7.04, 1.82, 5.17, 0.36, 17, ORANGE, bold=True)
    text(slide, "Cache account-ledger data\n+ stop report snapshot writes on this read path\n\nThe core speed target was not met.",
         7.04, 2.37, 5.15, 2.70, 20, INK, valign=MSO_ANCHOR.TOP)
    text(slide, "This shows what changed in code; slide 31 shows the measured performance result.",
         0.85, 6.24, 11.70, 0.42, 16, TEAL, bold=True)
    backup_notes(slide, "security and performance source paths", "Current report Appendices F and G.",
                 explanation="The left side shows the security-header change. The right side shows my performance attempt: cache ledger data and avoid a report snapshot write on this read path. This proves the change was made, not that it made the API faster. For speed numbers, open backup slide 31 and dashboards 38-39.")

    # 30. Role/invariant checks
    slide = header(prs, "Backup evidence", "Authorization and accounting controls remained testable", "Current report Appendices C, D, I and §4.6", NAVY)
    table(slide, [
        ["Control", "Evidence path", "Expected boundary"],
        ["JWT / roles", "Controller attributes + RBAC matrix", "Protected routes reject unauthorized roles"],
        ["Journal posting", "Balanced debit-credit source", "Closed periods and unequal totals rejected"],
        ["Audit trail", "Service + browser log view", "Actor and sensitive action recorded"],
        ["Browser roles", "Admin / Auditor screenshots", "Navigation and read-only behavior visible"],
    ], 0.79, 1.50, 11.75, 4.69, widths=[0.23,0.35,0.42], font_size=17)
    backup_notes(slide, "authorization and accounting evidence", "Current report Appendices C, D, I and Figures 4.2-4.7.")

    # 31-39. Every tool dashboard capture appears once, paired by profile/role.
    dashboard_pair(prs, "SonarQube overview · baseline vs remediation",
                   "sonarqube/sonarqube-baseline-overview.png", "sonarqube/sonarqube-remediation-overview.png",
                   "17 issues → 0; gate OK/OK (no conditions recorded); coverage 74.4% → 74.3%.",
                   "Appendix L Figures L.1 and L.3", "fresh-reproduction", GREEN,
                   "The two current screenshots show different issue counts: 17 before and zero after. Both show Quality Gate OK, but the saved gate files contain no conditions. Do not present OK/OK as the evidence of improvement; use the issue counts and disclose that coverage fell slightly.")
    dashboard_pair(prs, "SonarQube issues · baseline vs remediation",
                   "sonarqube/sonarqube-baseline-issues.png", "sonarqube/sonarqube-remediation-issues.png",
                   "Fresh issue-list views: 17 baseline findings and 0 after remediation.",
                   "Appendix L Figures L.2 and L.4", "fresh-reproduction", GREEN,
                   "Point to the issue list: the baseline has 17 distinct findings and the changed branch has zero. These are the direct issue-count views; the gate status is separate.")
    for profile, number in [("p50",9),("p100",10),("p500",11),("soak",12),("spike",13)]:
        before, after = sb[profile], sa[profile]
        judgment = {
            "p50": "CORE SLOWER", "p100": "CORE TARGET NOT MET", "p500": "CORE TARGET NOT MET",
            "soak": "SOAK p95 LOWER", "spike": "SPIKE p95 LOWER",
        }[profile]
        if profile in ("p100", "p500"):
            limit = 500 if profile == "p100" else 1200
            explanation = (f"In the Total row, find the 95th-percentile response time. At {PROFILE_DISPLAY[profile]}, "
                           f"it rose from {before['p95Ms']:g} to {after['p95Ms']:g} milliseconds. "
                           f"The after-fix value is above this study's {limit}-millisecond limit, so the core target was not met. "
                           "This is a measurement, not proof of what caused the slowdown.")
        elif profile == "p50":
            explanation = (f"At 50 simulated users, total p95 rose from {before['p95Ms']:g} to "
                           f"{after['p95Ms']:g} milliseconds. It is slower after the code change, even though "
                           "it stayed below this study's 300-millisecond limit.")
        elif profile == "soak":
            explanation = (f"The pooled Total p95 fell from {before['p95Ms']:g} to {after['p95Ms']:g} milliseconds, "
                           "but 9 of 10 individual request p95 values rose. Open the request table on slide 46. "
                           "The core 100- and 500-user targets were still not met.")
        else:
            explanation = (f"The spike Total p95 fell from {before['p95Ms']:g} to {after['p95Ms']:g} milliseconds, "
                           "and all 10 individual request p95 values fell. Open the request table on slide 47. "
                           "The core 100- and 500-user targets were still not met.")
        dashboard_pair(prs, f"JMeter {PROFILE_DISPLAY.get(profile, profile)} · baseline vs remediation",
                       f"jmeter/jmeter-baseline-{profile}-dashboard.png",
                       f"jmeter/jmeter-remediation-{profile}-dashboard.png",
                       f"Fresh total p95 {before['p95Ms']:g} → {after['p95Ms']:g} ms · {judgment}.",
                       f"Appendix L Figures L.{number} and L.{number+5}; fresh JMeter summary.json",
                       "fresh-reproduction", ORANGE, explanation)

    # 40-42. Browser evidence without the credential-bearing login screen.
    app_pair(prs, "App screens—not load-test data", "02-dashboard-admin.png", "Admin dashboard",
             "03-reports-trial-balance.png", "Trial-balance report", "Current report Figures 4.2 and 4.3")
    app_pair(prs, "Application: audit and role restrictions", "04-audit-logs.png", "Audit-log view",
             "05-auditor-role-view.png", "Auditor navigation", "Current report Figures 4.4 and 4.5")
    app_pair(prs, "Application: evidence and balanced journal lines", "06-research-evidence.png", "Research-evidence map",
             "07-journal-entry-details.png", "Expanded debit and credit lines", "Current report Figures 4.6 and 4.7")
    request_detail_slide(prs, facts, "soak")
    request_detail_slide(prs, facts, "spike")


def build() -> Path:
    facts = read_facts()
    CAPTURES.clear()
    CAPTURES.update(facts["captures"])
    prs = Presentation()
    prs.slide_width = Inches(W)
    prs.slide_height = Inches(H)
    prs.core_properties.title = "Final Thesis Defense - Current Fresh Results"
    prs.core_properties.subject = "Branch-isolated evidence for financial accounting API remediation"
    prs.core_properties.author = "Zaw Ye Htut Ko"
    prs.core_properties.keywords = "SonarQube, OWASP ZAP, JMeter, ChatGPT, financial API"
    main_count = build_main_slides(prs, facts)
    if main_count != 27:
        raise RuntimeError(f"Expected 27 timed slides, built {main_count}")
    build_appendix_slides(prs, facts)
    if len(prs.slides) != 47:
        raise RuntimeError(f"Expected 47 total slides, built {len(prs.slides)}")
    for slide in prs.slides:
        notes = slide.notes_slide.notes_text_frame
        notes.text = shift_backup_references(notes.text)
    add_evidence_cues(prs)
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    prs.save(OUTPUT)
    return OUTPUT


if __name__ == "__main__":
    path = build()
    print(path)
