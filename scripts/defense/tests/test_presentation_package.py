import unittest
import zipfile
from pathlib import Path
import re


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


if __name__ == "__main__":
    unittest.main()
