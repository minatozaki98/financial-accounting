from __future__ import annotations

import importlib.util
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from docx import Document


ROOT = Path(__file__).resolve().parents[2]


def load_module(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Could not load {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


appendix_builder = load_module(
    "appendix_builder", ROOT / "scripts" / "add_thesis_appendices_to_full_report.py"
)
report_formatter = load_module(
    "report_formatter", ROOT / "scripts" / "format_final_report_docx.py"
)
fresh_result_updater = load_module(
    "fresh_result_updater", ROOT / "scripts" / "update_full_report_fresh_results.py"
)


class ThesisAppendixReportTests(unittest.TestCase):
    def test_fresh_result_inputs_match_versioned_machine_readable_evidence(self):
        evidence = fresh_result_updater.load_fresh_evidence(ROOT)

        self.assertEqual(17, evidence["sonar"]["baseline_issues"])
        self.assertEqual(0, evidence["sonar"]["remediation_issues"])
        self.assertEqual("74.4", evidence["sonar"]["baseline_coverage"])
        self.assertEqual("74.3", evidence["sonar"]["remediation_coverage"])
        self.assertEqual(1, evidence["zap"]["remediation_api_medium"])
        self.assertEqual("FAIL", evidence["jmeter"]["remediation_gate"])
        self.assertEqual(1146.9, evidence["jmeter"]["remediation_profiles"]["p100"]["p95Ms"])

    def test_report_update_replaces_primary_historical_claims_but_preserves_appendix_history(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "report.docx"
            path.write_bytes(appendix_builder.DEFAULT_REPORT.read_bytes())

            fresh_result_updater.update_report(path, ROOT)

            doc = Document(path)
            paragraphs = [p.text for p in doc.paragraphs]
            appendix_index = paragraphs.index("APPENDICES")
            primary_text = "\n".join(paragraphs[:appendix_index])
            appendix_text = "\n".join(paragraphs[appendix_index:])
            self.assertIn("17 to 0", primary_text)
            self.assertIn("74.4% to 74.3%", primary_text)
            self.assertIn("remediation core gate failed", primary_text)
            self.assertNotIn("retained C# findings from 28 to 0", primary_text)
            self.assertIn("Historical result: 28 retained findings to 0", appendix_text)

            table = fresh_result_updater.find_table_by_header(
                doc, ("Metric", "Baseline", "After fixes", "Interpretation")
            )
            rows = [[cell.text for cell in row.cells] for row in table.rows]
            self.assertIn(["Total unique issues", "17", "0", "All fresh baseline issues closed"], rows)
            self.assertIn(["Coverage", "74.4%", "74.3%", "Decreased by 0.1 percentage points"], rows)

    def test_dashboard_page_breaks_keep_tool_heading_with_first_dashboard(self):
        self.assertFalse(
            appendix_builder.dashboard_heading_page_break(3, "SonarQube Dashboards", False)
        )
        self.assertTrue(
            appendix_builder.dashboard_heading_page_break(3, "OWASP ZAP Dashboards", False)
        )
        self.assertFalse(
            appendix_builder.dashboard_heading_page_break(4, "baseline-overview", True)
        )
        self.assertTrue(
            appendix_builder.dashboard_heading_page_break(4, "baseline-issues", False)
        )

    def test_builder_creates_template_independent_bullet_style(self):
        doc = Document(appendix_builder.DEFAULT_REPORT)
        style_name = appendix_builder.ensure_bullet_style(doc)
        paragraph = appendix_builder.add_body_paragraph(doc, "Repository entry", style=style_name)

        self.assertEqual("Appendix Bullet", paragraph.style.name)
        self.assertEqual(
            0.25,
            round(doc.styles[style_name].paragraph_format.left_indent.inches, 2),
        )

    def test_rebuild_references_preserves_appendices_and_places_references_before_them(self):
        doc = Document()
        doc.add_paragraph("REFERENCES", style="Heading 1")
        doc.add_paragraph("stale reference")
        doc.add_paragraph("APPENDICES", style="Heading 1")
        doc.add_paragraph("Appendix A - Repository and Environment", style="Heading 1")
        doc.add_paragraph("appendix body")

        report_formatter.rebuild_references(doc)

        texts = [report_formatter.normalized_text(p) for p in doc.paragraphs]
        self.assertNotIn("stale reference", texts)
        self.assertIn("appendix body", texts)
        reference_index = texts.index("REFERENCES")
        appendix_index = texts.index("APPENDICES")
        self.assertGreater(appendix_index, reference_index + 1)
        self.assertTrue(any("GPTutor" in text for text in texts[reference_index:appendix_index]))

    def test_lists_only_refresh_does_not_require_legacy_section_3_1_heading(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "report.docx"
            doc = Document()
            doc.add_paragraph("Table of Contents")
            doc.add_paragraph("List of Acronyms", style="Heading 1")
            doc.add_paragraph("API - Application Programming Interface")
            doc.add_paragraph("Chapter 1 - Introduction", style="Heading 1")
            doc.add_paragraph("APPENDICES", style="Heading 1")
            doc.add_paragraph("Appendix A - Repository and Environment", style="Heading 1")
            doc.add_paragraph("appendix body")
            doc.save(path)

            with (
                patch.object(report_formatter, "export_pdf", return_value=path.with_suffix(".pdf")),
                patch.object(report_formatter, "rendered_page_numbers", return_value={}),
            ):
                report_formatter.refresh_generated_lists(path)

            texts = [p.text for p in Document(path).paragraphs]
            self.assertIn("APPENDICES", texts)
            self.assertIn("Appendix A - Repository and Environment", texts)
            self.assertIn("appendix body", texts)

    def test_word_page_selection_prefers_body_over_generated_list_entry(self):
        self.assertEqual(
            95,
            report_formatter.select_word_page(
                "Appendix A - Repository and Environment", [5, 95]
            ),
        )
        self.assertEqual(3, report_formatter.select_word_page("Abstract", [3, 12]))

    def test_cross_references_are_idempotent(self):
        doc = Document()
        for heading, sentence in appendix_builder.CROSS_REFERENCES.items():
            doc.add_paragraph(heading, style="Heading 2")
            doc.add_paragraph("Section body.")

        appendix_builder.add_cross_references(doc)
        appendix_builder.add_cross_references(doc)

        text = "\n".join(p.text for p in doc.paragraphs)
        for sentence in appendix_builder.CROSS_REFERENCES.values():
            self.assertEqual(1, text.count(sentence))

    def test_cross_reference_targets_normal_prose_not_a_trailing_caption(self):
        doc = Document()
        heading = "3.1.1 Testing Environment and Reproducibility"
        sentence = appendix_builder.CROSS_REFERENCES[heading]
        prose = None
        caption = None
        for current_heading in appendix_builder.CROSS_REFERENCES:
            doc.add_paragraph(current_heading, style="Heading 3")
            body = doc.add_paragraph("Methodology body.", style="Normal")
            if current_heading == heading:
                prose = body
                caption = doc.add_paragraph("Table 3.7. Evidence table.", style="Caption")

        appendix_builder.add_cross_references(doc)

        self.assertIsNotNone(prose)
        self.assertIsNotNone(caption)
        self.assertIn(sentence, prose.text)
        self.assertNotIn(sentence, caption.text)

    def test_existing_appendix_tail_is_replaced_without_removing_section_properties(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "report.docx"
            doc = Document()
            doc.add_paragraph("REFERENCES", style="Heading 1")
            doc.add_paragraph("reference body")
            doc.add_paragraph("APPENDICES", style="Heading 1")
            doc.add_paragraph("old appendix body")
            appendix_builder.remove_existing_appendices(doc)
            doc.save(path)

            reopened = Document(path)
            texts = [p.text for p in reopened.paragraphs]
            self.assertIn("reference body", texts)
            self.assertNotIn("APPENDICES", texts)
            self.assertNotIn("old appendix body", texts)
            self.assertIsNotNone(reopened._element.body.sectPr)

    def test_controlled_source_contains_explanations_without_embedded_demo_password(self):
        source = (ROOT / "docs" / "appendix" / "thesis-appendix-source-code-and-results.md").read_text(
            encoding="utf-8"
        )
        self.assertEqual(5, source.count("**Explanation.**"))
        self.assertIn("### C.1 Role-Based Authorization", source)
        self.assertIn("### C.5 Deterministic Research-Data Parameters", source)
        self.assertNotIn("Admin@123", source)


if __name__ == "__main__":
    unittest.main()
