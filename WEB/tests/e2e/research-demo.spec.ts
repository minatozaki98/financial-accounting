import { expect, test } from "@playwright/test";

test("research demo shell exposes login and evidence workflow", async ({ page }) => {
  await page.goto("/");
  await expect(page.getByRole("heading", { name: /Financial Accounting API Demo/i })).toBeVisible();
  await expect(page.getByRole("button", { name: /Use admin/i })).toBeVisible();
  await expect(page.getByLabel(/API base URL/i)).toHaveValue(/localhost:5296/);
});

const runLiveE2e = process.env.RUN_LIVE_E2E === "1";

async function signInWithDemoUser(page: import("@playwright/test").Page, selectorName: RegExp) {
  await page.goto("/");
  await page.getByRole("button", { name: selectorName }).click();
  await page.getByRole("button", { name: "Sign in" }).click();
  await expect(page.getByRole("heading", { name: /Dashboard/i })).toBeVisible();
}

test.describe("live API research workflow", () => {
  test.skip(!runLiveE2e, "Set RUN_LIVE_E2E=1 with the API and seeded database running to execute live workflow tests.");

  test("admin can sign in, run a report, and open audit logs", async ({ page }) => {
    await signInWithDemoUser(page, /Use admin/i);

    await expect(page.getByRole("navigation", { name: "Accounting workspace" })).toBeVisible();
    await expect(page.getByRole("banner", { name: "Current session" })).toContainText("admin");
    await expect(page.getByRole("region", { name: "Live system overview" })).toBeVisible();
    await expect(page.getByRole("link", { name: /Journal Entries/i })).toBeVisible();
    await expect(page.getByRole("link", { name: /Users/i })).toBeVisible();

    await page.getByRole("link", { name: /Accounts/i }).click();
    await expect(page.getByRole("heading", { name: /Accounts/i })).toBeVisible();
    await page.getByRole("button", { name: /View balance/i }).first().click();
    await expect(page.locator(".balance-panel .eyebrow", { hasText: "Ledger balance" })).toBeVisible();
    await expect(page.getByRole("columnheader", { name: /Debit total/i })).toBeVisible();
    await expect(page.getByRole("columnheader", { name: /Credit total/i })).toBeVisible();

    await page.getByRole("link", { name: /Reports/i }).click();
    await expect(page.getByRole("heading", { name: /Reports Workspace/i })).toBeVisible();
    await page.getByRole("button", { name: /Trial balance/i }).click();
    await expect(page.getByText(/Total debit/i)).toBeVisible();
    await expect(page.getByRole("columnheader", { name: /Account code/i })).toBeVisible();
    await expect(page.getByRole("columnheader", { name: /Balance/i })).toBeVisible();
    await expect(page.locator(".json-preview")).toHaveCount(0);
    await page.getByRole("button", { name: /Account ledger/i }).click();
    await expect(page.getByText(/Cannot read properties/i)).toHaveCount(0);
    await expect(page.getByRole("columnheader", { name: /Running balance/i })).toBeVisible();
    await expect(page.getByText(/Lines/i)).toBeVisible();

    await page.getByRole("link", { name: /Journal Entries/i }).click();
    await expect(page.getByRole("heading", { name: /Journal Entries/i })).toBeVisible();
    await expect(page.getByRole("columnheader", { name: /Lines/i })).toBeVisible();
    await expect(page.getByRole("columnheader", { name: /Line debit/i }).first()).toBeVisible();
    await expect(page.getByRole("columnheader", { name: /Line credit/i }).first()).toBeVisible();

    await page.getByRole("link", { name: /Audit Logs/i }).click();
    await expect(page.getByRole("heading", { name: /Audit Logs/i })).toBeVisible();
    await expect(page.getByRole("button", { name: /Refresh/i })).toBeVisible();
  });

  test("auditor sees read-only evidence surfaces without admin/journal screens", async ({ page }) => {
    await signInWithDemoUser(page, /Use auditor/i);

    await expect(page.locator(".role-pill", { hasText: "Auditor" })).toBeVisible();
    await expect(page.getByRole("link", { name: /Reports/i })).toBeVisible();
    await expect(page.getByRole("link", { name: /Audit Logs/i })).toBeVisible();
    await expect(page.getByRole("link", { name: /Journal Entries/i })).toHaveCount(0);
    await expect(page.getByRole("link", { name: /Users/i })).toHaveCount(0);
  });
});
