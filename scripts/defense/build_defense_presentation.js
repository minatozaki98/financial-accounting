const fs = require("fs");
const path = require("path");
const PptxGenJS = require("pptxgenjs");
const sharp = require("sharp");
const { COLORS, FONTS, LAYOUT, sectionColor } = require("./presentation_theme");

const ROOT = path.resolve(__dirname, "../..");
const CONTENT_PATH = path.join(__dirname, "defense_content.json");
const OUTPUT_PATH = path.join(
  ROOT,
  "Document",
  "outputs",
  "final-defense",
  "G6519692_Zaw_Ye_Htut_Ko_Final_Thesis_Defense.pptx"
);

function resolveAsset(relativePath) {
  const absolute = path.join(ROOT, ...relativePath.split("/"));
  if (!fs.existsSync(absolute)) throw new Error(`Missing evidence asset: ${relativePath}`);
  return absolute;
}

function textOptions(options = {}) {
  return {
    fontFace: FONTS.face,
    color: COLORS.text,
    margin: 0,
    breakLine: false,
    fit: "shrink",
    valign: "middle",
    ...options
  };
}

function addText(slide, text, options) {
  slide.addText(text, textOptions(options));
}

function addRect(slide, x, y, w, h, fill, line = COLORS.line, radius = false) {
  slide.addShape(radius ? "roundRect" : "rect", {
    x,
    y,
    w,
    h,
    rectRadius: radius ? 0.07 : undefined,
    fill: { color: fill },
    line: { color: line, width: line === fill ? 0 : 1 }
  });
}

function addFrame(slide, model, slideNumber) {
  slide.background = { color: COLORS.background };
  const accent = sectionColor(model.section || "Appendix");
  slide.addShape("rect", { x: 0, y: 0, w: 0.16, h: LAYOUT.height, fill: { color: accent }, line: { color: accent } });
  addText(slide, (model.section || "Appendix").toUpperCase(), {
    x: 0.68,
    y: 0.28,
    w: 2.7,
    h: 0.2,
    fontSize: 10,
    bold: true,
    color: accent,
    charSpacing: 1.6
  });
  addText(slide, model.title, {
    x: 0.68,
    y: 0.53,
    w: 11.75,
    h: 0.58,
    fontSize: FONTS.title,
    bold: true,
    color: COLORS.text,
    breakLine: false
  });
  slide.addShape("line", { x: 0.68, y: 1.16, w: 11.96, h: 0, line: { color: COLORS.line, width: 1 } });
  addSourceFooter(slide, model.evidenceRefs, slideNumber, accent);
}

function addSourceFooter(slide, evidenceRefs, slideNumber, accent) {
  slide.addShape("line", { x: 0.68, y: 7.08, w: 11.96, h: 0, line: { color: COLORS.line, width: 0.75 } });
  addText(slide, evidenceRefs.join(" | "), {
    x: 0.68,
    y: 7.13,
    w: 10.9,
    h: 0.16,
    fontSize: 8.5,
    color: COLORS.muted
  });
  addText(slide, String(slideNumber).padStart(2, "0"), {
    x: 11.85,
    y: 7.1,
    w: 0.75,
    h: 0.2,
    fontSize: 10,
    bold: true,
    align: "right",
    color: accent
  });
}

function addCard(slide, { x, y, w, h, title, body, accent = COLORS.methodology, fill = COLORS.surface, titleSize = 19, bodySize = 14 }) {
  addRect(slide, x, y, w, h, fill, COLORS.line, true);
  slide.addShape("rect", { x, y, w: 0.09, h, fill: { color: accent }, line: { color: accent } });
  addText(slide, title, { x: x + 0.24, y: y + 0.18, w: w - 0.4, h: 0.35, fontSize: titleSize, bold: true, color: COLORS.text });
  if (body) addText(slide, body, { x: x + 0.24, y: y + 0.62, w: w - 0.43, h: h - 0.8, fontSize: bodySize, color: COLORS.muted, valign: "top", breakLine: true });
}

function addMetric(slide, value, label, x, y, color, w = 2.7) {
  addRect(slide, x, y, w, 1.25, COLORS.surface, COLORS.line, true);
  addText(slide, value, { x: x + 0.12, y: y + 0.16, w: w - 0.24, h: 0.45, fontSize: FONTS.metric, bold: true, align: "center", color });
  addText(slide, label, { x: x + 0.16, y: y + 0.72, w: w - 0.32, h: 0.32, fontSize: 13, align: "center", color: COLORS.muted });
}

function addEvidenceTag(slide, text, x, y, color = COLORS.methodology, width = 2.3) {
  addRect(slide, x, y, width, 0.36, color, color, true);
  addText(slide, text, { x: x + 0.1, y: y + 0.05, w: width - 0.2, h: 0.22, fontSize: 10.5, bold: true, color: COLORS.surface, align: "center" });
}

function addBullets(slide, items, x, y, w, h, fontSize = FONTS.body, color = COLORS.text) {
  const runs = [];
  items.forEach((item, index) => {
    runs.push({ text: item, options: { bullet: { indent: 15 }, breakLine: index < items.length - 1, hanging: 4 } });
  });
  slide.addText(runs, textOptions({ x, y, w, h, fontSize, color, valign: "top", paraSpaceAfterPt: 12, breakLine: true }));
}

function addArrow(slide, x1, y1, x2, y2, color = COLORS.methodology, width = 2) {
  slide.addShape("line", {
    x: Math.min(x1, x2),
    y: Math.min(y1, y2),
    w: Math.abs(x2 - x1),
    h: Math.abs(y2 - y1),
    flipH: x2 < x1,
    flipV: y2 < y1,
    line: { color, width, beginArrowType: "none", endArrowType: "triangle" }
  });
}

async function addImageContain(slide, imagePath, x, y, w, h, options = {}) {
  const metadata = await sharp(imagePath).metadata();
  const imageRatio = metadata.width / metadata.height;
  const boxRatio = w / h;
  let drawW = w;
  let drawH = h;
  let drawX = x;
  let drawY = y;
  if (imageRatio > boxRatio) {
    drawH = w / imageRatio;
    drawY += (h - drawH) / 2;
  } else {
    drawW = h * imageRatio;
    drawX += (w - drawW) / 2;
  }
  if (options.frame !== false) addRect(slide, x, y, w, h, COLORS.surface, COLORS.line, true);
  slide.addImage({ path: imagePath, x: drawX, y: drawY, w: drawW, h: drawH, transparency: options.transparency || 0 });
}

function addTable(slide, headers, rows, options = {}) {
  const x = options.x ?? 0.75;
  const y = options.y ?? 1.55;
  const w = options.w ?? 11.82;
  const h = options.h ?? 4.9;
  const colW = options.colW || Array(headers.length).fill(w / headers.length);
  const data = [headers.map((text) => ({ text, options: { bold: true, color: COLORS.surface, fill: sectionColor(options.section || "Method") } }))];
  rows.forEach((row) => data.push(row.map((text) => String(text))));
  slide.addTable(data, {
    x,
    y,
    w,
    h,
    colW,
    border: { type: "solid", color: COLORS.line, pt: 0.8 },
    fill: COLORS.surface,
    color: COLORS.text,
    fontFace: FONTS.face,
    fontSize: options.fontSize || 14,
    margin: 0.09,
    valign: "middle",
    autoFit: false,
    rowH: options.rowH || 0.45,
    breakLine: false,
    bold: false
  });
}

function notesFor(model) {
  return [
    `TIMING: ${model.durationSeconds} seconds`,
    `KEY MESSAGE: ${model.keyMessage}`,
    "SCRIPT:",
    model.speakerNotes,
    `TRANSITION: ${model.transition}`,
    `CAUTION: ${model.overclaimWarning}`,
    `EVIDENCE: ${model.evidenceRefs.join(" | ")}`
  ].join("\n\n");
}

function addSimpleFlow(slide, labels, color, y = 3.1) {
  const gap = 0.22;
  const x0 = 0.8;
  const totalW = 11.72;
  const boxW = (totalW - gap * (labels.length - 1)) / labels.length;
  labels.forEach((label, index) => {
    const x = x0 + index * (boxW + gap);
    addRect(slide, x, y, boxW, 1.15, index % 2 === 0 ? COLORS.surface : COLORS.paleTeal, COLORS.line, true);
    addText(slide, label, { x: x + 0.12, y: y + 0.18, w: boxW - 0.24, h: 0.78, fontSize: 16, bold: true, align: "center", color });
    if (index < labels.length - 1) addArrow(slide, x + boxW + 0.02, y + 0.58, x + boxW + gap - 0.02, y + 0.58, color, 1.3);
  });
}

async function renderMainVisual(pptx, slide, model) {
  const c = model.visibleContent;
  switch (model.visual.type) {
    case "roadmap":
      addSimpleFlow(slide, c.stages, COLORS.text, 2.85);
      addText(slide, "Problem -> controlled method -> measured results -> model trade-offs -> defensible conclusion", { x: 1.2, y: 4.65, w: 10.9, h: 0.55, fontSize: 18, color: COLORS.muted, align: "center" });
      break;
    case "threePillars":
      c.pillars.forEach((item, index) => addCard(slide, { x: 0.8 + index * 4.12, y: 2.0, w: 3.72, h: 3.6, title: item.label, body: item.detail, accent: [COLORS.security, COLORS.performance, COLORS.methodology][index], titleSize: 24, bodySize: 18 }));
      break;
    case "gapComparison":
      addCard(slide, { x: 0.85, y: 1.75, w: 5.35, h: 4.55, title: "Dominant prior focus", body: c.left.join("\n\n"), accent: COLORS.muted, titleSize: 23, bodySize: 19 });
      addArrow(slide, 6.25, 4.0, 7.08, 4.0, COLORS.methodology, 2.5);
      addCard(slide, { x: 7.13, y: 1.75, w: 5.35, h: 4.55, title: "This thesis", body: c.right.join("\n\n"), accent: COLORS.methodology, fill: COLORS.paleTeal, titleSize: 23, bodySize: 19 });
      break;
    case "researchQuestions":
      c.questions.forEach((question, index) => addCard(slide, { x: 0.8 + index * 4.13, y: 1.8, w: 3.75, h: 4.7, title: `RQ${index + 1}`, body: question.replace(/^RQ\d+:\s*/, ""), accent: [COLORS.methodology, COLORS.security, COLORS.performance][index], titleSize: 25, bodySize: 17 }));
      break;
    case "apiMap":
      addRect(slide, 4.65, 2.55, 4.0, 1.3, COLORS.dark, COLORS.dark, true);
      addText(slide, "Financial Accounting API", { x: 4.9, y: 2.87, w: 3.5, h: 0.45, fontSize: 24, bold: true, color: COLORS.surface, align: "center" });
      c.groups.forEach((group, index) => {
        const left = index < 4;
        const row = left ? index : index - 4;
        const x = left ? 0.8 : 9.25;
        const y = 1.55 + row * 1.35;
        addCard(slide, { x, y, w: 3.25, h: 0.92, title: group, body: "", accent: left ? COLORS.methodology : COLORS.security, titleSize: 17 });
        addArrow(slide, left ? x + 3.25 : 9.2, y + 0.46, left ? 4.55 : 8.7, 3.18, COLORS.line, 1.2);
      });
      addEvidenceTag(slide, c.stack, 3.15, 5.85, COLORS.verified, 7.0);
      break;
    case "branchDiagram":
      addCard(slide, { x: 0.85, y: 2.55, w: 2.6, h: 1.4, title: c.baseline, body: "Shared starting point", accent: COLORS.text, titleSize: 19 });
      c.branches.forEach((branch, index) => {
        const y = 1.48 + index * 1.72;
        addArrow(slide, 3.55, 3.25, 5.05, y + 0.57, [COLORS.methodology, COLORS.security, COLORS.performance][index], 2);
        addCard(slide, { x: 5.1, y, w: 5.55, h: 1.15, title: branch, body: ["Static quality", "Security", "Performance"][index], accent: [COLORS.methodology, COLORS.security, COLORS.performance][index], titleSize: 18, bodySize: 13 });
      });
      addEvidenceTag(slide, c.control, 4.1, 6.25, COLORS.verified, 5.7);
      break;
    case "workflow":
      [
        ["01", "Capture baseline", "Preserve raw tool findings and environment state", COLORS.text],
        ["02", "Propose bounded fix", "Give the model the finding, source context, and constraints", COLORS.performance],
        ["03", "Human review and tests", "Protect authorization, accounting invariants, and contracts", COLORS.security],
        ["04", "Rerun and compare", "Accept only changes supported by the original measurement tool", COLORS.verified]
      ].forEach((phase, index) => {
        const x = 0.85 + (index % 2) * 6.0;
        const y = 1.45 + Math.floor(index / 2) * 2.5;
        addCard(slide, { x, y, w: 5.55, h: 2.05, title: `${phase[0]}  ${phase[1]}`, body: phase[2], accent: phase[3], titleSize: 21, bodySize: 16.5 });
      });
      addEvidenceTag(slide, "Finding -> patch -> tests -> remeasurement", 3.65, 6.42, COLORS.methodology, 5.9);
      await addImageContain(slide, resolveAsset(model.visual.asset), 10.85, 6.13, 1.35, 0.7, { frame: false });
      break;
    case "datasetFacts":
      c.metrics.forEach((metric, index) => addMetric(slide, metric.value, metric.label, 0.9 + index * 4.05, 1.75, COLORS.methodology, 3.55));
      c.facts.forEach((fact, index) => addCard(slide, { x: 0.9 + (index % 2) * 6.08, y: 3.65 + Math.floor(index / 2) * 1.25, w: 5.65, h: 0.93, title: fact, body: "", accent: index % 2 ? COLORS.performance : COLORS.verified, titleSize: 17 }));
      break;
    case "gateMatrix":
      c.gates.forEach((gate, index) => {
        const x = 0.75 + index * 2.5;
        addCard(slide, { x, y: 2.15, w: 2.2, h: 3.5, title: gate.tool, body: gate.measure, accent: [COLORS.methodology, COLORS.security, COLORS.performance, COLORS.verified, COLORS.text][index], titleSize: 18, bodySize: 16 });
      });
      addEvidenceTag(slide, "No single metric is overall quality", 4.45, 6.1, COLORS.text, 4.45);
      break;
    case "humanLoop":
      addSimpleFlow(slide, c.flow, COLORS.methodology, 2.55);
      addRect(slide, 2.2, 4.65, 8.95, 1.05, COLORS.paleGreen, COLORS.verified, true);
      addText(slide, c.boundary, { x: 2.45, y: 4.93, w: 8.45, h: 0.44, fontSize: 22, bold: true, color: COLORS.verified, align: "center" });
      break;
    case "barCompare":
      slide.addChart(pptx.ChartType.bar, [
        { name: "Before", labels: c.chart.categories, values: c.chart.before },
        { name: "After", labels: c.chart.categories, values: c.chart.after }
      ], { x: 0.8, y: 1.55, w: 7.15, h: 4.7, catAxisLabelFontFace: FONTS.face, catAxisLabelFontSize: 15, valAxisLabelFontFace: FONTS.face, valAxisLabelFontSize: 12, showLegend: true, legendPos: "b", chartColors: [COLORS.security, COLORS.verified], showValue: true, showTitle: false, showCatName: false, showSerName: false, showValue: true, dataLabelPosition: "outEnd", showValAxisTitle: false, showCatAxisTitle: false, valGridLine: { color: COLORS.line, width: 1 }, showBorder: false, showValue: true });
      c.metrics.forEach((metric, index) => addCard(slide, { x: 8.35, y: 1.65 + index * 1.48, w: 4.05, h: 1.08, title: metric, body: "", accent: COLORS.verified, titleSize: 16 }));
      break;
    case "securitySeverity":
      addCard(slide, { x: 0.85, y: 1.55, w: 5.72, h: 4.9, title: "Baseline scan", body: `Medium  ${c.baseline.medium[0]} -> ${c.baseline.medium[1]}\n\nLow  ${c.baseline.low[0]} -> ${c.baseline.low[1]}\n\nInformational  ${c.baseline.informational[0]} -> ${c.baseline.informational[1]}`, accent: COLORS.security, fill: COLORS.paleRed, titleSize: 24, bodySize: 23 });
      addCard(slide, { x: 6.78, y: 1.55, w: 5.72, h: 4.9, title: "Authenticated API scan", body: `Low  ${c.authenticated.low[0]} -> ${c.authenticated.low[1]}\n\nInformational  ${c.authenticated.informational[0]} -> ${c.authenticated.informational[1]}\n\n${c.result}`, accent: COLORS.verified, fill: COLORS.paleGreen, titleSize: 24, bodySize: 21 });
      break;
    case "loadProfiles":
      c.profiles.forEach((profile, index) => {
        const x = 0.78 + index * 2.5;
        addMetric(slide, profile.name, profile.purpose, x, 2.15, index < 3 ? COLORS.methodology : COLORS.performance, 2.18);
      });
      addSimpleFlow(slide, c.metrics, COLORS.text, 4.45);
      break;
    case "performanceChart": {
      const reductions = c.chart.before.map((value, index) => Number(((value - c.chart.after[index]) / value * 100).toFixed(1)));
      slide.addChart(pptx.ChartType.bar, [{ name: "p95 reduction", labels: c.chart.categories, values: reductions }], { x: 0.85, y: 1.55, w: 7.2, h: 4.8, catAxisLabelFontFace: FONTS.face, catAxisLabelFontSize: 14, valAxisLabelFontFace: FONTS.face, valAxisLabelFontSize: 11, valAxisMinVal: 0, valAxisMaxVal: 100, valAxisLabelFormatCode: "0.0\"%\"", showLegend: false, chartColors: [COLORS.performance], showValue: true, dataLabelPosition: "outEnd", dataLabelFormatCode: "0.0\"%\"", valGridLine: { color: COLORS.line, width: 1 }, showBorder: false });
      addCard(slide, { x: 8.35, y: 1.65, w: 4.0, h: 1.55, title: "Core reliability", body: c.callout, accent: COLORS.verified, fill: COLORS.paleGreen, titleSize: 20, bodySize: 17 });
      addCard(slide, { x: 8.35, y: 3.55, w: 4.0, h: 2.15, title: "Caveat retained", body: c.caveat, accent: COLORS.security, fill: COLORS.paleRed, titleSize: 20, bodySize: 17 });
      break;
    }
    case "integrityChecklist":
      c.checks.forEach((check, index) => {
        const x = 0.85 + (index % 2) * 6.05;
        const y = 1.45 + Math.floor(index / 2) * 1.28;
        addCard(slide, { x, y, w: 5.65, h: 0.98, title: `CHECK ${String(index + 1).padStart(2, "0")}`, body: check, accent: COLORS.verified, titleSize: 11, bodySize: 18 });
      });
      break;
    case "screenshotGrid":
      for (let index = 0; index < c.screens.length; index += 1) {
        const screen = c.screens[index];
        const x = 0.78 + (index % 2) * 6.22;
        const y = 1.35 + Math.floor(index / 2) * 2.75;
        await addImageContain(slide, resolveAsset(screen.asset), x, y, 5.85, 2.25);
        addText(slide, screen.caption, { x, y: y + 2.3, w: 5.85, h: 0.27, fontSize: 11.5, bold: true, align: "center", color: COLORS.muted });
      }
      break;
    case "modelComparison":
      addTable(slide, ["Area", "GPT-5.4", "GPT-5.5", "Reading"], c.rows.map((r) => [r.area, r.gpt54, r.gpt55, r.reading]), { x: 0.78, y: 1.55, w: 11.8, h: 4.9, colW: [1.55, 3.45, 3.45, 3.35], fontSize: 15, rowH: 0.86, section: "Comparison" });
      break;
    case "v2Scorecard":
      addTable(slide, ["Measure", "GPT-5.4", "GPT-5.5"], c.scorecard.map((r) => [r.measure, r.gpt54, r.gpt55]), { x: 1.2, y: 1.45, w: 10.9, h: 5.25, colW: [3.6, 3.65, 3.65], fontSize: 16, rowH: 0.72, section: "Comparison" });
      break;
    case "contributions":
      c.contributions.forEach((item, index) => addCard(slide, { x: 0.8 + index * 4.13, y: 1.75, w: 3.75, h: 4.85, title: item.label, body: item.detail, accent: [COLORS.methodology, COLORS.verified, COLORS.performance][index], titleSize: 23, bodySize: 18 }));
      break;
    case "limitationMap":
      c.pairs.forEach((pair, index) => {
        const y = 1.4 + index * 1.05;
        addRect(slide, 0.8, y, 5.65, 0.82, COLORS.paleRed, COLORS.line, true);
        addRect(slide, 6.9, y, 5.65, 0.82, COLORS.paleGreen, COLORS.line, true);
        addText(slide, pair.limitation, { x: 0.98, y: y + 0.12, w: 5.25, h: 0.55, fontSize: 15.5, color: COLORS.security, bold: true });
        addArrow(slide, 6.48, y + 0.41, 6.86, y + 0.41, COLORS.muted, 1.2);
        addText(slide, pair.future, { x: 7.08, y: y + 0.12, w: 5.25, h: 0.55, fontSize: 15.5, color: COLORS.verified, bold: true });
      });
      addText(slide, "LIMITATION", { x: 0.8, y: 6.7, w: 5.65, h: 0.2, fontSize: 9, bold: true, color: COLORS.security, align: "center" });
      addText(slide, "NEXT EVIDENCE", { x: 6.9, y: 6.7, w: 5.65, h: 0.2, fontSize: 9, bold: true, color: COLORS.verified, align: "center" });
      break;
    case "conclusion":
      c.takeaways.forEach((takeaway, index) => addCard(slide, { x: 0.9, y: 1.45 + index * 1.3, w: 11.5, h: 0.95, title: `${index + 1}`, body: takeaway, accent: COLORS.verified, titleSize: 19, bodySize: 19 }));
      addRect(slide, 2.15, 5.65, 9.0, 0.88, COLORS.dark, COLORS.dark, true);
      addText(slide, c.closing, { x: 2.4, y: 5.85, w: 8.5, h: 0.4, fontSize: 24, bold: true, align: "center", color: COLORS.surface });
      break;
    default:
      addBullets(slide, Object.values(c).flat().map(String), 0.9, 1.6, 11.4, 4.9, 20);
  }
}

async function renderAppendixVisual(slide, model) {
  const c = model.visibleContent;
  if (model.visual.type === "dataTable") {
    addTable(slide, c.headers, c.rows, { x: 0.8, y: 1.4, w: 11.75, h: 5.4, fontSize: 15, rowH: 0.62, section: "Appendix" });
  } else if (model.visual.type === "roleMatrix") {
    addTable(slide, ["Endpoint group", ...c.roles], c.groups.map((group, index) => [group, index < 6 ? "Full" : "Admin", index === 6 ? "Read" : "Role-based", "Own scope", index >= 2 ? "Read" : "Limited"]), { x: 0.72, y: 1.4, w: 8.35, h: 5.2, colW: [2.3, 1.45, 1.65, 1.4, 1.55], fontSize: 12.5, rowH: 0.55 });
    await addImageContain(slide, resolveAsset("Document/outputs/web-app-evidence/01-login.png"), 9.35, 1.55, 3.0, 2.0);
    await addImageContain(slide, resolveAsset("Document/outputs/web-app-evidence/04-audit-logs.png"), 9.35, 4.0, 3.0, 2.0);
  } else if (model.visual.type === "provenanceTable") {
    addTable(slide, ["Track", "Branch", "Evidence"], [["Original baseline", "baseline-v0.1", "Shared starting point"], ["Original Sonar", "baseline-sonarqube-v1", "Static-quality rerun"], ["Original ZAP", "baseline-zap-v1", "Baseline and authenticated scans"], ["Original JMeter", "baseline-jmeter-v1", "Five workload profiles"], ["GPT-5.5 comparison", "codex/gpt-5.5-comparison", "Paired model evidence"]], { x: 0.9, y: 1.6, w: 11.5, h: 4.5, colW: [2.5, 4.2, 4.8], fontSize: 15, rowH: 0.7 });
  } else if (model.visual.type === "threatsGrid") {
    c.groups.forEach((group, index) => addCard(slide, { x: 0.8 + (index % 2) * 6.05, y: 1.4 + Math.floor(index / 2) * 2.65, w: 5.65, h: 2.25, title: group.label, body: group.items.join("\n\n"), accent: [COLORS.methodology, COLORS.performance, COLORS.security, COLORS.verified][index], titleSize: 21, bodySize: 15.5 }));
  } else if (model.visual.type === "traceabilityFlow") {
    addSimpleFlow(slide, c.flow, COLORS.methodology, 2.0);
    addBullets(slide, c.rules, 2.3, 4.25, 5.1, 1.9, 17, COLORS.text);
    await addImageContain(slide, resolveAsset("Document/outputs/web-app-evidence/06-research-evidence.png"), 8.0, 4.1, 4.2, 2.25);
  } else if (model.visual.type === "references") {
    addBullets(slide, c.references, 0.9, 1.45, 11.45, 5.25, 17, COLORS.text);
  }
}

function renderTitleSlide(slide, content) {
  slide.background = { color: COLORS.dark };
  slide.addShape("rect", { x: 0, y: 0, w: 0.2, h: 7.5, fill: { color: COLORS.performance }, line: { color: COLORS.performance } });
  addText(slide, content.metadata.defenseLabel.toUpperCase(), { x: 0.85, y: 0.7, w: 4.8, h: 0.3, fontSize: 12, bold: true, color: "7FD0D4", charSpacing: 2.2 });
  addText(slide, content.metadata.title, { x: 0.85, y: 1.35, w: 10.95, h: 2.35, fontSize: 34, bold: true, color: COLORS.surface, valign: "top", breakLine: true, fit: "shrink" });
  slide.addShape("line", { x: 0.85, y: 4.15, w: 4.1, h: 0, line: { color: COLORS.performance, width: 4 } });
  addText(slide, `${content.metadata.student} | ${content.metadata.studentId}`, { x: 0.85, y: 4.55, w: 6.8, h: 0.42, fontSize: 22, bold: true, color: COLORS.surface });
  addText(slide, `${content.metadata.degree}\nAdvisor: ${content.metadata.advisor}`, { x: 0.85, y: 5.15, w: 7.2, h: 0.92, fontSize: 17, color: "C9D2D9", breakLine: true, valign: "top" });
  addText(slide, content.metadata.dateLabel, { x: 9.8, y: 6.55, w: 2.55, h: 0.35, fontSize: 14, color: "C9D2D9", align: "right" });
  addRect(slide, 9.25, 4.55, 3.15, 1.35, "22323B", "344750", true);
  addText(slide, "Evidence first", { x: 9.5, y: 4.82, w: 2.65, h: 0.35, fontSize: 21, bold: true, color: "7FD0D4", align: "center" });
  addText(slide, "Model proposes.\nEvidence decides.", { x: 9.5, y: 5.22, w: 2.65, h: 0.48, fontSize: 13, color: COLORS.surface, align: "center", breakLine: true });
}

async function buildDeck(content, outputPath) {
  const pptx = new PptxGenJS();
  pptx.layout = "LAYOUT_WIDE";
  pptx.author = content.metadata.student;
  pptx.company = "Graduate School of Engineering, Science and Technology";
  pptx.subject = content.metadata.defenseLabel;
  pptx.title = content.metadata.title;
  pptx.lang = "en-US";
  pptx.theme = {
    headFontFace: FONTS.face,
    bodyFontFace: FONTS.face,
    lang: "en-US"
  };
  pptx.defineSlideMaster({
    title: "DEFENSE",
    background: { color: COLORS.background },
    objects: [],
    slideNumber: { x: 12, y: 7.1, w: 0.6, h: 0.2, color: COLORS.muted, fontFace: FONTS.face, fontSize: 9 }
  });

  for (let index = 0; index < content.slides.length; index += 1) {
    const model = content.slides[index];
    const slide = pptx.addSlide();
    if (index === 0) renderTitleSlide(slide, content);
    else {
      addFrame(slide, model, index + 1);
      await renderMainVisual(pptx, slide, model);
    }
    slide.addNotes(notesFor(model));
  }

  for (let index = 0; index < content.appendix.length; index += 1) {
    const model = { ...content.appendix[index], section: "Appendix" };
    const slide = pptx.addSlide();
    addFrame(slide, model, content.slides.length + index + 1);
    await renderAppendixVisual(slide, model);
    slide.addNotes(`APPENDIX: Open this slide only when the committee asks for ${model.title.toLowerCase()}.\n\nEVIDENCE: ${model.evidenceRefs.join(" | ")}`);
  }

  fs.mkdirSync(path.dirname(outputPath), { recursive: true });
  await pptx.writeFile({ fileName: outputPath, compression: true });
}

async function main() {
  const content = JSON.parse(fs.readFileSync(CONTENT_PATH, "utf8"));
  await buildDeck(content, OUTPUT_PATH);
  console.log(OUTPUT_PATH);
}

if (require.main === module) {
  main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
}

module.exports = { buildDeck, addFrame, addMetric, addEvidenceTag, addImageContain, addSourceFooter };
