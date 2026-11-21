Threshold sensitivity analysis

This is a post-hoc reclassification of all 30 accepted cloud runs. It uses the recorded metrics without running the application again. Latency limits use multipliers 0.50, 0.75, 1.00, 1.25, 1.50 and 2.00 of the original limits. Drift limits are 10, 20, 30, 40, 50, 80 and 100 percent. Original error limits apply at every point. The analysis file records the input hash and passing run IDs.

Run analyze.py and plot.py from the repository root to reproduce the outputs. Counts describe three repeats per revision. The selected range does not validate the original thresholds as production requirements.
