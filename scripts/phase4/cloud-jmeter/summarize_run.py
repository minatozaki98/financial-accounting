"""Summarize a steady JMeter hold and distinguish validity from performance."""

import argparse
from collections import defaultdict
import csv
import json
import math
from pathlib import Path
import re
import sys

from concurrency_gate import analyze


START_PATTERN = re.compile(r"Running test \((\d+)\)")
ERROR_PATTERN = re.compile(r"\bERROR\b|StackOverflowError|OutOfMemoryError")


def percentile(values: list[int], fraction: float):
    if not values:
        return None
    ordered = sorted(values)
    return ordered[max(0, math.ceil(len(ordered) * fraction) - 1)]


def summarize(jtl: Path, log: Path, target_users: int, ramp_seconds: int,
              hold_seconds: int, bin_seconds: int = 5) -> dict:
    log_text = log.read_text(encoding="utf-8", errors="replace")
    starts = START_PATTERN.findall(log_text)
    if len(starts) != 1:
        raise ValueError(f"expected one JMeter start timestamp, found {len(starts)}")
    start_ms = int(starts[0])
    hold_start = start_ms + ramp_seconds * 1000
    hold_end = hold_start + hold_seconds * 1000
    concurrency = analyze(jtl, target_users, start_ms, ramp_seconds,
                          hold_seconds, bin_seconds)
    elapsed = defaultdict(list)
    failures = defaultdict(int)
    codes = defaultdict(int)
    with jtl.open(newline="", encoding="utf-8-sig") as stream:
        for row in csv.DictReader(stream):
            timestamp = int(row["timeStamp"])
            if not hold_start <= timestamp < hold_end:
                continue
            label = row["label"]
            elapsed[label].append(int(row["elapsed"]))
            if row["success"].lower() != "true":
                failures[label] += 1
                codes[f"{label}: {row['responseCode']}"] += 1
    count = sum(len(values) for values in elapsed.values())
    failed = sum(failures.values())
    all_elapsed = [value for values in elapsed.values() for value in values]
    log_error_lines = [line for line in log_text.splitlines() if ERROR_PATTERN.search(line)]
    return {
        "valid_run": concurrency["valid"] and not log_error_lines and count > 0,
        "concurrency": concurrency,
        "jmeter_log_error_count": len(log_error_lines),
        "hold": {
            "samples": count,
            "errors": failed,
            "error_pct": round(100 * failed / count, 4) if count else None,
            "requests_per_second": round(count / hold_seconds, 4),
            "p50_ms": percentile(all_elapsed, 0.50),
            "p95_ms": percentile(all_elapsed, 0.95),
            "p99_ms": percentile(all_elapsed, 0.99),
        },
        "endpoints": {
            label: {"samples": len(values), "errors": failures[label],
                    "p95_ms": percentile(values, 0.95)}
            for label, values in sorted(elapsed.items())
        },
        "error_codes": dict(sorted(codes.items())),
        "test_start_ms": start_ms,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--jtl", type=Path, required=True)
    parser.add_argument("--log", type=Path, required=True)
    parser.add_argument("--target-users", type=int, required=True)
    parser.add_argument("--ramp-seconds", type=int, required=True)
    parser.add_argument("--hold-seconds", type=int, required=True)
    args = parser.parse_args()
    try:
        result = summarize(args.jtl, args.log, args.target_users,
                           args.ramp_seconds, args.hold_seconds)
    except (OSError, ValueError) as error:
        parser.error(str(error))
    print(json.dumps(result, sort_keys=True))
    return 0 if result["valid_run"] else 1


if __name__ == "__main__":
    sys.exit(main())
