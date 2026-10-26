"""Summarize fixed-cap CPU and RAM evidence for the five valid JMeter profiles."""

import argparse
import csv
import json
from pathlib import Path
from statistics import median

from run_matrix import DEFAULT_STATE


PROFILES = ("p50", "p100", "p500", "soak", "spike")
CONTAINERS = {
    "api": ("target", "jmeter-research-api-1"),
    "sql": ("target", "jmeter-research-sql-1"),
    "generator": ("generator", "jmeter-research-jmeter"),
}


def resource(profile: str, evidence: Path) -> dict:
    sides = {"before": [], "after": []}
    for repeat in (1, 2, 3):
        pair = json.loads((evidence / f"{profile}-r{repeat}-pair.json").read_text(
            encoding="utf-8"))
        if {run["side"] for run in pair["runs"]} != {"before", "after"}:
            raise ValueError(f"incomplete {profile} repeat {repeat}")
        for run in pair["runs"]:
            data = json.loads((evidence / run["run_id"] / "resource-summary.json").read_text(
                encoding="utf-8"))
            sides[run["side"]].append(data)

    def med(side: str, container: str, metric: str) -> float:
        role, name = CONTAINERS[container]
        return median(d[role]["scored_hold"]["containers"][name][metric]
                      for d in sides[side])

    docs = sides["before"] + sides["after"]
    hosts = [d[role]["full"] for d in docs for role in ("target", "generator")]
    containers = [item for host in hosts for item in host["containers"].values()]
    return {
        "profile": profile,
        "api_p95_cpu_cores_before": round(med("before", "api", "cpu_effective_cores_p95"), 3),
        "api_p95_cpu_cores_after": round(med("after", "api", "cpu_effective_cores_p95"), 3),
        "sql_p95_cpu_cores_before": round(med("before", "sql", "cpu_effective_cores_p95"), 3),
        "sql_p95_cpu_cores_after": round(med("after", "sql", "cpu_effective_cores_p95"), 3),
        "generator_p95_cpu_cores_after": round(med("after", "generator", "cpu_effective_cores_p95"), 3),
        "sql_throttled_period_pct_before": round(100 * med("before", "sql", "cpu_throttled_period_fraction"), 2),
        "sql_throttled_period_pct_after": round(100 * med("after", "sql", "cpu_throttled_period_fraction"), 2),
        "api_peak_ram_pct_cap_after": round(med("after", "api", "memory_peak_pct_of_limit"), 1),
        "sql_peak_ram_pct_cap_after": round(med("after", "sql", "memory_peak_pct_of_limit"), 1),
        "generator_peak_ram_pct_cap_after": round(med("after", "generator", "memory_peak_pct_of_limit"), 1),
        "minimum_host_available_mib": round(min(host["host_min_available_mib"] for host in hosts), 1),
        "maximum_host_swap_used_mib": max(host["host_max_swap_used_mib"] for host in hosts),
        "maximum_container_oom_kills": max(item["oom_kill_delta"] for item in containers),
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--state-dir", type=Path, default=DEFAULT_STATE)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    rows = [resource(profile, args.state_dir / "evidence/matrix") for profile in PROFILES]
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", encoding="utf-8", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)
    print(f"wrote {len(rows)} resource profiles to {args.output}")


if __name__ == "__main__":
    main()
