from __future__ import annotations

import argparse
from collections import Counter
from pathlib import Path

from docx import Document
from docx.document import Document as DocumentObject
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.shared import Inches, Pt


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_REPORT = ROOT / "Document" / "outputs" / "final-report-23SEP.docx"
LABELS = {
    "Purpose. ": "Purpose: ",
    "Source. ": "Source: ",
    "Verification. ": "Verification: ",
}


def standardize_appendix_labels(doc: DocumentObject) -> Counter[str]:
    paragraphs = doc.paragraphs
    marker = next(
        i for i, paragraph in enumerate(paragraphs)
        if paragraph.text == "APPENDICES" and paragraph.style.name == "Heading 1"
    )
    changed: Counter[str] = Counter()
    for paragraph in paragraphs[marker + 1 :]:
        for old, new in LABELS.items():
            if not paragraph.text.startswith(old):
                continue
            if not paragraph.runs or not paragraph.runs[0].text.startswith(old):
                raise RuntimeError(f"Cannot safely replace a split appendix label: {paragraph.text[:80]}")
            label_run = paragraph.runs[0]
            label_run.text = new + label_run.text[len(old) :]
            label_run.bold = True
            label_run.font.name = "Times New Roman"
            label_run.font.size = Pt(12)

            if new == "Verification: " and len(paragraph.runs) > 1:
                body_run = paragraph.runs[1]
                prefix = "Related evidence: "
                if body_run.text.startswith(prefix):
                    body = body_run.text[len(prefix) :]
                    body_run.text = body[:1].upper() + body[1:]

            paragraph.paragraph_format.line_spacing = 2.0
            if new == "Source: ":
                paragraph.alignment = WD_ALIGN_PARAGRAPH.LEFT
                paragraph.paragraph_format.first_line_indent = Inches(0)
            else:
                paragraph.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
                paragraph.paragraph_format.first_line_indent = Inches(0.5)
            changed[new.strip()] += 1
            break
    return changed


def standardize_report(path: Path) -> Counter[str]:
    doc = Document(path)
    changed = standardize_appendix_labels(doc)
    doc.save(path)
    return changed


def main() -> None:
    parser = argparse.ArgumentParser(description="Use readable colon labels in appendix listings.")
    parser.add_argument("target", nargs="?", type=Path, default=DEFAULT_REPORT)
    args = parser.parse_args()
    target = args.target.resolve()
    changed = standardize_report(target)
    print(target)
    print(dict(changed))


if __name__ == "__main__":
    main()
