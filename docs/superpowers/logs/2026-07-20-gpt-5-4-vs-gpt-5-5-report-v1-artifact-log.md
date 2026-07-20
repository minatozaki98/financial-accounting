# GPT-5.4 vs GPT-5.5 Report v1 Artifact Log

Date: 2026-07-20

Branch: `codex/gpt-5.4-vs-gpt-5.5-report-v1`

Base commit: `11f8cfd664e09f1c6831dd1e8f7f05a5c40bfc08`

## Purpose

Preserve the normalized GPT-5.4 vs GPT-5.5 v1 report deliverables on a dedicated branch instead of leaving them as untracked files on `baseline-v0.2`.

The current manuscript/report should continue using this v1 evidence set. The Complex API v2 evidence frozen separately on `codex/gpt-5.5-v2-freeze` is reserved for later GPT-5.5 vs GPT-5.6 work.

## Artifact manifest

| Path | Bytes | SHA-256 |
| --- | ---: | --- |
| `Document/outputs/camera-ready-manuscript-gpt55-comparison.docx` | 317714 | `2b1869ac2e22f5e31cb4996445ebdb31eb394cc514528f01e5d9a533eb5eacf8` |
| `Document/outputs/camera-ready-manuscript-gpt55-comparison.pdf` | 463372 | `d7fbed7564fdc269c62803f4bd63bfd90437a0fe1421a92dc8fb14cd0b809b05` |
| `Document/outputs/final-report-gpt55-comparison.docx` | 1237601 | `167224420bb20924b6e464947aea528dcb8b4ec49e3c018f6d5b754b88fa2420` |
| `Document/outputs/final-report-gpt55-comparison.pdf` | 1807063 | `a675f9e7092b67990c5513612873594cd03dc20ab51dad9b04e3d453c825c9f6` |
| `Document/outputs/gpt-5.4-vs-gpt-5.5.html` | 28495 | `094d5a1a5df748732199d607ea52615c26f63e3c62f714805608ed100f7e2b05` |
| `Document/outputs/gpt55-comparison-deliverables.md` | 1352 | `dea50065823a8f4d414be39fd9c61eafb5f7412d156ff1ce2611eba9b1a23e00` |
| `scripts/create_gpt55_comparison_deliverables.py` | 19301 | `125b5936b79493d08b4474c22deac510bd4fd06007f491d4900809db30140ecf` |

## Cleanup decision

Generated .NET build output under `bin/` and `obj/` was removed from the main checkout before this branch was created. No benchmark evidence, report deliverable, or source file was deleted for this log.
