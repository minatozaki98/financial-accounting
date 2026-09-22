import { expect, test } from "@playwright/test";
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

type MetricSpec = {
  name: string;
  expectedValue: string | number;
  sourcePath?: string;
  sourceKind?: "path" | "zap-risk-count";
  riskCode?: number;
  pagePattern?: string;
};

type CaptureCase = {
  name: string;
  tool: "sonarqube" | "zap" | "jmeter";
  view: string;
  sourceUrl: string;
  sourceUrlLabel?: string;
  readySelector?: string;
  captureSelector?: string;
  fullPage?: boolean;
  imagePath: string;
  evidenceClassification: "historical" | "rendered-historical" | "fresh-reproduction";
  evidenceRole: "baseline" | "remediation";
  branch: string;
  commit: string;
  runId: string;
  toolVersion: string;
  sourceArtifact: string;
  metrics?: MetricSpec[];
  loginUrl?: string;
};

const currentDirectory = path.dirname(fileURLToPath(import.meta.url));
const repositoryRoot = path.resolve(currentDirectory, "../../..");
const casesPath = process.env.THESIS_DASHBOARD_CASES;
if (!casesPath) {
  throw new Error("THESIS_DASHBOARD_CASES must point to a dashboard capture case file.");
}
const resolvedCasesPath = path.isAbsolute(casesPath)
  ? casesPath
  : path.resolve(repositoryRoot, casesPath);
const cases = JSON.parse(fs.readFileSync(resolvedCasesPath, "utf8")) as CaptureCase[];
if (!Array.isArray(cases) || cases.length === 0) {
  throw new Error("Dashboard capture case file must contain at least one case.");
}

const manifestPath = path.join(repositoryRoot, "docs/appendix/dashboard-capture-manifest.json");
const dashboardRoot = path.join(repositoryRoot, "docs/appendix/dashboards");
const forbidden = [
  /Password\s*=/i,
  /sonar\.token\s*=/i,
  /Authorization:\s*Bearer/i,
  /[A-Za-z]:[\\/]Users[\\/](?!\[USER\])[^\\/]+/i,
];

function getByPath(value: unknown, dottedPath: string): unknown {
  return dottedPath.split(".").reduce<unknown>((current, segment) => {
    if (current === null || typeof current !== "object") return undefined;
    return (current as Record<string, unknown>)[segment];
  }, value);
}

function getZapRiskCount(value: unknown, riskCode: number): number {
  const root = value as { site?: Array<{ alerts?: Array<{ riskcode?: string | number }> }> | { alerts?: Array<{ riskcode?: string | number }> } };
  const sites = Array.isArray(root.site) ? root.site : root.site ? [root.site] : [];
  return sites.flatMap((site) => site.alerts ?? []).filter((alert) => Number(alert.riskcode) === riskCode).length;
}

function readPngDimensions(buffer: Buffer): { width: number; height: number } {
  if (buffer.length < 24 || buffer.toString("ascii", 1, 4) !== "PNG") {
    throw new Error("Screenshot is not a valid PNG.");
  }
  return { width: buffer.readUInt32BE(16), height: buffer.readUInt32BE(20) };
}

function updateManifest(entry: Record<string, unknown>): void {
  const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8")) as {
    schemaVersion: number;
    requiredCaptures: string[];
    captures: Array<Record<string, unknown>>;
  };
  manifest.captures = manifest.captures.filter((capture) => capture.imagePath !== entry.imagePath);
  manifest.captures.push(entry);
  manifest.captures.sort((left, right) => String(left.imagePath).localeCompare(String(right.imagePath)));
  fs.writeFileSync(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`, "utf8");
}

for (const captureCase of cases) {
  test(captureCase.name, async ({ page }) => {
    expect(captureCase.commit).toMatch(/^[0-9a-f]{40}$/);
    const sourcePath = path.resolve(repositoryRoot, captureCase.sourceArtifact);
    expect(fs.existsSync(sourcePath), `Missing source artifact ${captureCase.sourceArtifact}`).toBe(true);

    if (captureCase.loginUrl) {
      const username = process.env.SONAR_USERNAME;
      const password = process.env.SONAR_PASSWORD;
      if (!username || !password) throw new Error("SONAR_USERNAME and SONAR_PASSWORD are required for authenticated capture.");
      await page.goto(captureCase.loginUrl);
      await page.locator('input[name="login"]').fill(username);
      await page.locator('input[name="password"]').fill(password);
      await page.getByRole("button", { name: /log in/i }).click();
    }

    await page.goto(captureCase.sourceUrl, { waitUntil: "networkidle" });
    await page.locator(captureCase.readySelector ?? "body").waitFor({ state: "visible" });
    const bodyText = await page.locator("body").innerText();
    for (const pattern of forbidden) expect(bodyText).not.toMatch(pattern);

    const sourceData = JSON.parse(fs.readFileSync(sourcePath, "utf8")) as unknown;
    const displayedMetrics: Record<string, string | number> = {};
    for (const metric of captureCase.metrics ?? []) {
      const sourceValue = metric.sourceKind === "zap-risk-count"
        ? getZapRiskCount(sourceData, metric.riskCode ?? -1)
        : getByPath(sourceData, metric.sourcePath ?? "");
      expect(String(sourceValue), `${captureCase.name}: ${metric.name} source mismatch`).toBe(String(metric.expectedValue));
      if (metric.pagePattern) expect(bodyText).toMatch(new RegExp(metric.pagePattern, "i"));
      displayedMetrics[metric.name] = metric.expectedValue;
    }

    const outputPath = path.join(dashboardRoot, captureCase.imagePath);
    fs.mkdirSync(path.dirname(outputPath), { recursive: true });
    const buffer = captureCase.captureSelector
      ? await page.locator(captureCase.captureSelector).screenshot({ path: outputPath })
      : await page.screenshot({ path: outputPath, fullPage: captureCase.fullPage ?? false });
    const dimensions = readPngDimensions(buffer);
    const sha256 = crypto.createHash("sha256").update(buffer).digest("hex");

    updateManifest({
      tool: captureCase.tool,
      view: captureCase.view,
      evidenceClassification: captureCase.evidenceClassification,
      evidenceRole: captureCase.evidenceRole,
      branch: captureCase.branch,
      commit: captureCase.commit,
      runId: captureCase.runId,
      capturedAtUtc: new Date().toISOString(),
      toolVersion: captureCase.toolVersion,
      sourceUrl: captureCase.sourceUrlLabel ?? captureCase.sourceArtifact,
      sourceArtifact: captureCase.sourceArtifact,
      displayedMetrics,
      imagePath: captureCase.imagePath,
      width: dimensions.width,
      height: dimensions.height,
      sha256,
      redactionStatus: "pass",
    });
  });
}
