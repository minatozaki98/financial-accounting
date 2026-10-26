"""Publication figure: human decisions, AI proposal, and automated evidence."""

from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyArrowPatch, FancyBboxPatch


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "Document/outputs/figures/research-workflow-committee.png"

steps = [
    ("1", "HUMAN", "Define scope and gates",
     "One API, seven groups; freeze source, data, caps and pass limits"),
    ("2", "AUTOMATED", "Capture baseline",
     "SonarQube/ZAP locally; JMeter cloud; save raw output and hashes"),
    ("3", "AI ASSISTED", "Propose a bounded change",
     "Finding + code excerpt + constraints → candidate patch"),
    ("4", "HUMAN", "Review and apply",
     "Check contract, accounting, RBAC and scope; accept/revise/reject"),
    ("5", "AUTOMATED", "Verify with the same instrument",
     "Focused tests + same scan/load; p95/p99, users, errors, CPU/RAM"),
    ("6", "HUMAN", "Interpret and report",
     "PASS/PARTIAL/FAIL; retain regressions; cite and archive evidence"),
]

palette = {
    "HUMAN": ("#E9F0F7", "#315A7A"),
    "AUTOMATED": ("#E7F3EF", "#2F7065"),
    "AI ASSISTED": ("#FFF1D9", "#976016"),
}

fig, ax = plt.subplots(figsize=(7.5, 9.0), dpi=240)
ax.set_xlim(0, 1)
ax.set_ylim(0, 1)
ax.axis("off")
fig.patch.set_facecolor("white")
ax.text(0.5, 0.985, "Research framework and decision sequence",
        ha="center", va="top", fontsize=14, fontweight="bold", color="#1C2E3B")
ax.text(0.5, 0.945, "Automated measurements produce evidence; human review decides what is accepted",
        ha="center", va="top", fontsize=8.5, color="#475967")

ys = [0.80, 0.66, 0.52, 0.38, 0.24, 0.10]
h = 0.11
for (number, role, title, detail), y in zip(steps, ys):
    fill, edge = palette[role]
    box = FancyBboxPatch((0.07, y), 0.86, h,
                         boxstyle="round,pad=0.008,rounding_size=0.014",
                         linewidth=1.4, edgecolor=edge, facecolor=fill)
    ax.add_patch(box)
    ax.text(0.098, y + 0.072, number, ha="left", va="center", fontsize=15,
            fontweight="bold", color=edge)
    ax.text(0.156, y + 0.082, role, ha="left", va="center", fontsize=8.9,
            fontweight="bold", color=edge)
    ax.text(0.156, y + 0.058, title, ha="left", va="center", fontsize=11.2,
            fontweight="bold", color="#1C2E3B")
    ax.text(0.156, y + 0.023, detail, ha="left", va="center", fontsize=8.4,
            linespacing=1.1, color="#34434F")

for upper, lower in zip(ys[:-1], ys[1:]):
    ax.add_patch(FancyArrowPatch((0.5, upper - 0.007), (0.5, lower + h + 0.007),
                                 arrowstyle="-|>", mutation_scale=13,
                                 linewidth=1.5, color="#586B76"))

ax.text(0.5, 0.035,
        "If the human rejects a patch or a tool gate fails, return to step 3 with the finding and test evidence.",
        ha="center", va="center", fontsize=7.8, color="#475967")

OUT.parent.mkdir(parents=True, exist_ok=True)
fig.savefig(OUT, dpi=240, bbox_inches="tight", pad_inches=0.12)
plt.close(fig)
print(OUT)
