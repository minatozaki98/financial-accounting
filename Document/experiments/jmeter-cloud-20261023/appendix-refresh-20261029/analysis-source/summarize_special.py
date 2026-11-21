"""Validate soak drift and all three scored spike phases."""

from collections import Counter, defaultdict
import csv
import math
from pathlib import Path

from concurrency_gate import analyze
from lifecycle_gate import analyze_lifecycle, reconcile_jtl_with_lifecycle
from summarize_run import ERROR_PATTERN, START_PATTERN, percentile, summarize


def phase(jtl: Path, start_ms: int, start_second: int, end_second: int) -> dict:
    elapsed = []
    endpoint_elapsed = defaultdict(list)
    endpoint_errors = Counter()
    errors = 0
    codes = Counter()
    with jtl.open(newline="", encoding="utf-8-sig") as stream:
        for row in csv.DictReader(stream):
            timestamp = int(row["timeStamp"])
            if not start_ms + start_second * 1000 <= timestamp < start_ms + end_second * 1000:
                continue
            elapsed.append(int(row["elapsed"]))
            endpoint_elapsed[row["label"]].append(int(row["elapsed"]))
            if row["success"].lower() != "true":
                errors += 1
                codes[row["responseCode"]] += 1
                endpoint_errors[row["label"]] += 1
    count = len(elapsed)
    return {"samples": count, "errors": errors,
            "error_pct": round(100 * errors / count, 4) if count else None,
            "requests_per_second": round(count / (end_second - start_second), 4),
            "p95_ms": percentile(elapsed, 0.95),
            "p99_ms": percentile(elapsed, 0.99), "error_codes": dict(codes),
            "endpoints": {
                label: {"samples": len(values), "errors": endpoint_errors[label],
                        "p95_ms": percentile(values, 0.95), "p99_ms": percentile(values, 0.99)}
                for label, values in sorted(endpoint_elapsed.items())
            }}


def drift_pct(first: dict, last: dict):
    if not first["p95_ms"] or last["p95_ms"] is None:
        return None
    return round(100 * (last["p95_ms"] - first["p95_ms"]) / first["p95_ms"], 3)


def legacy_sample_count_drift(jtl: Path) -> dict:
    """Reproduce the old thesis runner's first/last 20% of all JTL rows."""
    with jtl.open(newline="", encoding="utf-8-sig") as stream:
        rows = sorted((int(row["timeStamp"]), int(row["elapsed"]))
                      for row in csv.DictReader(stream))
    if len(rows) < 10:
        raise ValueError("legacy drift requires at least ten JTL samples")
    window = max(1, math.floor(len(rows) * 0.2))
    first = {"p95_ms": percentile([value for _, value in rows[:window]], 0.95)}
    last = {"p95_ms": percentile([value for _, value in rows[-window:]], 0.95)}
    return {"window_samples": window, "first_p95_ms": first["p95_ms"],
            "last_p95_ms": last["p95_ms"], "drift_pct": drift_pct(first, last)}


def summarize_soak(jtl: Path, log: Path) -> dict:
    result = summarize(jtl, log, 100, 120, 2700)
    start = result["test_start_ms"]
    first = phase(jtl, start, 120, 720)
    last = phase(jtl, start, 2220, 2820)
    drift = drift_pct(first, last)
    result["soak"] = {"first_10_minutes": first, "last_10_minutes": last,
                      "p95_drift_pct": drift}
    result["legacy_first_last_20pct_samples"] = legacy_sample_count_drift(jtl)
    result["performance_gates"] = {
        "error_pct_at_most_1": result["hold"]["error_pct"] is not None and result["hold"]["error_pct"] <= 1,
        "p95_drift_at_most_20": drift is not None and drift <= 20,
    }
    return result


SPIKE_PHASES = {
    "base": (30, 150, 100),
    "peak": (180, 480, 500),
    "recovery": (510, 810, 100),
}


def summarize_spike(jtl: Path, log: Path) -> dict:
    text = log.read_text(encoding="utf-8", errors="replace")
    starts = START_PATTERN.findall(text)
    if len(starts) != 1:
        raise ValueError("spike run needs one JMeter start timestamp")
    start_ms = int(starts[0])
    errors = [line for line in text.splitlines() if ERROR_PATTERN.search(line)]
    phases = {}
    concurrency = {}
    for name, (start_second, end_second, users) in SPIKE_PHASES.items():
        phases[name] = phase(jtl, start_ms, start_second, end_second)
        jtl_concurrency = analyze(jtl, users, start_ms + start_second * 1000,
                                  0, end_second - start_second, 5)
        lifecycle = analyze_lifecycle(text, users, start_ms, start_second,
                                      end_second, settle_seconds=5)
        concurrency[name] = reconcile_jtl_with_lifecycle(jtl_concurrency, lifecycle)
    drift = drift_pct(phases["base"], phases["recovery"])
    count = sum(value["samples"] for value in phases.values())
    failed = sum(value["errors"] for value in phases.values())
    error_pct = round(100 * failed / count, 4) if count else None
    return {
        "analysis_protocol_version": 2,
        "valid_run": all(value["valid"] for value in concurrency.values()) and not errors and count > 0,
        "test_start_ms": start_ms,
        "jmeter_log_error_count": len(errors),
        "concurrency": concurrency,
        "phases": phases,
        "scored_samples": count,
        "scored_error_pct": error_pct,
        "recovery_p95_drift_pct": drift,
        "legacy_first_last_20pct_samples": legacy_sample_count_drift(jtl),
        "performance_gates": {
            "error_pct_at_most_3": error_pct is not None and error_pct <= 3,
            "recovery_p95_drift_at_most_20": drift is not None and drift <= 20,
        },
    }
