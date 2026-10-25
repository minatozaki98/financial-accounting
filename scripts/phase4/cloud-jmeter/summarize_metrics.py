"""Summarize five-second resource samples from one benchmark host."""

import argparse
from collections import defaultdict
from datetime import datetime
import json
from pathlib import Path


def percentile(values: list[float], fraction: float):
    if not values:
        return None
    ordered = sorted(values)
    index = max(0, min(len(ordered) - 1, int(len(ordered) * fraction + 0.999999) - 1))
    return round(ordered[index], 2)


def summarize(path: Path) -> dict:
    records = [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines()
               if line.strip()]
    if len(records) < 2:
        raise ValueError("at least two telemetry samples are required")
    host = [record["host"] for record in records]
    by_container = defaultdict(list)
    for record in records:
        for item in record.get("containers", []):
            by_container[item["Name"]].append((record["time_utc"], item))
    containers = {}
    for name, samples in sorted(by_container.items()):
        items = [item for _, item in samples]
        cpu = [float(item["CPUPerc"].rstrip("%")) for item in items]
        memory = [float(item["MemPerc"].rstrip("%")) for item in items]
        effective_cores = []
        for (previous_time, previous), (current_time, current) in zip(samples, samples[1:]):
            if not previous.get("cpu_stat") or not current.get("cpu_stat"):
                continue
            elapsed_us = (datetime.fromisoformat(current_time) -
                          datetime.fromisoformat(previous_time)).total_seconds() * 1_000_000
            usage_us = current["cpu_stat"].get("usage_usec", 0) - previous["cpu_stat"].get("usage_usec", 0)
            if elapsed_us > 0 and usage_us >= 0:
                effective_cores.append(usage_us / elapsed_us)
        oom_kills = [item.get("memory_events", {}).get("oom_kill", 0)
                     for item in items if item.get("memory_events")]
        throttled = [item.get("cpu_stat", {}).get("throttled_usec", 0)
                     for item in items if item.get("cpu_stat")]
        periods = [item.get("cpu_stat", {}).get("nr_periods", 0)
                   for item in items if item.get("cpu_stat")]
        throttled_periods = [item.get("cpu_stat", {}).get("nr_throttled", 0)
                             for item in items if item.get("cpu_stat")]
        period_delta = max(periods) - min(periods) if periods else 0
        throttled_delta = max(throttled_periods) - min(throttled_periods) if throttled_periods else 0
        containers[name] = {
            "samples": len(items), "cpu_p95_pct_of_one_core": percentile(cpu, 0.95),
            "cpu_peak_pct_of_one_core": max(cpu), "memory_peak_pct_of_limit": max(memory),
            "cpu_effective_cores_p95": percentile(effective_cores, 0.95),
            "cpu_effective_cores_peak": round(max(effective_cores), 2) if effective_cores else None,
            "oom_kill_delta": max(oom_kills) - min(oom_kills) if oom_kills else None,
            "cpu_throttled_usec_delta": max(throttled) - min(throttled) if throttled else None,
            "cpu_throttled_period_fraction": round(throttled_delta / period_delta, 4) if period_delta else None,
        }
    host_cpu = [sample["cpu_percent"] for sample in host if sample["cpu_percent"] is not None]
    swap_in = (host[-1]["swap_pages_in"] - host[0]["swap_pages_in"]
               if all("swap_pages_in" in sample for sample in host) else None)
    swap_out = (host[-1]["swap_pages_out"] - host[0]["swap_pages_out"]
                if all("swap_pages_out" in sample for sample in host) else None)
    return {
        "samples": len(records),
        "first_utc": records[0]["time_utc"], "last_utc": records[-1]["time_utc"],
        "host_min_available_mib": round(min(sample["available_kib"] for sample in host) / 1024, 1),
        "host_max_swap_used_mib": round(max(sample["swap_used_kib"] for sample in host) / 1024, 1),
        "host_swap_pages_in_delta": swap_in,
        "host_swap_pages_out_delta": swap_out,
        "host_cpu_p95_pct": percentile(host_cpu, 0.95),
        "containers": containers,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("path", type=Path)
    args = parser.parse_args()
    print(json.dumps(summarize(args.path), sort_keys=True))


if __name__ == "__main__":
    main()
