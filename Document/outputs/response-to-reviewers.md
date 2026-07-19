# Response to Reviewers

## Summary

The camera-ready manuscript and final report were revised to address all reviewer requests while preserving the accepted submission format. No new experimental claims were invented. Where a reviewer suggested additional repeated LLM runs, the revision states this as future work because those runs were not part of the completed study.

## Review 1

1. A compact C# controller listing was added for the post-remediation `GET /journal-entries` endpoint, alongside before/after evidence linking SonarQube, ZAP, and JMeter results to concrete code changes.
2. Prompt templates were added using the three-part structure: tool context, code excerpt, and constrained repair instruction.
3. The results discussion was expanded to explain why localized template-driven fixes improved strongly and why the mixed-workload drift heuristic remained a limitation.

## Review 2

1. Generalizability is now foregrounded in the abstract, threats-to-validity discussion, conclusion, and final-report limitations.
2. LLM non-determinism is clarified. Repeated stochastic runs were not performed; this is now stated explicitly as future work.
3. A compact human-effort table was added to the camera-ready manuscript, with a detailed version retained in the final report. It records LLM rounds and the human review required for each fix class.

## Review 3

The revision preserves the accepted contribution framing: ChatGPT is evaluated as a code advisor, not as an autonomous developer. The discussion now more clearly separates successful localized fixes from unresolved workload-composition metrics.
