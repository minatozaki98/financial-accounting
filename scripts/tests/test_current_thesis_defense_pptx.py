from __future__ import annotations

import re
import subprocess
import tempfile
import unittest
import json
from hashlib import sha256
from pathlib import Path
from zipfile import ZipFile

from pptx import Presentation


ROOT = Path(__file__).resolve().parents[2]
DECK = (
    ROOT
    / "Document"
    / "outputs"
    / "final-defense"
    / "G6519692_Zaw_Ye_Htut_Ko_Final_Thesis_Defense.pptx"
)


def slide_text(slide) -> str:
    return "\n".join(shape.text for shape in slide.shapes if shape.has_text_frame)


class CurrentThesisDefenseTests(unittest.TestCase):
    def test_fresh_zap_report_renders_the_scanned_http_site(self):
        renderer = ROOT / "scripts" / "phase4" / "generate-zap-detailed-report.ps1"
        cases = [
            ("baseline", "zap-api-fresh-before-20260922-184706.json", 1, 3),
            ("remediation", "zap-api-fresh-after-20260922-190653.json", 1, 0),
        ]
        with tempfile.TemporaryDirectory() as temp_dir:
            for role, name, medium, low in cases:
                source = ROOT / "docs" / "appendix" / "verification-runs" / "research" / "zap" / role / name
                output = Path(temp_dir) / f"{role}.html"
                subprocess.run(
                    ["pwsh", "-NoProfile", "-File", str(renderer), "-JsonPath", str(source), "-OutputPath", str(output)],
                    check=True, capture_output=True, text=True,
                )
                html = output.read_text(encoding="utf-8-sig")
                self.assertIn(f'<div class="card medium"><div>Medium Alerts</div><div class="num">{medium}</div>', html)
                self.assertIn(f'<div class="card low"><div>Low Alerts</div><div class="num">{low}</div>', html)

    def test_committee_notes_are_plain_and_point_to_evidence(self):
        deck = Presentation(DECK)
        self.assertEqual(45, len(deck.slides))
        opening = slide_text(deck.slides[1])
        self.assertIn("When is an AI suggestion an improvement?", opening)
        self.assertNotIn("17 to 0", opening)
        self.assertNotIn("Target not met", opening)
        self.assertNotIn("result first", deck.slides[1].notes_slide.notes_text_frame.text.lower())
        self.assertIn("three different user counts", deck.slides[3].notes_slide.notes_text_frame.text)
        self.assertIn("Local", slide_text(deck.slides[7]))
        for index in range(45):
            self.assertNotIn("codex", slide_text(deck.slides[index]).lower())
            self.assertNotIn("codex", deck.slides[index].notes_slide.notes_text_frame.text.lower())
        for index in range(27):
            notes = deck.slides[index].notes_slide.notes_text_frame.text
            self.assertIn("SHOW IF ASKED:", notes, f"slide {index + 1}")
            self.assertIn("APPENDIX:", notes, f"slide {index + 1}")
            self.assertNotIn("backup slide 27", notes, f"stale backup reference on slide {index + 1}")

        dataset_rows = [
            " | ".join(cell.text for cell in row.cells)
            for shape in deck.slides[27].shapes if shape.has_table
            for row in shape.table.rows
        ]
        self.assertTrue(any("120 accounts" in row and "branch-verification.json" in row for row in dataset_rows))
        self.assertIn("Appendix H", slide_text(deck.slides[8]))
        self.assertNotIn("commit", slide_text(deck.slides[5]).lower())
        self.assertIsNone(re.search(r"\bcommits?\b", deck.slides[5].notes_slide.notes_text_frame.text, re.I))
        research_design = slide_text(deck.slides[4])
        self.assertIn("Applied case study", research_design)
        self.assertIn("Why ChatGPT?", research_design)
        self.assertIn("not a new algorithm", research_design.lower())
        self.assertIn("widely used", research_design)
        self.assertIn("not uniquely capable", research_design)
        self.assertIn("not comparing AI assistants", deck.slides[4].notes_slide.notes_text_frame.text)
        self.assertIn("Claude and Copilot", deck.slides[4].notes_slide.notes_text_frame.text)
        self.assertIn("I cannot claim ChatGPT is better", deck.slides[4].notes_slide.notes_text_frame.text)
        self.assertIn("I reviewed", deck.slides[10].notes_slide.notes_text_frame.text)
        self.assertIn("Start with evidence", slide_text(deck.slides[10]))
        self.assertIn("Review the proposed fix", slide_text(deck.slides[10]))
        self.assertIn("Verify the outcome", slide_text(deck.slides[10]))
        self.assertIn("Read this diagram from left to right", deck.slides[10].notes_slide.notes_text_frame.text)
        self.assertIn("decision paths through code", deck.slides[12].notes_slide.notes_text_frame.text)
        sonar_explanation = slide_text(deck.slides[12])
        self.assertIn("PRIMARY OUTCOME", sonar_explanation)
        self.assertIn("Coverage 74.4% → 74.3%", sonar_explanation)
        self.assertIn("Bugs / Vulnerabilities 0 / 0 → 0 / 0", sonar_explanation)
        self.assertIn("Duplicate density 0.0% → 0.0%", sonar_explanation)
        self.assertIn("Complexity 886 → 889", sonar_explanation)
        self.assertIn("The right-hand metrics are controls, not gains", deck.slides[12].notes_slide.notes_text_frame.text)
        self.assertIn("all 17 were classified as code smells", deck.slides[12].notes_slide.notes_text_frame.text)
        self.assertIn("cannot identify the exact cause", deck.slides[12].notes_slide.notes_text_frame.text)
        self.assertIn("17 unique issues → 0", slide_text(deck.slides[13]))
        self.assertIn("JournalEntryQueryDto", slide_text(deck.slides[14]))
        self.assertIn("RunAsync", slide_text(deck.slides[14]))
        self.assertIn("PASSIVE SCAN", slide_text(deck.slides[15]))
        self.assertIn("AUTHENTICATED API SCAN", slide_text(deck.slides[16]))
        self.assertIn("HTTP Only Site", slide_text(deck.slides[16]))
        self.assertIn("outside this study's measured scope", deck.slides[18].notes_slide.notes_text_frame.text)
        self.assertIn("GET /reports/account-ledger", slide_text(deck.slides[22]))
        self.assertIn("SOAK p95 LOWER", slide_text(deck.slides[40]))
        self.assertIn("SPIKE p95 LOWER", slide_text(deck.slides[41]))
        workload_notes = deck.slides[21].notes_slide.notes_text_frame.text
        self.assertIn("Soak means repeated traffic over time", workload_notes)
        self.assertIn("Spike means many users arrive quickly", workload_notes)
        self.assertIn("not direct proof of no soak drift or spike recovery", workload_notes)
        self.assertIn("not load-test data", slide_text(deck.slides[42]).lower())
        limitation = slide_text(deck.slides[25])
        self.assertIn("Limitations and next validation", limitation)
        self.assertIn("one api", limitation.lower())
        self.assertIn("CPU/RAM", limitation)
        self.assertIn("HTTPS", limitation)
        self.assertIn("repeat", deck.slides[25].notes_slide.notes_text_frame.text.lower())
        self.assertIn("Appendix N", deck.slides[25].notes_slide.notes_text_frame.text)
        self.assertIn("The strongest contribution", slide_text(deck.slides[26]))

    def test_deck_carries_fresh_results_without_historical_zap_captures(self):
        with ZipFile(DECK) as package:
            self.assertIsNone(package.testzip())
            media = [name for name in package.namelist() if name.startswith("ppt/media/")]
            self.assertGreaterEqual(len(media), 18)
            embedded_hashes = {sha256(package.read(name)).hexdigest() for name in media}
        manifest = json.loads(
            (ROOT / "docs" / "appendix" / "dashboard-capture-manifest.json").read_text(encoding="utf-8-sig")
        )
        for capture in manifest["captures"]:
            source = ROOT / "docs" / "appendix" / "dashboards" / capture["imagePath"]
            digest = sha256(source.read_bytes()).hexdigest()
            if capture["evidenceClassification"] == "fresh-reproduction":
                self.assertIn(digest, embedded_hashes, capture["imagePath"])
            elif capture["tool"] == "zap":
                self.assertNotIn(digest, embedded_hashes, capture["imagePath"])
        credential_screen = ROOT / "Document" / "outputs" / "web-app-evidence" / "01-login.png"
        self.assertNotIn(sha256(credential_screen.read_bytes()).hexdigest(), embedded_hashes)

        for name in (
            "zap-fresh-passive-before-summary.png",
            "zap-fresh-passive-after-summary.png",
            "zap-fresh-api-before-summary.png",
            "zap-fresh-api-after-summary.png",
        ):
            capture = ROOT / "docs" / "appendix" / "dashboards" / "zap" / name
            self.assertIn(sha256(capture.read_bytes()).hexdigest(), embedded_hashes, name)

        deck = Presentation(DECK)
        self.assertEqual(45, len(deck.slides))
        self.assertIn("When is an AI suggestion an improvement?", slide_text(deck.slides[1]))
        self.assertNotIn("17 to 0", slide_text(deck.slides[1]))
        self.assertIn("raw API Medium remains", slide_text(deck.slides[15]))
        self.assertIn("rendered from the current ZAP scan JSON", slide_text(deck.slides[15]))
        self.assertIn("rendered from the current ZAP scan JSON", slide_text(deck.slides[16]))
        self.assertIn("I am showing the passive scan before and after", deck.slides[15].notes_slide.notes_text_frame.text)
        self.assertIn("I am showing the signed-in API scan before and after", deck.slides[16].notes_slide.notes_text_frame.text)
        self.assertIn("1,146.9", slide_text(deck.slides[18]))
        self.assertIn("1,547.95", slide_text(deck.slides[18]))
        self.assertIn("NOT MET:", slide_text(deck.slides[18]))
        self.assertIn("100 VU", slide_text(deck.slides[19]))
        self.assertIn("500 VU", slide_text(deck.slides[20]))
        self.assertNotIn("FAIL", "\n".join(slide_text(deck.slides[index]) for index in range(27)))
        self.assertIn("remediation core gate FAIL", slide_text(deck.slides[31]))
        self.assertIn("CPU/RAM", slide_text(deck.slides[25]))
        all_visible = "\n".join(slide_text(slide) for slide in deck.slides)
        self.assertNotIn("GPT-5.5", all_visible)
        self.assertNotIn("28 to 0", all_visible)
        self.assertNotIn("September", all_visible)
        self.assertNotIn("March", all_visible)
        self.assertNotIn("historical dashboard capture", all_visible.lower())

        times = []
        for index in range(27):
            slide = deck.slides[index]
            notes = slide.notes_slide.notes_text_frame.text
            self.assertNotIn("September", notes)
            self.assertNotIn("March", notes)
            self.assertIn("KEY MESSAGE:", notes)
            self.assertIn("SCRIPT:", notes)
            self.assertIn("SOURCE:", notes)
            match = re.search(r"TIMING: (\d+) seconds", notes)
            self.assertIsNotNone(match)
            times.append(int(match.group(1)))
        self.assertLessEqual(sum(times), 32 * 60)


if __name__ == "__main__":
    unittest.main()
