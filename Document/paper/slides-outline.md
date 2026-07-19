# 15-Minute Conference Talk — Slide Outline + Speaker Notes

**Target:** 15-minute slot (≈ 12 minutes talk + 3 minutes Q&A)
**Slides:** 14 content slides + 1 title + 1 thanks = 16 total
**Pacing:** ~50 seconds per content slide (tight — rehearse to trim)

Each slide below has a one-line **headline** (what appears on the slide) and **speaker notes** (what you say). Keep slide text minimal — the notes carry the argument.

---

## Slide 1 · Title
**Headline:** *Evaluating ChatGPT (Codex 5.4) for Security, Performance, and Code-Quality Improvement of a Financial Accounting REST API: A Branch-Isolated Baseline Study*
**Speaker notes:** Good morning. I'm Zaw Ye Htut Ko from Assumption University. In the next 12 minutes I'll show empirical evidence that ChatGPT works well as a code-review advisor — *when you pair it with automated measurement tools* — and I'll also show the one metric it doesn't move.

## Slide 2 · Motivation — the gap (≈1 min)
**Headline:** "LLMs generate code. Can they *improve* code that already exists?"
**Speaker notes:** The literature on LLMs for software engineering is dominated by generation benchmarks. But in real teams, the question is different: I have an existing API, a SonarQube report, a ZAP scan, and a JMeter failure — can the LLM help me fix what the tools already found? That's the question this paper answers, with numbers.

## Slide 3 · Contribution — three bullets (≈30 sec)
**Headline:**
1. Reproducible 4-phase branch-isolated workflow
2. Empirical before/after data on three dimensions
3. An honest limitation the LLM cannot fix
**Speaker notes:** Three contributions. A reproducible workflow. Empirical numbers across code quality, security, and performance. And a limitation — because I want you to trust the other numbers.

## Slide 4 · System under test (≈45 sec)
**Headline:** ASP.NET Core 8.0 Financial Accounting API — auth, journal entries, 4 reports, audit log — 98 tests, 4 RBAC roles
**Speaker notes:** The subject is a research-grade financial accounting REST API in ASP.NET Core: JWT auth, bulk journal entries, four financial reports, audit logging, RBAC with four roles, and a 98-test baseline. Non-trivial but scoped.

## Slide 5 · The workflow diagram — one picture (≈1 min 30 sec) [USE Fig. 1]
**Headline:** Four phases × one branch per tool
**Speaker notes:** This is the whole methodology. Phase 1 baseline: SonarQube, OWASP ZAP, and JMeter on `baseline-v0.1`. Phase 2 improvements: each tool's fixes land on its own branch — `-sonarqube-v1`, `-zap-v1`, `-jmeter-v1` — so we can attribute every delta to one dimension. Phase 3 re-runs the same tool matrix. Phase 4 aggregates the comparison.

## Slide 6 · Prompting protocol — why we trust the deltas (≈45 sec)
**Headline:** (context = tool output) + (code = smallest unit) + (instruction = minimal patch, tests green)
**Speaker notes:** Three-part prompt template for every fix. The model sees the tool's own output, the smallest code unit containing the finding, and a constraint: minimal patch, existing tests stay green, no new dependencies. Every prompt/response archived. This gives us traceability against LLM non-determinism.

## Slide 7 · Results I — Code quality (≈1 min) [TABLE]
**Headline:** SonarQube: 28 → 0 findings · Code smells 21 → 0 · Quality Gate OK · Coverage 74.3 %
**Speaker notes:** Twenty-eight C# baseline findings, twenty-one were code smells. After the LLM-guided fixes, zero. Quality gate OK, coverage held at 74.3%. Fixes were mechanical: DTO extraction, sealed types, parameterized queries, awaited shutdown, string-literal de-duplication. Pattern matching — that's what the model is good at.

## Slide 8 · Results II — Security (≈1 min) [TABLE]
**Headline:** OWASP ZAP: all Med/Low alerts on business endpoints → 0
**Speaker notes:** ZAP baseline and authenticated API scans. Before: 2 Medium, 9 Low across both scans. After: zero. Fixes included moving the security-header middleware ahead of Swagger, upgrading Swashbuckle to clear a vulnerable DOMPurify bundle, and disabling Swagger UI by default. Remaining alerts are informational scanner noise.

## Slide 9 · Results III — Performance (≈1 min 15 sec) [TABLE]
**Headline:** JMeter p95 ↓ 73.7–94.2 % · 0 % errors · p50/p100/p500 gates **PASS**
**Speaker notes:** Five load profiles. p50 at 50 VUs, p95 went from 49 ms to 13 ms. p100 from 262 ms to 34 ms. p500 from 176 ms to 28 ms. Soak from 971 ms to 56 ms — that's a 94% reduction. Spike from 6.8 seconds to 1.4 seconds. Zero errors across every profile. Constant-load gates all pass.

## Slide 10 · Results IV — Endpoint hotspots (≈45 sec) [TABLE or BAR CHART]
**Headline:** Summary reports: trial-balance −88 %, profit-loss −90 %, balance-sheet −89 % (spike p95)
**Speaker notes:** The summary reports were the bottleneck. Trial balance p95 under spike went from 10.6 seconds to 1.2. Profit-loss from 7.1 to 0.7. Balance-sheet from 5.8 to 0.7. The fix: stop recomputing from raw journal lines, reuse the pre-computed `LedgerBalances` aggregate. The LLM suggested the pattern after seeing the endpoint name and the latency.

## Slide 11 · The caveat — what the LLM could *not* fix (≈1 min)
**Headline:** Mixed-workload drift heuristic stayed red — and it should have
**Speaker notes:** Honest slide. The drift gate compares first-window p95 to last-window p95 of the mixed thread group. Every per-endpoint optimization helped — but the *last* window is compositionally heavier than the first. That's not an endpoint problem. It's a workload-composition problem. No amount of caching or indexing moves it. The LLM kept proposing local optimizations. It doesn't see the global picture.

## Slide 12 · What worked, what didn't (≈45 sec)
**Headline:**
✓ Worked: parameterized queries · security headers · library upgrades · composite indexes · aggregate reuse · payload caching
✗ Didn't: workload-composition metrics · framework-specific conventions (ARM)
**Speaker notes:** Where the fix has a well-known template, the LLM is excellent. Where the problem is global, or where framework conventions are subtly different, it takes 2–3 rounds or doesn't converge at all.

## Slide 13 · Threats to validity (≈30 sec)
**Headline:** 1 model · 1 framework · 1 language · 1 domain
**Speaker notes:** Single-model, single-framework, single-language, single-domain. We pre-registered the gates to avoid post-hoc tuning. Future work is multi-model and multi-framework. The methodology itself is reproducible on any branch.

## Slide 14 · Conclusion (≈45 sec)
**Headline:**
- LLM as *advisor* on existing code: 28→0, all Med/Low security cleared, p95 −73.7–94.2 %
- The limitation is composition, not complexity
- Future: CI/CD-integrated, multi-model
**Speaker notes:** Three takeaways. ChatGPT as an advisor on an existing codebase works — when paired with the right measurement tools. The limitation is workload composition, not code complexity. Next: integrate the loop into CI/CD so that tool diagnostics become LLM prompts automatically.

## Slide 15 · Thanks + Q&A
**Headline:** Thanks — kozawyehtutko43@gmail.com — Questions?
**Speaker notes:** Thank you. Happy to take questions.

---

## Likely questions + 1-sentence answers

- **Q: Why Codex 5.4 and not GPT-5 / Claude / Gemini?**
  A: Scoping — single-model study is the unit of analysis; multi-model comparison is named as future work.
- **Q: How did you control for LLM non-determinism?**
  A: Archived every prompt/response; manual review + tests acted as a safety net; we do not attribute every delta to the model alone.
- **Q: Why didn't you just change the drift threshold?**
  A: Gates are pre-registered; adjusting the threshold post-hoc to make the paper look better would be p-hacking.
- **Q: Is 74.3 % coverage enough?**
  A: Coverage is a secondary metric here; the primary measurement is issue count, alert count, and latency. Coverage is held constant before/after so it is not a confound.
- **Q: Can the model introduce regressions?**
  A: Yes — that is exactly why we kept the 98-test suite green as a hard gate; any patch that broke tests was rejected.

## Visual assets you already have

- Figure 1 (workflow) -> Slide 5 — [workflow-split-preview.png](figures/workflow-split-preview.png)
- Tables I–IV → Slides 7, 8, 9, 10 (copy directly from the .tex)

## Rehearsal checklist

- [ ] Time a dry run end-to-end (target: 11:30–12:30)
- [ ] Check slide 10 renders the hotspot numbers readably from the back row
- [ ] Have a one-liner ready for *"how is this different from Pearce 2022?"* → ours is an improvement study on an existing API; theirs is an audit of generated code
- [ ] Back up the deck as PDF (conferences frequently refuse .pptx/.key last minute)
