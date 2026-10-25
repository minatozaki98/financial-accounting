"""Validate sustained JMeter active-thread counts from a CSV JTL."""

import argparse
import csv
import json
import math
from pathlib import Path
import statistics
import sys


def analyze(jtl: Path, target_users: int, test_start_ms: int, ramp_seconds: int,
            hold_seconds: int, bin_seconds: int) -> dict:
    if target_users < 1 or ramp_seconds < 0 or hold_seconds < 1 or bin_seconds < 1:
        raise ValueError("target, hold, and bin must be positive; ramp must be nonnegative")
    if hold_seconds % bin_seconds:
        raise ValueError("hold_seconds must be divisible by bin_seconds")

    hold_start = test_start_ms + ramp_seconds * 1000
    hold_end = hold_start + hold_seconds * 1000
    bin_width_ms = bin_seconds * 1000
    expected_bins = hold_seconds // bin_seconds
    bin_minima: dict[int, int] = {}
    observed_peak = 0
    ramp_peak = 0
    unique_threads: set[str] = set()

    with jtl.open(newline="", encoding="utf-8-sig") as stream:
        reader = csv.DictReader(stream)
        required = {"timeStamp", "allThreads", "threadName"}
        if not required.issubset(reader.fieldnames or ()):
            raise ValueError(f"JTL must contain {', '.join(sorted(required))}")
        for row in reader:
            timestamp = int(row["timeStamp"])
            active = int(row["allThreads"])
            observed_peak = max(observed_peak, active)
            if timestamp <= hold_start:
                ramp_peak = max(ramp_peak, active)
            unique_threads.add(row["threadName"])
            if hold_start <= timestamp < hold_end:
                index = (timestamp - hold_start) // bin_width_ms
                bin_minima[index] = min(active, bin_minima.get(index, active))

    values = list(bin_minima.values())
    full_bins = sum(value == target_users for value in values)
    failures = []
    if len(values) != expected_bins:
        failures.append("missing_samples")
    if observed_peak < target_users:
        failures.append("target_never_reached")
    if ramp_seconds > 0 and ramp_peak < target_users:
        failures.append("target_not_reached_by_ramp_end")
    if any(value < math.ceil(target_users * 0.95) for value in values):
        failures.append("below_95_percent")
    if full_bins < math.ceil(expected_bins * 0.95):
        failures.append("insufficient_full_hold")

    return {
        "valid": not failures,
        "target_users": target_users,
        "observed_peak": observed_peak,
        "ramp_peak": ramp_peak,
        "unique_threads": len(unique_threads),
        "hold_bins": expected_bins,
        "bins_observed": len(values),
        "full_bins": full_bins,
        "min_hold_active": min(values) if values else None,
        "median_hold_active": statistics.median(values) if values else None,
        "failures": failures,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--jtl", type=Path, required=True)
    parser.add_argument("--target-users", type=int, required=True)
    parser.add_argument("--test-start-ms", type=int, required=True)
    parser.add_argument("--ramp-seconds", type=int, required=True)
    parser.add_argument("--hold-seconds", type=int, required=True)
    parser.add_argument("--bin-seconds", type=int, default=5)
    args = parser.parse_args()
    try:
        result = analyze(args.jtl, args.target_users, args.test_start_ms,
                         args.ramp_seconds, args.hold_seconds, args.bin_seconds)
    except (OSError, ValueError) as exc:
        parser.error(str(exc))
    print(json.dumps(result, sort_keys=True))
    return 0 if result["valid"] else 1


if __name__ == "__main__":
    sys.exit(main())
