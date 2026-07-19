"""Generate readable split panels for IEEE Fig. 1."""
from pathlib import Path
import textwrap

from PIL import Image, ImageDraw, ImageFont


OUT_DIR = Path("Document/paper/figures")
PANEL_SIZE = (1350, 850)
PREVIEW_SIZE = (2820, 1840)


def font(name, size):
    candidates = [
        Path("C:/Windows/Fonts") / name,
        Path("C:/Windows/Fonts/arial.ttf"),
    ]
    for candidate in candidates:
        if candidate.exists():
            return ImageFont.truetype(str(candidate), size)
    return ImageFont.load_default()


FONT_TITLE = font("arialbd.ttf", 58)
FONT_SUBTITLE = font("arialbd.ttf", 40)
FONT_BODY = font("arial.ttf", 60)
FONT_FOOT = font("arial.ttf", 46)
FONT_BADGE = font("arialbd.ttf", 58)


PHASES = [
    {
        "file": "workflow-phase1.png",
        "badge": "P1",
        "title": "Baseline Analysis",
        "subtitle": "Branch: baseline-v0.1",
        "bullets": [
            "Run SonarQube quality scan.",
            "Run ZAP security scans.",
            "Run JMeter load profiles.",
            "Record baseline metrics.",
        ],
        "foot": "Output: baseline evidence.",
        "fill": "#D9E8FB",
        "edge": "#1F4E79",
    },
    {
        "file": "workflow-phase2.png",
        "badge": "P2",
        "title": "LLM-Guided Improvements",
        "subtitle": "Branches: sonarqube-v1, zap-v1, jmeter-v1",
        "bullets": [
            "Prompt ChatGPT with tool output.",
            "Apply targeted fixes.",
            "Use one branch per tool.",
            "Review before accepting.",
        ],
        "foot": "Output: isolated fix branches.",
        "fill": "#FFE9CC",
        "edge": "#C55A11",
    },
    {
        "file": "workflow-phase3.png",
        "badge": "P3",
        "title": "Post-Improvement Testing",
        "subtitle": "Re-run the same measurement suite",
        "bullets": [
            "Re-run SonarQube.",
            "Re-run ZAP scans.",
            "Re-run JMeter profiles.",
            "Keep the same test setup.",
        ],
        "foot": "Output: after-state metrics.",
        "fill": "#E2F0D9",
        "edge": "#375623",
    },
    {
        "file": "workflow-phase4.png",
        "badge": "P4",
        "title": "Comparative Analysis",
        "subtitle": "Deliverable: baseline-comparison-report",
        "bullets": [
            "Compare before vs. after.",
            "Classify PASS / Improved / FAIL.",
            "Report security closure.",
            "Report latency and errors.",
        ],
        "foot": "Output: evidence for claims.",
        "fill": "#F4DDEB",
        "edge": "#7030A0",
    },
]


def draw_wrapped(draw, xy, text, font_obj, fill, width, line_spacing=12):
    x, y = xy
    words_per_line = max(18, int(width / (font_obj.size * 0.50)))
    lines = []
    for paragraph in text.split("\n"):
        lines.extend(textwrap.wrap(paragraph, width=words_per_line) or [""])
    for line in lines:
        draw.text((x, y), line, font=font_obj, fill=fill)
        y += font_obj.size + line_spacing
    return y


def rounded_rect(draw, box, radius, fill, outline, width):
    draw.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)


def make_panel(phase):
    image = Image.new("RGB", PANEL_SIZE, "white")
    draw = ImageDraw.Draw(image)
    margin = 56
    rounded_rect(
        draw,
        (margin, margin, PANEL_SIZE[0] - margin, PANEL_SIZE[1] - margin),
        44,
        phase["fill"],
        phase["edge"],
        8,
    )

    badge_box = (86, 86, 238, 220)
    draw.rounded_rectangle(badge_box, radius=30, fill=phase["edge"])
    bbox = draw.textbbox((0, 0), phase["badge"], font=FONT_BADGE)
    draw.text(
        (
            badge_box[0] + (badge_box[2] - badge_box[0] - (bbox[2] - bbox[0])) / 2,
            badge_box[1] + (badge_box[3] - badge_box[1] - (bbox[3] - bbox[1])) / 2 - 3,
        ),
        phase["badge"],
        font=FONT_BADGE,
        fill="white",
    )

    draw_wrapped(draw, (270, 78), phase["title"], FONT_TITLE, phase["edge"], 820, 4)
    draw_wrapped(draw, (272, 172), phase["subtitle"], FONT_SUBTITLE, "#222222", 930, 4)

    y = 292
    for bullet in phase["bullets"]:
        draw.ellipse((130, y + 28, 158, y + 56), fill=phase["edge"])
        y = draw_wrapped(draw, (190, y), bullet, FONT_BODY, "#222222", 1040, 14)
        y += 18

    draw.line((112, 690, 1238, 690), fill=phase["edge"], width=5)
    draw_wrapped(draw, (122, 728), phase["foot"], FONT_FOOT, "#222222", 1060, 10)
    return image


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    panels = []
    for phase in PHASES:
        panel = make_panel(phase)
        panel.save(OUT_DIR / phase["file"], quality=95)
        panels.append(panel)

    preview = Image.new("RGB", PREVIEW_SIZE, "white")
    slots = [(0, 0), (1440, 0), (0, 940), (1440, 940)]
    for panel, (x, y) in zip(panels, slots):
        preview.paste(panel.resize((1380, 870), Image.Resampling.LANCZOS), (x, y))
    preview.save(OUT_DIR / "workflow-split-preview.png", quality=95)

    for phase in PHASES:
        print(OUT_DIR / phase["file"])
    print(OUT_DIR / "workflow-split-preview.png")


if __name__ == "__main__":
    main()
