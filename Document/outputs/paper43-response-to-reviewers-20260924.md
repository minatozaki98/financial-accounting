Subject: InCIT2026 Response to Reviewers – Paper 43 – Zaw Ye Htut Ko

Dear InCIT 2026 Technical Program Committee,

Thank you for accepting Paper 43, “Evaluating ChatGPT for Security, Performance, and Code-Quality Improvement of a Financial Accounting REST API: A Branch-Isolated Baseline Study,” and for the constructive reviews. The revised paper addresses the comments as follows.

## Review 1

1. **Representative API code.** Section III-A and Fig. 1 now show before/after source excerpts from the baseline and isolated fix branches: the `GET /journal-entries` query-DTO refactor (SonarQube S107), Swagger/OpenAPI security-header middleware order (ZAP), and the report read-path persistence change (JMeter). These examples connect the measured findings to concrete changes.
2. **Prompts or prompt templates.** Section III-C and Fig. 3 provide the three-part template used to structure remediation requests: tool finding, bounded code excerpt, and constrained patch instruction. Fig. 3 also gives an illustrative S107 instantiation, explicitly labeled as reconstructed from retained evidence rather than a verbatim historical prompt. The revised text no longer claims that individual prompt/response transcripts are archived with the branch artifacts.
3. **Results analysis.** Section IV-D now compares the types of repair that worked across tools, distinguishes the raw SonarQube issue count from the dashboard code-smell count, reports the modest throughput gain at 100 virtual users alongside the large p95 reduction, and quantifies the unresolved soak and spike drift against the 20% gate. It also limits the interpretation of the ZAP alert counts to the scanned requests.

## Review 2

1. **Generalizability.** The abstract, threats-to-validity section, and conclusion explicitly limit the findings to one model configuration, one ASP.NET Core/C# API, and one financial-accounting setting.
2. **LLM non-determinism.** Repeated independent LLM runs were not part of the completed study. Sections III-C and V now state this limitation directly; no variance estimate is claimed. Candidate fixes were instead reviewed, regression-tested, and re-measured on isolated branches.
3. **Human intervention.** Table V records author-reported LLM rounds and the human review action for each fix class. The ARM/camelCase cases required two to three rounds and provider-specific correction. The table does not present unrecorded person-hours as measured data.

## Review 3

Thank you for the positive assessment. The revision retains the code-advisor framing and more clearly distinguishes successful localized repairs from the unresolved mixed-workload stability metric.

We also corrected the JMeter container version to 5.5 and clarified the scope of the ZAP API scan. We appreciate the reviewers' guidance.

Sincerely,

Zaw Ye Htut Ko and Darun Kesrarat
