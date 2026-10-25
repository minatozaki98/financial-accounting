"""Render the three valid normal-load JMeter pairs as a thesis-ready figure."""

import argparse
import json
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D

from run_matrix import DEFAULT_STATE


PROFILES = (("p50", 50, 300), ("p100", 100, 500), ("p500", 500, 1200))


def paired_p95(evidence: Path, profile: str) -> list[tuple[int, int]]:
    pairs = []
    for repeat in (1, 2, 3):
        marker = json.loads((evidence / f"{profile}-r{repeat}-pair.json").read_text(
            encoding="utf-8"))
        runs = {run["side"]: run["run_id"] for run in marker["runs"]}
        if set(runs) != {"before", "after"}:
            raise ValueError(f"{profile} repeat {repeat} is not a complete pair")
        values = []
        for side in ("before", "after"):
            summary = json.loads((evidence / runs[side] / "summary.json").read_text(
                encoding="utf-8"))
            if not summary["valid_run"]:
                raise ValueError(f"{runs[side]} is not measurement-valid")
            values.append(summary["hold"]["p95_ms"])
        pairs.append((values[0], values[1]))
    return pairs


def render(evidence: Path, output: Path) -> None:
    plt.rcParams.update({"font.family": "DejaVu Sans", "font.size": 10,
                         "axes.spines.top": False, "axes.spines.right": False})
    fig, axes = plt.subplots(1, 3, figsize=(10.8, 4.15), constrained_layout=True)
    colors = ("#59748e", "#a66a44", "#6c697b")
    for ax, (profile, users, gate) in zip(axes, PROFILES):
        pairs = paired_p95(evidence, profile)
        for repeat, ((before, after), color) in enumerate(zip(pairs, colors), 1):
            ax.plot((0, 1), (before, after), marker="o", markersize=6, linewidth=1.4,
                    color=color, label=f"Repeat {repeat}")
        ax.axhline(gate, color="#222222", linestyle="--", linewidth=1,
                   label="Predeclared p95 limit")
        ax.text(0.02 if users == 500 else 0.98, gate * 1.07,
                f"limit {gate:,} ms", ha="left" if users == 500 else "right",
                va="bottom",
                transform=ax.get_yaxis_transform(), fontsize=8, color="#222222")
        ax.set_yscale("log")
        ax.set_xlim(-0.16, 1.16)
        ax.set_xticks((0, 1), ("Before", "After"))
        ax.set_title(f"{users} active users", fontweight="bold")
        ax.grid(axis="y", which="both", alpha=0.18)
        ax.set_ylabel("Scored p95 latency (ms, log scale)")
        ax.text(0.5, -0.17, f"After gate: {sum(a <= gate for _, a in pairs)}/3 pass",
                transform=ax.transAxes, ha="center", fontsize=9)
    fig.suptitle("Controlled ASP.NET Core before/after normal-load latency",
                 fontsize=13, fontweight="bold")
    fig.legend(handles=[Line2D((0,), (0,), color=c, marker="o", label=f"Repeat {i}")
                        for i, c in enumerate(colors, 1)] +
               [Line2D((0,), (0,), color="#222222", linestyle="--",
                       label="Predeclared p95 limit")],
               loc="lower center", ncol=4, bbox_to_anchor=(0.5, -0.1), frameon=False)
    output.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(output, dpi=300, bbox_inches="tight", facecolor="white")
    plt.close(fig)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--state-dir", type=Path, default=DEFAULT_STATE)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    render(args.state_dir / "evidence/matrix", args.output)
    print(args.output)


if __name__ == "__main__":
    main()
