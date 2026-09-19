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
        total_seconds = sum(slide["durationSeconds"] for slide in slides)
        self.assertGreaterEqual(total_seconds, 1500)
        self.assertLessEqual(total_seconds, 1680)
        for slide in slides:
            for key in (
                "speakerNotes",
                "keyMessage",
                "transition",
                "evidenceRefs",
                "visibleContent",
                "visual",
            ):
                self.assertTrue(slide[key], f"{slide['id']} missing {key}")

    def test_appendix_and_question_contract(self):
        self.assertEqual(10, len(self.data["appendix"]))
        self.assertGreaterEqual(len(self.data["questions"]), 30)
        perspectives = {question["perspective"] for question in self.data["questions"]}
        self.assertEqual(
            {"chair", "methodology", "security", "performance", "devilsAdvocate"},
            perspectives,
        )
        for question in self.data["questions"]:
            for key in ("question", "shortAnswer", "followUpAnswer", "slideRef", "caution"):
                self.assertTrue(question[key], f"Question {question['id']} missing {key}")

    def test_required_evidence_values(self):
        metrics = self.data["sources"]["approvedMetrics"]
        self.assertEqual([28, 0], metrics["originalSonarRetainedFindings"])
        self.assertEqual([24, 229, 23], metrics["modelComparisonP50P95Ms"])
        self.assertEqual([4509, 2594, 2482], metrics["modelComparisonSpikeP95Ms"])
        self.assertEqual([0, 0], metrics["v2FinalSonarIssues"])
        self.assertEqual([12, 12], metrics["v2ZapVerifiedAlerts"])
        self.assertEqual([120, 30000, 5000], metrics["seededDataset"])

    def test_asset_paths_exist(self):
        for relative_path in self.data["sources"]["assetPaths"]:
            self.assertTrue((ROOT / relative_path).is_file(), relative_path)

    def test_no_placeholder_language(self):
        serialized = json.dumps(self.data)
        forbidden = ("T" + "BD", "TO" + "DO", "Lorem " + "ipsum", "Click to " + "add")
        for token in forbidden:
            self.assertNotIn(token, serialized)

    def test_traceability_flow_uses_projector_safe_label(self):
        traceability = next(item for item in self.data["appendix"] if item["id"] == "A09")
        self.assertEqual("Tool rerun", traceability["visibleContent"]["flow"][-1])


if __name__ == "__main__":
    unittest.main()
