import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
SCRIPT = ROOT / "scripts" / "defense" / "export_defense_package.ps1"


class ExportScriptTests(unittest.TestCase):
    def test_existing_verified_pdfs_are_replaced_only_after_new_export(self):
        text = SCRIPT.read_text(encoding="utf-8")
        self.assertNotIn("Remove-ExistingOutput $pptPdfPath", text)
        self.assertNotIn("Remove-ExistingOutput $guidePdfPath", text)
        self.assertIn("$temporaryPresentationPdf", text)
        self.assertIn("Copy-Item -LiteralPath $temporaryPresentationPdf", text)
        self.assertIn("Copy-Item -LiteralPath $temporaryGuidePdf", text)

    def test_temporary_exports_are_cleaned_in_finally(self):
        text = SCRIPT.read_text(encoding="utf-8")
        self.assertIn("foreach ($temporaryOutput in @($temporaryPresentationPdf, $temporaryGuidePdf))", text)


if __name__ == "__main__":
    unittest.main()
