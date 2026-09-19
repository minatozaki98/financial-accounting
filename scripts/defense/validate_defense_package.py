from __future__ import annotations

import json
import re
import sys
import zipfile
from pathlib import Path

from docx import Document
from pypdf import PdfReader


ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "Document" / "outputs" / "final-defense"
PPTX = OUTPUT / "G6519692_Zaw_Ye_Htut_Ko_Final_Thesis_Defense.pptx"
PRESENTATION_PDF = OUTPUT / "G6519692_Zaw_Ye_Htut_Ko_Final_Thesis_Defense.pdf"
GUIDE_DOCX = OUTPUT / "G6519692_Zaw_Ye_Htut_Ko_Defense_Preparation_Guide.docx"
GUIDE_PDF = OUTPUT / "G6519692_Zaw_Ye_Htut_Ko_Defense_Preparation_Guide.pdf"
CONTENT = ROOT / "scripts" / "defense" / "defense_content.json"


class ValidationFailure(RuntimeError):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValidationFailure(message)


def office_text(archive_path: Path) -> str:
    with zipfile.ZipFile(archive_path) as archive:
        return "".join(
            archive.read(name).decode("utf-8", "ignore")
            for name in archive.namelist()
            if name.endswith(".xml")
        )


def count_pptx_parts() -> tuple[int, int, int]:
    with zipfile.ZipFile(PPTX) as archive:
        names = archive.namelist()
    slides = [name for name in names if re.fullmatch(r"ppt/slides/slide\d+\.xml", name)]
    notes = [name for name in names if re.fullmatch(r"ppt/notesSlides/notesSlide\d+\.xml", name)]
    media = [name for name in names if name.startswith("ppt/media/")]
    return len(slides), len(notes), len(media)


def validate() -> dict:
    for path in (PPTX, PRESENTATION_PDF, GUIDE_DOCX, GUIDE_PDF, CONTENT):
        require(path.is_file(), f"Missing required artifact: {path}")

    content = json.loads(CONTENT.read_text(encoding="utf-8"))
    main_seconds = sum(slide["durationSeconds"] for slide in content["slides"])
    question_count = len(content["questions"])
    require(1500 <= main_seconds <= 1680, f"Main script timing out of range: {main_seconds} seconds")
    require(question_count >= 30, f"Question bank too small: {question_count}")

    slide_count, notes_count, media_count = count_pptx_parts()
    require(slide_count == 32, f"Expected 32 slides, found {slide_count}")
    require(notes_count >= 22, f"Expected notes for at least 22 slides, found {notes_count}")
    require(media_count >= 8, f"Expected at least 8 embedded evidence images, found {media_count}")

    presentation_pages = len(PdfReader(PRESENTATION_PDF).pages)
    guide_pages = len(PdfReader(GUIDE_PDF).pages)
    require(presentation_pages == 32, f"Expected 32 presentation PDF pages, found {presentation_pages}")
    require(guide_pages >= 20, f"Expected at least 20 guide PDF pages, found {guide_pages}")

    guide = Document(GUIDE_DOCX)
    guide_text = "\n".join(paragraph.text for paragraph in guide.paragraphs)
    combined = office_text(PPTX) + office_text(GUIDE_DOCX) + guide_text
    forbidden = ("T" + "BD", "TO" + "DO", "Lorem " + "ipsum", "Click to " + "add")
    hits = [token for token in forbidden if token in combined]
    require(not hits, f"Placeholder tokens found: {hits}")

    return {
        "slides": slide_count,
        "notes": notes_count,
        "media": media_count,
        "presentationPdfPages": presentation_pages,
        "guidePdfPages": guide_pages,
        "mainSeconds": main_seconds,
        "mainMinutes": round(main_seconds / 60, 2),
        "questions": question_count,
        "status": "PASS",
    }


def main() -> int:
    try:
        result = validate()
    except (ValidationFailure, OSError, ValueError, zipfile.BadZipFile) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        return 1
    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
