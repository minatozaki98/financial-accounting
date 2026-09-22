import { expect, test } from "@playwright/test";
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { assertNoForbiddenText, type MetricSpec, validateMetric } from "../../src/lib/dashboard-capture-validation";

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
test.skip(!casesPath, "Set THESIS_DASHBOARD_CASES to run appendix dashboard capture cases.");
const resolvedCasesPath = casesPath ? (path.isAbsolute(casesPath)
  ? casesPath
  : path.resolve(repositoryRoot, casesPath)) : null;
const cases = resolvedCasesPath ? JSON.parse(fs.readFileSync(resolvedCasesPath, "utf8")) as CaptureCase[] : [];
if (casesPath && (!Array.isArray(cases) || cases.length === 0)) {
  throw new Error("Dashboard capture case file must contain at least one case.");
}

const manifestPath = path.join(repositoryRoot, "docs/appendix/dashboard-capture-manifest.json");
const dashboardRoot = path.join(repositoryRoot, "docs/appendix/dashboards");

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
      await Promise.all([
        page.waitForURL((url) => !url.pathname.includes("/sessions/new")),
        page.getByRole("button", { name: /log in/i }).click(),
      ]);
    }

    await page.goto(captureCase.sourceUrl, { waitUntil: "networkidle" });
    await page.locator(captureCase.readySelector ?? "body").waitFor({ state: "visible" });
    const dismissButton = page.getByRole("button", { name: /^dismiss$/i });
    try {
      await dismissButton.waitFor({ state: "visible", timeout: 3_000 });
      await dismissButton.click();
    } catch {
      // Most dashboards do not show an optional promotional panel.
    }
    const promotionalPanel = page.getByText("Get the most out of SonarQube Community Build!", { exact: false }).first();
    if (await promotionalPanel.isVisible().catch(() => false)) {
      await promotionalPanel.evaluate((element) => {
        let current: HTMLElement | null = element as HTMLElement;
        while (current.parentElement && window.getComputedStyle(current).position !== "fixed") {
          current = current.parentElement;
        }
        current.remove();
      });
    }
    const captureLocator = captureCase.captureSelector ? page.locator(captureCase.captureSelector) : page.locator("body");
    const capturedText = await captureLocator.innerText();
    assertNoForbiddenText(capturedText);

    const sourceData = JSON.parse(fs.readFileSync(sourcePath, "utf8")) as unknown;
    const displayedMetrics: Record<string, string | number> = {};
    for (const metric of captureCase.metrics ?? []) {
      displayedMetrics[metric.name] = validateMetric(sourceData, metric, capturedText);
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
      capturedRegion: captureCase.captureSelector === '#statisticsTable' ? 'statistics' : 'dashboard',
      imagePath: captureCase.imagePath,
      width: dimensions.width,
      height: dimensions.height,
      sha256,
      redactionStatus: "pass",
    });
  });
}
