# Final Thesis Defense Presentation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce an editable, evidence-grounded 30-minute PowerPoint defense deck and a complete English preparation guide for Zaw Ye Htut Ko's final thesis defense.

**Architecture:** Store all slide copy, evidence values, notes, timing, and committee questions in one reviewed JSON content model. A focused PptxGenJS builder converts that model and repository evidence images into a 16:9 PowerPoint with native charts and speaker notes. A Python document builder creates the preparation-guide DOCX from the same model, while validation and Office-export scripts verify package structure, evidence accuracy, timing, notes, and rendered layout.

**Tech Stack:** Node.js, PptxGenJS, Sharp, Python 3, python-docx, pypdf, Microsoft PowerPoint COM, Microsoft Word COM, Poppler, unittest

**Spec:** `docs/superpowers/specs/2026-09-19-final-thesis-defense-presentation-design.md`

## Global Constraints

- Source of truth: `Document/outputs/final-report-gpt55-comparison.docx` and its matching 64-page PDF.
- Output language: English.
- Defense duration: 30 minutes; main script target is 27-28 minutes.
- Presentation format: editable 16:9 Microsoft PowerPoint with 22 main slides and 8-10 appendix slides.
- Every main slide must have speaker notes, timing, a key message, a transition, and an overclaim warning where relevant.
- Use only thesis/repository evidence and actual application screenshots; do not use stock imagery.
- Main-slide body text must be at least 20 pt; titles must be 28-34 pt.
- Use Arial, white/light-gray backgrounds, charcoal text, deep teal methodology accents, red security accents, amber performance accents, and green verified-outcome accents.
- Distinguish the original Codex 5.4 study, the normalized GPT-5.4/GPT-5.5 comparison, and the new-API v2 controlled retest.
- Do not declare an overall new-API v2 winner because a valid GPT-5.4 JMeter remediation candidate does not exist.
- Preserve every existing thesis and report file unchanged.

## Review Focus

- A missing or renamed evidence image must fail validation with its exact expected path, rather than producing a blank slide.
- A metric changed in the content model must fail the source-evidence assertion when it no longer matches the approved report values.
- A main slide without speaker notes, timing, key message, or transition must fail package validation.
- A script whose main-slide timing exceeds 28 minutes must fail validation; a script below 25 minutes must emit an under-duration warning.
- A PowerPoint or guide containing clipped text, placeholder tokens, empty charts, or an unrendered screenshot must not be delivered.

---

### Task 1: Evidence Content Model

**Files:**
- Create: `scripts/defense/defense_content.json`
- Create: `scripts/defense/tests/test_defense_content.py`

**Interfaces:**
- Consumes: final-report chapter text and Tables 3.1-3.2, 4.2, 4.7-4.12; repository images under `Document/outputs/web-app-evidence/` and `Document/paper/figures/`.
- Produces: JSON object with `metadata`, `theme`, `sources`, `slides`, `appendix`, `questions`, and `rehearsal` keys. Every slide object exposes `id`, `title`, `section`, `durationSeconds`, `keyMessage`, `visibleContent`, `speakerNotes`, `transition`, `overclaimWarning`, `evidenceRefs`, and `visual`.

- [ ] **Step 1: Write the failing content-contract tests**

```python
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
CONTENT = ROOT / "scripts" / "defense" / "defense_content.json"

class DefenseContentTests(unittest.TestCase):
    def setUp(self):
        self.data = json.loads(CONTENT.read_text(encoding="utf-8"))

    def test_main_slide_contract_and_timing(self):
        slides = self.data["slides"]
        self.assertEqual(22, len(slides))
        self.assertLessEqual(sum(s["durationSeconds"] for s in slides), 1680)
        self.assertGreaterEqual(sum(s["durationSeconds"] for s in slides), 1500)
        for slide in slides:
            for key in ("speakerNotes", "keyMessage", "transition", "evidenceRefs"):
                self.assertTrue(slide[key], f"{slide['id']} missing {key}")

    def test_required_evidence_values(self):
        metrics = self.data["sources"]["approvedMetrics"]
        self.assertEqual([28, 0], metrics["originalSonarRetainedFindings"])
        self.assertEqual([24, 229, 23], metrics["modelComparisonP50P95Ms"])
        self.assertEqual([4509, 2594, 2482], metrics["modelComparisonSpikeP95Ms"])
        self.assertEqual([0, 0], metrics["v2FinalSonarIssues"])
        self.assertEqual([12, 12], metrics["v2ZapVerifiedAlerts"])

    def test_asset_paths_exist(self):
        for relative in self.data["sources"]["assetPaths"]:
            self.assertTrue((ROOT / relative).is_file(), relative)

if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the test and confirm the missing content model fails**

Run: `python scripts/defense/tests/test_defense_content.py -v`

Expected: FAIL because `scripts/defense/defense_content.json` does not exist.

- [ ] **Step 3: Create the complete evidence model**

Populate all 22 main slides and 10 appendix slides specified in the design. Include approximately 30 committee questions divided among chair, methodology, security, performance, and devil's-advocate perspectives. Store both a concise answer and a deeper follow-up answer for each question. Include exact report-page/table references, repository asset paths, and the approved values for SonarQube, ZAP, JMeter, patch size, public tests, and new-API v2.

The metadata block must use:

```json
{
  "title": "Improving Security and Performance of Financial RESTful APIs Using ChatGPT in ASP.NET Core",
  "student": "Zaw Ye Htut Ko",
  "studentId": "G6519692",
  "degree": "Master of Science in Information Technology",
  "advisor": "Assistant Professor Dr. Darun Kesrarat",
  "defenseLabel": "Final Thesis Defense",
  "dateLabel": "September 2026"
}
```

- [ ] **Step 4: Run content tests**

Run: `python scripts/defense/tests/test_defense_content.py -v`

Expected: PASS with 22 main slides, 10 appendix slides, 25-28 minutes of main-slide notes, approximately 30 questions, and all source assets present.

- [ ] **Step 5: Commit the evidence model**

```powershell
git add scripts/defense/defense_content.json scripts/defense/tests/test_defense_content.py
git commit -m "docs: define defense evidence and narrative"
```

### Task 2: PowerPoint Builder and Main Defense Deck

**Files:**
- Create: `scripts/defense/build_defense_presentation.js`
- Create: `scripts/defense/presentation_theme.js`
- Create: `scripts/defense/tests/test_presentation_package.py`
- Create: `Document/outputs/final-defense/G6519692_Zaw_Ye_Htut_Ko_Final_Thesis_Defense.pptx`

**Interfaces:**
- Consumes: `defense_content.json`, actual PNG evidence assets, and the exported theme constants `COLORS`, `FONTS`, `LAYOUT`, and `SLIDE_SIZE`.
- Produces: `buildDeck(content, outputPath): Promise<void>` and an editable PPTX with native text, shapes, charts, images, and notes.

- [ ] **Step 1: Write the failing PPTX package test**

```python
import unittest
import zipfile
from pathlib import Path
from xml.etree import ElementTree as ET

ROOT = Path(__file__).resolve().parents[3]
PPTX = ROOT / "Document" / "outputs" / "final-defense" / "G6519692_Zaw_Ye_Htut_Ko_Final_Thesis_Defense.pptx"

class PresentationPackageTests(unittest.TestCase):
    def test_slide_and_notes_counts(self):
        with zipfile.ZipFile(PPTX) as archive:
            slides = [n for n in archive.namelist() if n.startswith("ppt/slides/slide") and n.endswith(".xml")]
            notes = [n for n in archive.namelist() if n.startswith("ppt/notesSlides/notesSlide") and n.endswith(".xml")]
            self.assertEqual(32, len(slides))
            self.assertGreaterEqual(len(notes), 22)

    def test_no_placeholder_tokens(self):
        with zipfile.ZipFile(PPTX) as archive:
            text = "".join(archive.read(n).decode("utf-8", "ignore") for n in archive.namelist() if n.endswith(".xml"))
        for forbidden in ("T" + "BD", "TO" + "DO", "Lorem " + "ipsum", "Click to " + "add"):
            self.assertNotIn(forbidden, text)

if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the package test and confirm the missing PPTX fails**

Run: `python scripts/defense/tests/test_presentation_package.py -v`

Expected: FAIL because the PPTX does not exist.

- [ ] **Step 3: Implement the theme and reusable slide primitives**

`presentation_theme.js` must export the exact palette, dimensions, and typography. `build_defense_presentation.js` must implement focused helpers:

```javascript
function addFrame(slide, number, section) {}
function addTitle(slide, title, kicker) {}
function addMetric(slide, value, label, x, y, color) {}
function addEvidenceTag(slide, text, x, y) {}
function addImageContain(slide, path, x, y, w, h) {}
function addSourceFooter(slide, evidenceRefs) {}
function addSpeakerNotes(slide, slideModel) {}
async function buildDeck(content, outputPath) {}
```

Use `slide.addNotes()` for notes. Use native PowerPoint charts for numeric comparisons. Use Sharp only to inspect or crop repository images without modifying their originals.

- [ ] **Step 4: Implement slides 1-11**

Create the title, roadmap, problem, gap, research questions, system scope, branch-isolation design, four-phase workflow, environment/dataset, evaluation gates, and human-in-the-loop slides. Keep visible text concise and move explanation into notes.

- [ ] **Step 5: Implement slides 12-22**

Create the SonarQube, ZAP, JMeter design/results, integrity verification, web application evidence, model comparison, new-API v2, contributions, limitations, and conclusion slides. Use report-backed values only and show the JMeter and model-comparison caveats directly on the relevant slides.

- [ ] **Step 6: Implement appendix slides 23-32**

Add branch provenance, endpoint/role coverage, full tool metrics, patch/test evidence, new-API v2 details, threats to validity, prompt/human-effort traceability, and references. Appendix slides may use 16-18 pt table text but must remain readable at 100% zoom.

- [ ] **Step 7: Generate and test the deck**

Run:

```powershell
$env:NODE_PATH='C:\Users\Asus\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\node_modules'
node scripts/defense/build_defense_presentation.js
python scripts/defense/tests/test_presentation_package.py -v
```

Expected: PPTX is generated, contains 32 slides, includes notes on all 22 main slides, contains no placeholder tokens, and passes ZIP/XML parsing.

- [ ] **Step 8: Commit the PowerPoint builder and generated deck**

```powershell
git add scripts/defense/build_defense_presentation.js scripts/defense/presentation_theme.js scripts/defense/tests/test_presentation_package.py Document/outputs/final-defense/G6519692_Zaw_Ye_Htut_Ko_Final_Thesis_Defense.pptx
git commit -m "feat: build final thesis defense deck"
```

### Task 3: Defense Preparation Guide

**Files:**
- Create: `scripts/defense/build_defense_guide.py`
- Create: `scripts/defense/tests/test_preparation_guide.py`
- Create: `Document/outputs/final-defense/G6519692_Zaw_Ye_Htut_Ko_Defense_Preparation_Guide.docx`

**Interfaces:**
- Consumes: the same `defense_content.json` used by the PowerPoint builder.
- Produces: `build_guide(content: dict, output_path: Path) -> None` and a DOCX with slide-by-slide script, questions and answers, rehearsal schedule, and final-day checklist.

- [ ] **Step 1: Write the failing guide test**

```python
import unittest
from pathlib import Path
from docx import Document

ROOT = Path(__file__).resolve().parents[3]
GUIDE = ROOT / "Document" / "outputs" / "final-defense" / "G6519692_Zaw_Ye_Htut_Ko_Defense_Preparation_Guide.docx"

class PreparationGuideTests(unittest.TestCase):
    def test_required_sections_and_question_count(self):
        doc = Document(GUIDE)
        text = "\n".join(p.text for p in doc.paragraphs)
        for heading in ("Presentation Timing Map", "Slide-by-Slide Script", "Professor Question Bank", "Rehearsal Plan", "Final-Day Checklist"):
            self.assertIn(heading, text)
        self.assertGreaterEqual(text.count("Short answer:"), 30)
        self.assertGreaterEqual(text.count("Follow-up answer:"), 30)

if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the guide test and confirm the missing DOCX fails**

Run: `python scripts/defense/tests/test_preparation_guide.py -v`

Expected: FAIL because the DOCX does not exist.

- [ ] **Step 3: Implement the preparation guide**

Use Letter page size, one-inch margins, Arial 11 pt body text, black headings, and restrained colored callouts. Include:

- A slide timing table totaling 25-28 minutes
- Visible slide takeaway plus full spoken script for slides 1-22
- One transition sentence per slide
- One recovery sentence per section
- Approximately 30 committee questions with short and follow-up answers
- Cross-references to the relevant main or appendix slide
- A three-run rehearsal plan: content, timing, and hostile-question practice
- A final-day checklist covering PPTX, PDF, offline files, screen mode, fonts, and backup storage

- [ ] **Step 4: Generate and test the guide**

Run:

```powershell
python scripts/defense/build_defense_guide.py
python scripts/defense/tests/test_preparation_guide.py -v
```

Expected: DOCX opens successfully, contains all required sections, and includes at least 30 complete question-answer pairs.

- [ ] **Step 5: Validate the DOCX package**

Run:

```powershell
$env:PYTHONUTF8='1'
$env:PYTHONIOENCODING='utf-8'
python .agents/skills/docx/scripts/office/validate.py Document/outputs/final-defense/G6519692_Zaw_Ye_Htut_Ko_Defense_Preparation_Guide.docx -v
```

Expected: all XML and relationship validations pass with no new XSD errors.

- [ ] **Step 6: Commit the guide builder and guide**

```powershell
git add scripts/defense/build_defense_guide.py scripts/defense/tests/test_preparation_guide.py Document/outputs/final-defense/G6519692_Zaw_Ye_Htut_Ko_Defense_Preparation_Guide.docx
git commit -m "docs: add thesis defense preparation guide"
```

### Task 4: Office Export and Structural Validation

**Files:**
- Create: `scripts/defense/export_defense_package.ps1`
- Create: `scripts/defense/validate_defense_package.py`
- Create: `Document/outputs/final-defense/G6519692_Zaw_Ye_Htut_Ko_Final_Thesis_Defense.pdf`
- Create: `Document/outputs/final-defense/G6519692_Zaw_Ye_Htut_Ko_Defense_Preparation_Guide.pdf`

**Interfaces:**
- Consumes: generated PPTX and DOCX.
- Produces: two PDFs and a validator exit status that proves file existence, page counts, slide/note counts, main-script timing, and absence of placeholder text.

- [ ] **Step 1: Write structural-validation assertions**

Implement `validate_defense_package.py` with these checks:

```python
assert pptx_slide_count == 32
assert pptx_notes_count >= 22
assert presentation_pdf_pages == 32
assert guide_pdf_pages >= 20
assert 1500 <= main_script_seconds <= 1680
assert question_count >= 30
assert not placeholder_hits
```

- [ ] **Step 2: Run validation and confirm PDFs are initially missing**

Run: `python scripts/defense/validate_defense_package.py`

Expected: FAIL listing both missing PDF paths.

- [ ] **Step 3: Implement native Office export**

`export_defense_package.ps1` must create hidden, isolated PowerPoint and Word application instances, refuse to reuse an instance containing open user documents, export the PPTX and DOCX to their matching PDFs, close only documents it opened, and release COM objects in `finally` blocks.

- [ ] **Step 4: Export and validate**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/defense/export_defense_package.ps1
python scripts/defense/validate_defense_package.py
```

Expected: both PDFs exist, presentation PDF has 32 pages, guide PDF is readable, notes and timing checks pass, and no placeholder text is found.

- [ ] **Step 5: Commit export and validation artifacts**

```powershell
git add scripts/defense/export_defense_package.ps1 scripts/defense/validate_defense_package.py Document/outputs/final-defense/G6519692_Zaw_Ye_Htut_Ko_Final_Thesis_Defense.pdf Document/outputs/final-defense/G6519692_Zaw_Ye_Htut_Ko_Defense_Preparation_Guide.pdf
git commit -m "build: export and validate defense package"
```

### Task 5: Rendered Visual QA and Final Corrections

**Files:**
- Modify: `scripts/defense/build_defense_presentation.js`
- Modify: `scripts/defense/defense_content.json`
- Modify: `scripts/defense/build_defense_guide.py`
- Regenerate: all four deliverables under `Document/outputs/final-defense/`
- Create temporarily: `tmp/pdfs/final-defense/slides/*.png`
- Create temporarily: `tmp/pdfs/final-defense/guide/*.png`

**Interfaces:**
- Consumes: rendered PDFs and validation results.
- Produces: visually corrected PPTX/PDF and guide DOCX/PDF with no overlap, clipping, blank assets, unreadable tables, or weak contrast.

- [ ] **Step 1: Render every presentation and guide page**

Run:

```powershell
New-Item -ItemType Directory -Path tmp/pdfs/final-defense/slides,tmp/pdfs/final-defense/guide -Force | Out-Null
pdftoppm -png -r 120 Document/outputs/final-defense/G6519692_Zaw_Ye_Htut_Ko_Final_Thesis_Defense.pdf tmp/pdfs/final-defense/slides/slide
pdftoppm -png -r 120 Document/outputs/final-defense/G6519692_Zaw_Ye_Htut_Ko_Defense_Preparation_Guide.pdf tmp/pdfs/final-defense/guide/page
```

Expected: 32 slide images plus one image for every guide page.

- [ ] **Step 2: Create contact sheets and inspect all pages**

Use Sharp to assemble readable contact sheets at four slides/pages per row. Inspect titles, text wrapping, chart labels, image sharpness, table readability, footers, page numbers, and blank-space balance. Record every issue by slide or guide-page number.

- [ ] **Step 3: Correct every visual defect at its source**

Fix content length in `defense_content.json`, layout geometry in `build_defense_presentation.js`, and guide formatting in `build_defense_guide.py`. Do not patch the PDFs directly. Regenerate both Office files and PDFs after corrections.

- [ ] **Step 4: Run the complete fresh verification suite**

Run:

```powershell
python -m unittest discover -s scripts/defense/tests -v
$env:NODE_PATH='C:\Users\Asus\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\node_modules'
node scripts/defense/build_defense_presentation.js
python scripts/defense/build_defense_guide.py
powershell -ExecutionPolicy Bypass -File scripts/defense/export_defense_package.ps1
python scripts/defense/validate_defense_package.py
git diff --check
```

Expected: all tests pass, all four artifacts regenerate successfully, package validation passes, and `git diff --check` reports no whitespace errors.

- [ ] **Step 5: Re-render and perform final visual inspection**

Render all pages again after the last regeneration. Confirm that the final contact sheets show no clipping, overlap, blank images, unreadable charts, or malformed glyphs.

- [ ] **Step 6: Commit final visual corrections**

```powershell
git add scripts/defense Document/outputs/final-defense
git commit -m "fix: polish final thesis defense package"
```

## Completion Evidence

At handoff, report:

- Paths to the editable PPTX, presentation PDF, guide DOCX, and guide PDF
- Main slide count and appendix slide count
- Total planned speaking duration
- Number of professor questions and answer pairs
- Test, package-validation, and rendering results
- Any remaining presentation assumptions or evidence limitations
