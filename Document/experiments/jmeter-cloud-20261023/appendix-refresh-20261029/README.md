# Current JMeter appendix evidence — 29 October 2026

This package supports Figures L.9–L.18 of final-report-methods-citations-20261023.
All 30 accepted runs (three pairs for each of five profiles) are shown. The figures
are research plots of scored JMeter measurements, not native dashboard screenshots.

- `evidence/accepted-runs.csv`: exact accepted run IDs, source hashes, local dates,
  p95/p99, throughput, errors, drift and gate results.
- `evidence/endpoint-runs.csv`: every scored endpoint record, including separate
  base/peak/recovery phases for spike.
- `evidence/runs/`: freshly recomputed protocol-v2 summaries, captured resource
  summaries and checked input hashes for each accepted run.
- `evidence/raw-recheck.json`: 30 raw reanalyses and 150 checked input files;
  recomputed primary and endpoint metrics match the archived comparison.
- `figures/figure-provenance.json`: each figure's three input run IDs and PNG hash.
- `historical-local/`: retired September screenshots and tables, retained only for
  provenance. They are not used as the current experiment.
- `analysis-source/`: the same offline scoring modules used in the raw recheck.
- `make_figures.py`: regenerates the research figures from this package's checked
  JSON with Python, NumPy and Matplotlib. It performs no cloud actions or load test.

The raw JTL/log archive is located and hashed by `../raw-evidence-archive.json`.
The archive hash was rechecked before publishing this package. The input-source
archive is not duplicated inside the repository. The original cloud protocol and
post-scoring concurrency amendment are preserved in the parent directory.

Side medians/ranges and median within-pair changes are distinct summaries. Spike
latency/throughput are peak-only, while its error gate uses all scored phases.
All validity checks pass, but 500-user and relative-stability performance failures
remain. This update reanalyses existing evidence; it does not create new cloud runs.
