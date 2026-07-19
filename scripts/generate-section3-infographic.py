"""Generate a 4-phase research workflow infographic for Section 3.1."""
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch

OUT_PATH = "Document/unpacked_updated/word/media/image_section31_workflow.png"

fig, ax = plt.subplots(figsize=(12, 9), dpi=200)
ax.set_xlim(0, 12)
ax.set_ylim(0, 9)
ax.axis("off")

# Title
ax.text(6, 8.55, "Section 3.1 — Overall Research Experiment Workflow",
        ha="center", va="center", fontsize=17, fontweight="bold", color="#1F3864")
ax.text(6, 8.15, "ChatGPT (Codex 5.4) Evaluation on Financial Accounting ASP.NET Core RESTful API",
        ha="center", va="center", fontsize=10.5, style="italic", color="#444444")

# Phase box colors
PHASE_COLORS = {
    "p1": ("#D9E8FB", "#1F4E79"),  # baseline
    "p2": ("#FFE9CC", "#C55A11"),  # ChatGPT improvement
    "p3": ("#E2F0D9", "#375623"),  # post-improvement
    "p4": ("#F4DDEB", "#7030A0"),  # comparative analysis
}

def phase_box(x, y, w, h, title, subtitle, bullets, color_key):
    fill, edge = PHASE_COLORS[color_key]
    box = FancyBboxPatch(
        (x, y), w, h,
        boxstyle="round,pad=0.04,rounding_size=0.18",
        linewidth=1.8, edgecolor=edge, facecolor=fill
    )
    ax.add_patch(box)
    ax.text(x + 0.18, y + h - 0.28, title, fontsize=12, fontweight="bold", color=edge, va="top")
    ax.text(x + 0.18, y + h - 0.68, subtitle, fontsize=9.3, fontweight="bold",
            color="#222222", va="top")
    for i, b in enumerate(bullets):
        ax.text(x + 0.22, y + h - 1.05 - i * 0.34, u"• " + b,
                fontsize=8.6, color="#2A2A2A", va="top")

# Phase 1
phase_box(
    0.35, 4.55, 5.6, 3.15,
    "PHASE 1 — Baseline Analysis",
    "Branch: baseline-v0.1",
    [
        "Static analysis: SonarQube (code quality)",
        "Security scan: OWASP ZAP (baseline + auth API)",
        "Load test: JMeter (50 / 100 / 500 users, soak, spike)",
        "Targets: auth, accounts, journal-entries, reports, audit-logs",
        "Output: reference metrics for later comparison",
    ],
    "p1",
)

# Phase 2
phase_box(
    6.05, 4.55, 5.6, 3.15,
    "PHASE 2 — ChatGPT-Generated Improvements",
    "Branches: baseline-sonarqube-v1 | zap-v1 | jmeter-v1",
    [
        "Model: ChatGPT (Codex 5.4)",
        "Security fixes: parameterized queries, auth hardening",
        "Quality fixes: smells, duplication, complexity",
        "Performance: caching, query tuning, async I/O",
        "One tool per branch for clear A/B isolation",
    ],
    "p2",
)

# Phase 3
phase_box(
    0.35, 1.25, 5.6, 3.15,
    "PHASE 3 — Post-Improvement Testing",
    "Re-run same suite on each fix branch",
    [
        "SonarQube re-scan on baseline-sonarqube-v1",
        "ZAP baseline + authenticated API re-scan on -zap-v1",
        "JMeter matrix re-run on -jmeter-v1",
        "Identical configuration and endpoints as Phase 1",
        "Ensures apples-to-apples measurement",
    ],
    "p3",
)

# Phase 4
phase_box(
    6.05, 1.25, 5.6, 3.15,
    "PHASE 4 — Comparative Analysis & Reporting",
    "Deliverable: baseline-comparison-report",
    [
        "Delta vs baseline across 3 dimensions",
        "Security: alerts by risk level (High/Med/Low)",
        "Performance: throughput, latency, error rate",
        "Quality: bugs, vulnerabilities, code smells",
        "Conclusion on ChatGPT's effectiveness",
    ],
    "p4",
)

# Arrows connecting phases
def arrow(x1, y1, x2, y2, color="#555555"):
    ax.add_patch(FancyArrowPatch(
        (x1, y1), (x2, y2),
        arrowstyle="-|>", mutation_scale=22,
        linewidth=2, color=color,
    ))

# P1 -> P2 (horizontal)
arrow(5.95, 6.12, 6.05, 6.12, "#1F4E79")
# P2 -> P3 (diagonal down-left)
arrow(6.05, 4.55, 5.95, 4.40, "#C55A11")
# Actually we want a cleaner flow. Let's do P1->P2 (right), P2->P3 (down via middle), P3->P4 (right)
# Reset by overlaying cleaner arrows
# Vertical arrow P2 -> P4 (same column) and P1 -> P3 (same column)
arrow(3.15, 4.55, 3.15, 4.40, "#1F4E79")  # P1 down to P3
arrow(8.85, 4.55, 8.85, 4.40, "#C55A11")  # P2 down to P4
# P3 -> P4 horizontal
arrow(5.95, 2.82, 6.05, 2.82, "#375623")

# Tools strip (top band)
tools_y = 0.15
tools_box = FancyBboxPatch(
    (0.35, tools_y), 11.3, 0.85,
    boxstyle="round,pad=0.04,rounding_size=0.12",
    linewidth=1.2, edgecolor="#8497B0", facecolor="#F2F2F2"
)
ax.add_patch(tools_box)
ax.text(0.55, tools_y + 0.55, "Tooling:", fontsize=10, fontweight="bold", color="#1F3864")
ax.text(1.5, tools_y + 0.55, "SonarQube  |  OWASP ZAP  |  Apache JMeter  |  ChatGPT (Codex 5.4)  |  Git branch-based A/B isolation",
        fontsize=9.3, color="#222222")
ax.text(0.55, tools_y + 0.2, "API under test:", fontsize=9.3, fontweight="bold", color="#1F3864")
ax.text(2.05, tools_y + 0.2,
        "ASP.NET Core RESTful API  —  JWT auth, RBAC (Admin/FinanceManager/User/Auditor), audit logging",
        fontsize=9, color="#222222")

plt.tight_layout()
plt.savefig(OUT_PATH, dpi=200, bbox_inches="tight", facecolor="white")
print(f"Saved: {OUT_PATH}")
