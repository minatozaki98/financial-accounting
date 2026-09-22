import { defineConfig, devices } from "@playwright/test";

export default defineConfig({
  testDir: "./tests/e2e",
  testMatch: "thesis-dashboard-capture.spec.ts",
  timeout: 90_000,
  fullyParallel: false,
  workers: 1,
  outputDir: "../.tmp/playwright-appendix",
  use: {
    ...devices["Desktop Chrome"],
    viewport: { width: 1440, height: 1000 },
    trace: "retain-on-failure",
  },
});
