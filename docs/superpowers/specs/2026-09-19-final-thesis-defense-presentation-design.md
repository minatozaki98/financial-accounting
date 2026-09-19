# Final Thesis Defense Presentation Design

## Purpose

Create a complete English-language final thesis defense package for Zaw Ye Htut Ko (student ID G6519692). The defense is expected to last approximately 30 minutes and is based on the latest 64-page report, `Document/outputs/final-report-gpt55-comparison.docx` and its matching PDF.

The presentation must help a presenter who is not confident with public speaking explain the study accurately, clearly, and defensibly. It must emphasize measured evidence, distinguish conclusions from limitations, and prepare the presenter for difficult committee questions.

## Thesis Identity

- Title: *Improving Security and Performance of Financial RESTful APIs Using ChatGPT in ASP.NET Core*
- Student: Zaw Ye Htut Ko
- Student ID: G6519692
- Degree: Master of Science in Information Technology
- Advisor: Assistant Professor Dr. Darun Kesrarat
- Defense language: English
- Target duration: 30 minutes, including a small timing buffer before questions

## Deliverables

The package will be written under `Document/outputs/final-defense/`:

1. `G6519692_Zaw_Ye_Htut_Ko_Final_Thesis_Defense.pptx`
2. `G6519692_Zaw_Ye_Htut_Ko_Final_Thesis_Defense.pdf`
3. `G6519692_Zaw_Ye_Htut_Ko_Defense_Preparation_Guide.docx`
4. `G6519692_Zaw_Ye_Htut_Ko_Defense_Preparation_Guide.pdf`

The PowerPoint will contain approximately 22 main slides and 8-10 appendix slides. Every main slide will contain speaker notes. The preparation guide will combine the full script, question bank, fallback explanations, rehearsal schedule, and final-day checklist.

## Defense Narrative

The deck will use an evidence-first structure rather than mirror every thesis chapter. Its central argument is:

> ChatGPT/Codex can help shorten the audit-to-fix cycle for a financial ASP.NET Core API when its suggestions are constrained by source context, applied on isolated branches, reviewed by a human, and accepted only after repeatable tool-based verification.

The narrative will explicitly avoid claiming that ChatGPT autonomously improved the system or that the results generalize to every API or LLM.

## Main Slide Structure

| # | Slide | Primary purpose | Planned visual |
|---|---|---|---|
| 1 | Title | Establish thesis, student, advisor, and defense context | Minimal title composition |
| 2 | Defense roadmap | Set expectations for the 30-minute narrative | Five-stage horizontal roadmap |
| 3 | Practical problem | Explain why financial APIs need security, performance, and maintainability together | Three-risk visual |
| 4 | Research gap | Position tool-guided LLM remediation as underexplored | Existing-work versus this-study comparison |
| 5 | Research questions and objectives | State what the study actually tests | Three research-question columns |
| 6 | System under study | Define the financial accounting API and endpoint groups | API-domain map |
| 7 | Research design | Explain baseline versus isolated remediation branches | Branch-isolation diagram |
| 8 | Four-phase workflow | Show baseline, remediation, remeasurement, and comparison | Recreated workflow diagram |
| 9 | Environment and dataset | Establish reproducibility and scale | Compact facts panel with 120 accounts and 30,000 journal entries |
| 10 | Evaluation gates | Define SonarQube, OWASP ZAP, JMeter, tests, and acceptance criteria | Tool-gate matrix |
| 11 | How ChatGPT/Codex was used | Clarify the advisor role and human control boundary | Human-in-the-loop flow |
| 12 | SonarQube remediation | Present the static-quality changes and outcome | Before/after bar chart and gate badge |
| 13 | OWASP ZAP remediation | Present business-endpoint security outcomes and residual alerts | Severity comparison chart |
| 14 | JMeter design | Explain p50, p100, p500, soak, and spike profiles | Load-profile timeline |
| 15 | JMeter results | Present latency, throughput, error-rate, and drift results without cherry-picking | Before/after chart plus caveat callout |
| 16 | Accounting and authorization integrity | Demonstrate that optimization did not remove essential controls | Verification checklist and role matrix |
| 17 | Working application evidence | Show that the evaluated API has a usable, role-aware client | Actual screenshots from `web-app-evidence` |
| 18 | GPT-5.4 versus GPT-5.5 | Present the measured trade-offs, not a universal winner claim | Three-axis comparison table |
| 19 | New-API v2 controlled retest | Explain the corrected equal-opportunity retest and incomplete JMeter comparison | Controlled-retest scorecard |
| 20 | Contributions | State empirical, methodological, and practical contributions | Three contribution blocks |
| 21 | Limitations and future work | Preempt validity and generalizability objections | Limitation-to-future-work mapping |
| 22 | Conclusion | Deliver the final defensible answer and invite questions | Three takeaways and closing statement |

## Appendix Slides

The appendix will contain detailed material that should not consume main-defense time:

1. Branch and commit provenance
2. Endpoint coverage and role-access matrix
3. Full SonarQube metrics
4. Full ZAP alert-category and instance counts
5. Full JMeter profile table
6. Patch-size and regression-test evidence
7. New-API v2 detailed results
8. Threats to validity
9. Prompt-template and human-effort traceability
10. Key references

## Evidence Rules

- Every numeric claim must be traceable to a table or paragraph in the latest final report.
- Main slides must distinguish the original Codex 5.4 study from the later GPT-5.4/GPT-5.5 comparison.
- The original study result may report retained C# findings reduced from 28 to 0, business-endpoint ZAP gates cleared, and large JMeter p95 reductions, while preserving the report's documented drift caveat.
- The normalized model comparison must report SonarQube as a tie, GPT-5.4 as cleaner on residual ZAP output, and GPT-5.5 as more balanced across JMeter profiles with smaller patches.
- The new-API v2 retest must report a SonarQube and ZAP tie after equalizing the correction opportunity. It must not declare an overall three-tool winner because no valid GPT-5.4 JMeter remediation candidate exists.
- Screenshots and tables will be taken from the report or repository evidence. No stock imagery will be used.

## Visual System

- Format: 16:9 widescreen
- Background: white or very light gray
- Primary text: charcoal
- Methodology accent: deep teal
- Security accent: restrained red
- Performance accent: amber
- Verified outcome accent: green
- Typeface: Arial for maximum PowerPoint and PDF portability
- Minimum body size: 20 pt on main slides
- Titles: 28-34 pt depending on length
- Tables: simplified to presentation-relevant rows; dense full tables move to the appendix
- Charts: direct labels and units; no decorative 3D effects
- Images: actual application screenshots with short captions and visible feature callouts

Slides will avoid paragraphs, decorative gradients, nested cards, and unnecessary animations. Layouts will prioritize one message per slide and high projector readability.

## Speaker Notes

Each main slide will include:

- A 60-90 second spoken-English script
- A one-sentence key message
- A transition sentence to the next slide
- A timing cue
- A warning where the presenter must avoid overclaiming
- A likely interruption question when relevant

The wording will sound natural when spoken and will define technical terms before using abbreviations. Notes will not simply repeat visible slide text.

## Committee Question Preparation

The question bank will simulate five perspectives:

1. Chair or program reviewer: significance, originality, and thesis-level contribution
2. Methodology reviewer: controls, repeatability, branch isolation, statistical limitations, and causal claims
3. Software-security reviewer: ZAP coverage, authentication, authorization, residual alerts, and threat model
4. Performance and systems reviewer: workload realism, p95/p99 interpretation, throughput, drift, caching, and database effects
5. Devil's advocate: one-codebase limitation, model attribution, confirmation bias, incomplete GPT-5.4 JMeter evidence, and alternative explanations

The guide will provide approximately 30 high-probability questions. Each will have:

- A short 20-second answer
- A deeper follow-up answer
- The supporting slide or appendix reference
- A caution against unsupported claims

## Rehearsal Support

The preparation guide will include:

- A 30-minute timing map
- Opening and closing scripts
- Pronunciation and acronym reminders
- Instructions for explaining charts without reading them
- Recovery phrases for forgotten points
- A method for answering questions: answer first, give evidence, state limitation, stop
- A final-day checklist for files, fonts, PDF backup, screen resolution, and offline evidence

## Verification

The generated package must pass the following checks:

1. Open and validate the PPTX package structure.
2. Export the PPTX to PDF and confirm page count.
3. Render every slide to images and inspect for clipping, overlap, unreadable tables, blank images, and low contrast.
4. Verify every main numeric claim against the latest report.
5. Confirm speaker notes exist on all main slides.
6. Confirm the 30-minute script fits the timing target with a 2-3 minute buffer.
7. Validate and render the preparation-guide DOCX/PDF.
8. Preserve all existing thesis and report files unchanged.

## Acceptance Criteria

The package is complete when the presentation can be delivered in English within 27-28 minutes, the remaining time can absorb pauses or brief clarifications, all key claims are traceable to the report, the appendix can answer detailed committee challenges, and the user can rehearse directly from the provided notes and guide.
