import unittest
import zipfile
from pathlib import Path
import re
from xml.etree import ElementTree as ET


ROOT = Path(__file__).resolve().parents[3]
PPTX = (
    ROOT
    / "Document"
    / "outputs"
    / "final-defense"
    / "G6519692_Zaw_Ye_Htut_Ko_Final_Thesis_Defense.pptx"
)


class PresentationPackageTests(unittest.TestCase):
    def test_slide_and_notes_counts(self):
        with zipfile.ZipFile(PPTX) as archive:
            slides = [
                name
                for name in archive.namelist()
                if name.startswith("ppt/slides/slide") and name.endswith(".xml")
            ]
            notes = [
                name
                for name in archive.namelist()
                if name.startswith("ppt/notesSlides/notesSlide") and name.endswith(".xml")
            ]
            self.assertEqual(32, len(slides))
            self.assertGreaterEqual(len(notes), 22)

    def test_no_placeholder_tokens(self):
        with zipfile.ZipFile(PPTX) as archive:
            xml_text = "".join(
                archive.read(name).decode("utf-8", "ignore")
                for name in archive.namelist()
                if name.endswith(".xml")
            )
        forbidden = ("T" + "BD", "TO" + "DO", "Lorem " + "ipsum", "Click to " + "add")
        for token in forbidden:
            self.assertNotIn(token, xml_text)

    def test_all_evidence_images_are_embedded(self):
        with zipfile.ZipFile(PPTX) as archive:
            media = [name for name in archive.namelist() if name.startswith("ppt/media/")]
        self.assertGreaterEqual(len(media), 8)

    def test_shape_extents_are_never_negative(self):
        with zipfile.ZipFile(PPTX) as archive:
            for name in archive.namelist():
                if not (name.startswith("ppt/slides/slide") and name.endswith(".xml")):
                    continue
                xml_text = archive.read(name).decode("utf-8", "ignore")
                extents = re.findall(r'<a:ext cx="(-?\d+)" cy="(-?\d+)"', xml_text)
                negative = [value for value in extents if value[0].startswith("-") or value[1].startswith("-")]
                self.assertFalse(negative, f"{name} has negative extents: {negative}")

    def test_table_vertical_alignment_uses_valid_powerpoint_value(self):
        with zipfile.ZipFile(PPTX) as archive:
            slide_xml = "".join(
                archive.read(name).decode("utf-8", "ignore")
                for name in archive.namelist()
                if name.startswith("ppt/slides/slide") and name.endswith(".xml")
            )
        self.assertNotIn('anchor="mid"', slide_xml)

    def test_workflow_slide_uses_large_native_phase_labels(self):
        with zipfile.ZipFile(PPTX) as archive:
            slide = archive.read("ppt/slides/slide8.xml").decode("utf-8", "ignore")
        for label in ("Capture baseline", "Propose bounded fix", "Human review and tests", "Rerun and compare"):
            self.assertIn(label, slide)

    def test_chart_axis_does_not_scale_percentage_values_twice(self):
        with zipfile.ZipFile(PPTX) as archive:
            charts = "".join(
                archive.read(name).decode("utf-8", "ignore")
                for name in archive.namelist()
                if name.startswith("ppt/charts/chart") and name.endswith(".xml")
            )
        self.assertNotIn('formatCode="0%"', charts)

    def test_main_comparison_tables_use_projector_readable_text(self):
        namespace = {"a": "http://schemas.openxmlformats.org/drawingml/2006/main"}
        with zipfile.ZipFile(PPTX) as archive:
            for slide_number in (18, 19):
                root = ET.fromstring(archive.read(f"ppt/slides/slide{slide_number}.xml"))
                table = root.find(".//a:tbl", namespace)
                self.assertIsNotNone(table)
                sizes = [
                    int(node.get("sz"))
                    for node in table.findall(".//a:rPr", namespace)
                    if node.get("sz")
                ]
                self.assertTrue(sizes)
                self.assertGreaterEqual(min(sizes), 2000)
        with zipfile.ZipFile(PPTX) as archive:
            root = ET.fromstring(archive.read("ppt/slides/slide18.xml"))
        first_column = root.find(".//a:tblGrid/a:gridCol", namespace)
        self.assertIsNotNone(first_column)
        self.assertGreaterEqual(int(first_column.get("w")), 1645920)


if __name__ == "__main__":
    unittest.main()
