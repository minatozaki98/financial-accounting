# InCIT 2026 IEEE Submission Compliance Check

Sources checked:

- `Document/paper/incit2026-ieee-submission.tex`
- `Document/paper/incit2026-ieee-submission.docx`

## Format

- Uses IEEE conference mode: `\documentclass[conference]{IEEEtran}`.
- Keeps IEEE-style two-column LaTeX structure through `IEEEtran`.
- Keeps the paper as PDF-target source; InCIT requires PDF submission.
- Compiled successfully to `Document/paper/incit2026-ieee-submission.pdf` with Tectonic 0.16.9.
- Does not intentionally alter IEEE spacing, margins, font size, or layout commands.
- A Word/DOCX version was also generated with IEEE conference-style settings: Times New Roman, IEEE-style title/abstract/body sizing, US Letter page size, IEEE-style margins, and two-column body text.
- The compiled PDF is 6 pages, which is under the 8-page InCIT limit.

## Double-Anonymous Review

- Removed author names.
- Removed affiliations.
- Removed email address.
- Removed advisor name.
- Removed preprint/funding-style title footnote.
- Removed author-identifying DOCX document metadata.
- PDF text extraction found no hits for the author name, advisor name, affiliation, email username, advisor label, or preprint note.
- PDF metadata contains only the TeX toolchain creator/producer values.
- No author-revealing URLs were found in the paper body.
- Acknowledgment content is limited to non-identifying AI usage disclosure.

## Authorship Policy

- The review manuscript is anonymous, but EasyChair/submission metadata must still include the complete and final author list.
- Do not add authors after review unless the InCIT chair explicitly approves it.

## Plagiarism and Concurrent Submission

- Template boilerplate text was checked and not found in the new manuscript.
- Citation keys and bibliography entries are internally consistent: every cited key has a bibliography entry, and every bibliography entry is cited.
- This check does not certify plagiarism/similarity score. Use IEEE/Crossref Similarity Check, iThenticate, Turnitin, or the university plagiarism checker before submission.
- Do not submit this manuscript to any other venue while it is under InCIT 2026 review.
- If any text, table, figure, result, dataset, or prior idea is reused from another source, keep a citation next to that reused material.
- If any part comes from your own prior published work, cite it and disclose the relationship.

## AI Disclosure

- Added a non-identifying `Acknowledgment and AI Usage Disclosure` section.
- Identifies the AI system: ChatGPT (Codex 5.4).
- Identifies the affected sections: methodology, experiments, results, and discussion.
- Separates proofreading from substantive AI-assisted experimental patch generation.

## Remaining Manual Checks Before Submission

- Open the compiled PDF and visually confirm IEEE two-column layout, figure placement, table legibility, and no author identity in rendered text.
- Local automated Word-to-PDF conversion was attempted, but Microsoft Word's PDF export hung even on a one-paragraph test document. Export the generated DOCX manually from Word or compile the LaTeX source on Overleaf.
- Run a plagiarism/similarity checker and resolve any high-overlap passages.
- Upload the full author list in the submission system even though the PDF remains anonymous.
- Confirm no preprint uses the same title during the double-anonymous review period.
