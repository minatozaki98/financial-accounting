# IEEE Conference Paper — Draft

Target: IEEE conference format, 6 pages (IEEEtran, two-column, 10pt).

## Files

- [ieee-paper.tex](ieee-paper.tex) — LaTeX source (the submittable artifact)
- [ieee-paper.md](ieee-paper.md) — Markdown preview for on-screen reading
- [figures/workflow-phase1.png](figures/workflow-phase1.png) through [figures/workflow-phase4.png](figures/workflow-phase4.png) — Figure 1 split into readable phase panels
- [figures/workflow-split-preview.png](figures/workflow-split-preview.png) — side-by-side preview of the split Figure 1 panels

## How to compile

### Option A: Overleaf (recommended, no local install)
1. Create a new project and upload `ieee-paper.tex` and the `figures/` folder.
2. Compiler = `pdfLaTeX`. Click **Recompile**. The paper builds in a single pass (no bibtex; references are hard-coded).

### Option B: Local with TeX Live / MiKTeX
```bash
pdflatex ieee-paper.tex
pdflatex ieee-paper.tex   # second pass for cross-refs
```

### Option C: Tectonic (single-binary, auto-fetches packages)
```bash
tectonic ieee-paper.tex
```

## Page count

The draft is sized to land at ~6 pages in `IEEEtran` `conference` mode. After a first compile:

- If the paper runs **over** 6 pages: trim endpoint-hotspot sentences in §V-D, or collapse Table IV into prose, or shorten §II (each paragraph can lose 1 sentence without losing a citation).
- If the paper runs **under** 6 pages: expand the threats-to-validity subsection (add a paragraph on statistical power of single-run JMeter measurements) or add a small "limitations of the drift heuristic" figure.

## References

15 entries, hard-coded in IEEE numeric style inside `\begin{thebibliography}...\end{thebibliography}` — identical to the reference list in the thesis proposal, so citations across the thesis and paper stay aligned. No `.bib` file is needed.

## What's in the paper

| Section | Content |
|---------|---------|
| Abstract + Keywords | 200-word structured abstract |
| I. Introduction | Problem, gap, contributions |
| II. Related Work | Three themes: generation/productivity; LLMs + security; APIs + static analysis + LLM-for-SE |
| III. Methodology | SUT, four-phase workflow (Fig. 1), prompting protocol |
| IV. Experimental Setup | Tool versions, scan profiles, LLM usage protocol |
| V. Results | Tables I–IV across SonarQube / ZAP / JMeter / endpoint hotspots |
| VI. Discussion | What worked, what didn't, threats to validity |
| VII. Conclusion | Findings + future work |
| AI Usage Disclosure | Required by IEEE |
| References | 15 entries, IEEE style |

## Notes

- All empirical numbers come from [Document/baseline-comparison-report.md](../baseline-comparison-report.md), [Document/sonarqube-fixes.md](../sonarqube-fixes.md), [Document/zap-fixes.md](../zap-fixes.md), and [Document/jmeter-fixes.md](../jmeter-fixes.md). No number is invented.
- The 5 added references (Pearce 2022, Khoury 2023, Sandoval 2023, Hou 2024, Lenarduzzi 2020) are exactly the PDFs in [Document/references/](../references/) (files 11–15).
- AI disclosure is included per IEEE policy; it is factually accurate — the model was used on the experimental patches, and for language polish on the manuscript only.
