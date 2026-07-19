# IEEE Word Conference Template Format Spec

Source template: `C:\Users\Asus\Downloads\conference-template-letter.docx`

## Document Container

- DOCX namespace: Strict OOXML, `http://purl.oclc.org/ooxml/wordprocessingml/main`
- Paper size: US Letter
- Page width: 8.5 in (`612pt`)
- Page height: 11.0 in (`792pt`)
- Orientation: portrait

## Page Margins

Main template margins:

- Top: 0.75 in (`54pt`)
- Bottom: 1.0 in (`72pt`)
- Left: approximately 0.62 in (`44.65pt`)
- Right: approximately 0.62 in (`44.65pt`)
- Header: 0.5 in (`36pt`)
- Footer: 0.5 in (`36pt`)
- Gutter: 0

Two-column body section uses nearly the same side margins:

- Left: approximately 0.63 in (`45.35pt`)
- Right: approximately 0.63 in (`45.35pt`)

## Columns

The template uses multiple continuous sections:

- Title/top matter: 1 column
- Author blocks: 4 columns, 0.15 in (`10.80pt`) column spacing
- Main body: 2 columns, 0.25 in (`18pt`) column spacing
- Some final/template-note material switches back to 1 column

For the paper body, apply:

- 2 equal columns
- Column spacing: 0.25 in (`18pt`)

## Font Defaults

Default Latin font:

- Times New Roman

Default East Asian font:

- SimSun

Other fonts listed in the template font table:

- Symbol
- Times New Roman
- Courier New
- Wingdings
- SimSun
- MS Mincho
- NimbusRomNo9L-Regu
- Calibri Light
- Calibri

## Core Styles

### Paper Title

- Style ID: `papertitle`
- Name: `paper title`
- Font size: 24 pt
- Alignment: center
- Spacing after: 6 pt
- East Asian font override: MS Mincho

### Paper Subtitle

- Style ID: `papersubtitle`
- Name: `paper subtitle`
- Font size: 14 pt
- Alignment: center
- Spacing after: 6 pt
- East Asian font override: MS Mincho

### Author

- Style ID: `Author`
- Font size: 11 pt
- Alignment: center
- Spacing before: 18 pt
- Spacing after: 2 pt

### Abstract

- Style ID: `Abstract`
- Font size: 9 pt
- Bold: true
- Alignment: justified
- First-line indent: 13.60 pt
- Spacing after: 10 pt

### Keywords

- Style ID: `Keywords`
- Based on: `Abstract`
- Italic: true
- First-line indent: 13.70 pt
- Spacing after: 6 pt

### Body Text

- Style ID: `BodyText`
- Based on: `Normal`
- Font: inherited Times New Roman
- Effective font size: 10 pt in template body content
- Alignment: justified
- First-line indent: 14.40 pt
- Spacing after: 6 pt
- Line setting: 11.40 pt, auto

### Heading 1

- Style ID: `Heading1`
- Based on: `Normal`
- Spacing before: 8 pt
- Spacing after: 4 pt
- First-line indent: 0
- Template body content uses this for numbered/top-level section headings.

### Heading 2

- Style ID: `Heading2`
- Based on: `Normal`
- Italic: true
- Alignment: left/start
- Spacing before: 6 pt
- Spacing after: 3 pt

### Heading 3

- Style ID: `Heading3`
- Based on: `Normal`
- Italic: true
- Alignment: justified
- First-line indent: 14.40 pt
- Line spacing: exactly 12 pt

### Heading 4

- Style ID: `Heading4`
- Based on: `Normal`
- Italic: true
- Alignment: justified
- First-line indent: 25.20 pt
- Spacing before: 2 pt
- Spacing after: 2 pt

### Heading 5

- Style ID: `Heading5`
- Based on: `Normal`
- Spacing before: 8 pt
- Spacing after: 4 pt

## Tables and Figures

### Figure Caption

- Style ID: `figurecaption`
- Font size: 8 pt
- Alignment: justified
- First-line indent: 0
- Spacing before: 4 pt
- Spacing after: 10 pt

### Table Head

- Style ID: `tablehead`
- Font size: 8 pt
- Alignment: center
- Spacing before: 12 pt
- Spacing after: 6 pt
- Line setting: 10.80 pt, auto

### Table Copy

- Style ID: `tablecopy`
- Font size: 8 pt
- Alignment: justified

### Table Column Head

- Style ID: `tablecolhead`
- Font size: 8 pt
- Bold: true

### Table Column Subhead

- Style ID: `tablecolsubhead`
- Font size: 7.5 pt
- Italic: true

### Table Footnote

- Style ID: `tablefootnote`
- Font size: 6 pt
- Alignment: right/end
- Spacing before: 3 pt
- Spacing after: 1.5 pt
- Start indent: 2.90 pt
- Hanging indent: 1.45 pt

## References

- Style ID: `references`
- Font size: 8 pt
- Alignment: justified
- Spacing after: 2.5 pt
- Line spacing: exactly 9 pt
- East Asian font override: MS Mincho

## Notes for Applying to `ieee-paper-v8-readable-fig1.docx`

- Keep the original file unchanged.
- Save a new file, likely `Document/paper/ieee-paper-v8-ieee-template-letter.docx`.
- Use US Letter page size and the exact margins above.
- Preserve single-column title/abstract area, then use a continuous section break into two equal columns for the body.
- Do not use the 4-column author block for the double-anonymous InCIT review copy unless author details are restored for camera-ready.
- Remove or anonymize author-identifying metadata when generating the review copy.
