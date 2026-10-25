"""Compare all valid three-repeat before/after JMeter pairs without cherry-picking."""

import argparse
import json
from pathlib import Path
from statistics import median

from run_matrix import DEFAULT_STATE, PROFILES


STATIC_GATES = {"p50": (300, 0.5), "p100": (500, 1.0), "p500": (1200, 2.0)}


def primary(summary: dict, profile: str) -> dict:
    if profile == "spike":
        peak = summary["phases"]["peak"]
        return {"p95_ms": peak["p95_ms"], "p99_ms": peak["p99_ms"],
                "error_pct": summary["scored_error_pct"],
                "requests_per_second": peak["requests_per_second"],
                "endpoints": peak["endpoints"],
                "drift_pct": summary["recovery_p95_drift_pct"]}
    hold = summary["hold"]
    return {"p95_ms": hold["p95_ms"], "p99_ms": hold["p99_ms"],
            "error_pct": hold["error_pct"],
            "requests_per_second": hold["requests_per_second"],
            "endpoints": summary["endpoints"],
            "drift_pct": summary.get("soak", {}).get("p95_drift_pct")}


def gate_passes(summary: dict, profile: str) -> bool:
    if profile in STATIC_GATES:
        max_p95, max_errors = STATIC_GATES[profile]
        return summary["hold"]["p95_ms"] <= max_p95 and summary["hold"]["error_pct"] <= max_errors
    return all(summary["performance_gates"].values())


def active_users(summary: dict, profile: str) -> dict:
    concurrency = summary["concurrency"]["peak"] if profile == "spike" else summary["concurrency"]
    return {key: concurrency[key] for key in
            ("observed_peak", "min_hold_active", "median_hold_active", "full_bins", "hold_bins")}


def spread(values: list[float]) -> dict:
    return {"median": round(median(values), 3),
            "minimum": round(min(values), 3), "maximum": round(max(values), 3),
            "values": values}


def compare(state: Path) -> dict:
    evidence = state / "evidence/matrix"
    missing = []
    result = {}
    for profile in PROFILES:
        paired = []
        for repeat in (1, 2, 3):
            marker = evidence / f"{profile}-r{repeat}-pair.json"
            if not marker.is_file():
                missing.append(marker.name)
                continue
            pair = json.loads(marker.read_text(encoding="utf-8"))
            sides = {item["side"]: item["run_id"] for item in pair["runs"]}
            if set(sides) != {"before", "after"}:
                raise ValueError(f"{marker.name} lacks one source side")
            observations = {}
            for side, run_id in sides.items():
                summary = json.loads((evidence / run_id / "summary.json").read_text(encoding="utf-8"))
                if not summary["valid_run"]:
                    raise ValueError(f"invalid run was marked complete: {run_id}")
                observations[side] = {"run_id": run_id, "summary": summary,
                                      "primary": primary(summary, profile),
                                      "passes_gate": gate_passes(summary, profile)}
            paired.append({"repeat": repeat, "execution_order": pair["order"], **observations})
        if len(paired) != 3:
            continue
        metrics = {}
        for metric in ("p95_ms", "p99_ms", "error_pct", "requests_per_second"):
            before = [pair["before"]["primary"][metric] for pair in paired]
            after = [pair["after"]["primary"][metric] for pair in paired]
            if any(value is None for value in before + after):
                raise ValueError(f"missing {metric} in {profile}")
            percent_changes = [round(100 * (a - b) / b, 3) if b else None
                               for b, a in zip(before, after)]
            metrics[metric] = {"before": spread(before), "after": spread(after),
                               "paired_percent_changes": percent_changes,
                               "median_paired_percent_change": round(median(
                                   value for value in percent_changes if value is not None), 3)
                               if any(value is not None for value in percent_changes) else None}
        endpoints = {}
        labels = sorted({label for pair in paired for side in ("before", "after")
                         for label in pair[side]["primary"]["endpoints"]})
        for label in labels:
            by_side = {}
            for side in ("before", "after"):
                observations = [pair[side]["primary"]["endpoints"].get(label)
                                for pair in paired]
                if any(item is None for item in observations):
                    by_side[side] = None
                    continue
                by_side[side] = {
                    metric: spread([item[metric] for item in observations])
                    for metric in ("p95_ms", "p99_ms")
                }
                by_side[side]["total_samples"] = sum(item["samples"] for item in observations)
                by_side[side]["total_errors"] = sum(item["errors"] for item in observations)
            endpoints[label] = by_side
        result[profile] = {
            "valid_pairs": 3,
            "order": [pair["execution_order"] for pair in paired],
            "gate_passes": {side: sum(pair[side]["passes_gate"] for pair in paired)
                            for side in ("before", "after")},
            "active_users": {
                side: [active_users(pair[side]["summary"], profile) for pair in paired]
                for side in ("before", "after")
            },
            "metrics": metrics,
            "endpoints": endpoints,
            "drift_pct": {
                side: [pair[side]["primary"]["drift_pct"] for pair in paired]
                for side in ("before", "after")
            } if profile in ("soak", "spike") else None,
            "legacy_drift_pct": {
                side: [pair[side]["summary"]["legacy_first_last_20pct_samples"]["drift_pct"]
                       for pair in paired]
                for side in ("before", "after")
            } if profile in ("soak", "spike") else None,
        }
    if missing:
        raise ValueError("comparison is incomplete; missing pairs: " + ", ".join(missing))
    return {"profiles": result, "source_revisions": json.loads(
        (Path(__file__).resolve().parents[3] /
         "Document/experiments/jmeter-cloud-20261023/source-revisions.json").read_text())}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--state-dir", type=Path, default=DEFAULT_STATE)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    data = compare(args.state_dir.resolve())
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
    print(f"compared {len(data['profiles'])} profiles across three paired repeats")


if __name__ == "__main__":
    main()
