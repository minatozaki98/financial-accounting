# Quiet Accounting Workspace Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform the React research demo into a calm, ledger-first accounting workspace while preserving all API routes and RBAC behavior.

**Architecture:** Keep the existing React Router pages and `ApiClient` contracts. Extract reusable presentational primitives from `WEB/src/App.tsx`, then use them to standardize headers, toolbars, status feedback, metrics, tables, and progressive disclosure for account balances and journal lines. Use CSS custom properties in the existing stylesheet as the single visual-token source.

**Tech Stack:** React 19, TypeScript, React Router 7, Lucide React, Vite, Vitest, Playwright, plain CSS.

## Global Constraints

- Preserve existing API routes, request payloads, `ApiClient` methods, demo users, and RBAC rules.
- Use the existing Lucide dependency for icons; do not add a UI framework.
- Use the current system/Inter sans-serif stack and a fixed product type scale.
- Keep 6-8px component radii; avoid nested cards, decorative gradients, and raw JSON report output.
- Maintain WCAG 2.1 AA contrast, visible keyboard focus, semantic table markup, and `prefers-reduced-motion` support.
- Use `http://localhost:5174` only for temporary local verification while port 5173 is occupied; inject that origin into the API process environment rather than changing backend configuration.

---

## File Structure

- Create: `WEB/src/components/workspace.tsx` - shared `PageHeader`, `Metric`, `StatusMessages`, `DataTable`, `EmptyState`, and button-class helpers.
- Create: `WEB/src/components/workspace.test.tsx` - focused rendering tests for shared workspace primitives.
- Create: `WEB/src/components/journal-entry-table.tsx` - compact journal table with row-level line disclosure.
- Create: `WEB/src/components/journal-entry-table.test.tsx` - behavior test for journal-line disclosure.
- Modify: `WEB/src/App.tsx` - import shared primitives, use the revised application shell, and compose each page from toolbar/table/detail regions.
- Modify: `WEB/src/styles.css` - replace ad hoc colors and card treatments with workspace tokens, responsive layout, focus, status, table, skeleton, and motion rules.
- Modify: `WEB/tests/e2e/research-demo.spec.ts` - prove the changed visible workflow, including account balance and collapsed journal-line detail.
- Modify: `WEB/vite.config.ts` only if a deterministic test port override is required by Vite configuration; do not change the committed default port merely because another project is currently running.

## Task 1: Establish the Workspace Shell and Shared Primitives

**Files:**
- Create: `WEB/src/components/workspace.tsx`
- Create: `WEB/src/components/workspace.test.tsx`
- Modify: `WEB/src/App.tsx`
- Modify: `WEB/src/styles.css`

**Interfaces:**
- Consumes: `ApiError` from `WEB/src/lib/api.ts` and the existing `useAsyncAction` result in `WEB/src/App.tsx`.
- Produces: `PageHeader`, `Metric`, `StatusMessages`, `DataTable`, and `EmptyState` for all route pages.

- [ ] **Step 1: Write the failing component tests**

Create `WEB/src/components/workspace.test.tsx` with tests that establish the accessible contracts:

```tsx
import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { DataTable, EmptyState, PageHeader, StatusMessages } from "./workspace";

describe("workspace primitives", () => {
  it("renders a page title, context, and primary action", () => {
    render(<PageHeader title="Accounts" context="256 active accounts" action={<button>Create account</button>} />);
    expect(screen.getByRole("heading", { name: "Accounts" })).toBeVisible();
    expect(screen.getByText("256 active accounts")).toBeVisible();
    expect(screen.getByRole("button", { name: "Create account" })).toBeVisible();
  });

  it("renders a labelled table and an actionable empty state", () => {
    render(
      <>
        <DataTable caption="Accounts" headers={["Code", "Balance"]} rows={[]} numericColumns={[1]} />
        <EmptyState title="No accounts found" detail="Clear the search or create a new account." />
      </>,
    );
    expect(screen.getByRole("table", { name: "Accounts" })).toBeVisible();
    expect(screen.getByText("No accounts found")).toBeVisible();
  });

  it("announces success and error feedback", () => {
    render(<StatusMessages error="403: Forbidden" message="Account created." />);
    expect(screen.getByRole("alert")).toHaveTextContent("403: Forbidden");
    expect(screen.getByRole("status")).toHaveTextContent("Account created.");
  });
});
```

- [ ] **Step 2: Run the focused test to verify it fails**

Run: `npm test -- workspace.test.tsx`

Expected: FAIL because `WEB/src/components/workspace.tsx` does not exist.

- [ ] **Step 3: Implement shared workspace primitives**

Create `WEB/src/components/workspace.tsx` with the following public contracts. Keep the row cell type aligned with the existing `DataTable` call sites.

```tsx
import type { ReactNode } from "react";
import { AlertTriangle, CheckCircle2 } from "lucide-react";

export function PageHeader({ title, context, action }: { title: string; context?: string; action?: ReactNode }) {
  return <header className="page-header"><div><h2>{title}</h2>{context ? <p>{context}</p> : null}</div>{action ? <div className="page-header-actions">{action}</div> : null}</header>;
}

export function Metric({ label, value, tone = "default" }: { label: string; value: string; tone?: "default" | "positive" | "warning" }) {
  return <article className={`metric metric-${tone}`}><span>{label}</span><strong>{value}</strong></article>;
}

export function StatusMessages({ error, message }: { error?: string | null; message?: string | null }) {
  return <div className="status-stack" aria-live="polite">
    {error ? <div className="notice notice-error" role="alert"><AlertTriangle size={16} />{error}</div> : null}
    {message ? <div className="notice notice-success" role="status"><CheckCircle2 size={16} />{message}</div> : null}
  </div>;
}

export function EmptyState({ title, detail }: { title: string; detail: string }) {
  return <div className="empty-state"><strong>{title}</strong><p>{detail}</p></div>;
}

export function DataTable({ caption, headers, rows, numericColumns = [] }: { caption: string; headers: string[]; rows: Array<Array<ReactNode>>; numericColumns?: number[] }) {
  return <div className="table-wrap"><table aria-label={caption}><thead><tr>{headers.map((header, index) => <th className={numericColumns.includes(index) ? "numeric" : undefined} key={header}>{header}</th>)}</tr></thead><tbody>{rows.length === 0 ? <tr><td colSpan={headers.length}><EmptyState title="No rows found" detail="Adjust the current filter or load data again." /></td></tr> : rows.map((row, rowIndex) => <tr key={rowIndex}>{row.map((cell, cellIndex) => <td className={numericColumns.includes(cellIndex) ? "numeric" : undefined} key={cellIndex}>{cell}</td>)}</tr>)}</tbody></table></div>;
}
```

In `WEB/src/App.tsx`, import these primitives, remove duplicate local definitions, and replace every `DataTable` call with a descriptive `caption` and the appropriate numeric column indices. Preserve the existing `useAsyncAction` hook and `formatMoney`/`formatDate` helpers.

In `WEB/src/styles.css`, define the workspace token layer and component rules:

```css
:root {
  --canvas: #edf2f6;
  --surface: #ffffff;
  --surface-subtle: #f6f8fa;
  --ink: #172433;
  --ink-muted: #526577;
  --border: #cbd6df;
  --nav: #13283d;
  --nav-active: #214d78;
  --action: #1f5f94;
  --action-hover: #16486f;
  --focus: #0b76d1;
  --success: #176a48;
  --warning: #9b5b00;
  --danger: #a22d21;
}

button:focus-visible, input:focus-visible, select:focus-visible, a:focus-visible {
  outline: 3px solid color-mix(in srgb, var(--focus) 45%, white);
  outline-offset: 2px;
}

.page-header { display: flex; justify-content: space-between; align-items: end; gap: 1rem; margin-bottom: 1.25rem; }
.page-header h2 { margin: 0; font-size: 1.5rem; }
.page-header p { margin: .3rem 0 0; color: var(--ink-muted); }
.numeric { text-align: right; font-variant-numeric: tabular-nums; }
```

Use the tokens for the existing shell, forms, role pills, notices, tables, and metric surfaces. Add a `@media (prefers-reduced-motion: reduce)` block that removes transition duration.

- [ ] **Step 4: Run focused tests to verify they pass**

Run: `npm test -- workspace.test.tsx`

Expected: PASS with three workspace primitive tests.

- [ ] **Step 5: Commit the shared workspace foundation**

```powershell
git add WEB/src/App.tsx WEB/src/styles.css WEB/src/components/workspace.tsx WEB/src/components/workspace.test.tsx
git commit -m "feat: add accounting workspace primitives"
```

## Task 2: Make the Application Shell and Route Toolbars Operationally Dense

**Files:**
- Modify: `WEB/src/App.tsx`
- Modify: `WEB/src/styles.css`
- Modify: `WEB/tests/e2e/research-demo.spec.ts`

**Interfaces:**
- Consumes: `PageHeader`, `Metric`, `StatusMessages`, and `DataTable` from `WEB/src/components/workspace.tsx`.
- Produces: a compact desktop shell, responsive navigation, and consistent route headers/toolbars.

- [ ] **Step 1: Start a local live-test runtime without disturbing port 5173**

Run from the repository root in one terminal:

```powershell
$env:AppSettings__AllowedOrigins__2 = "http://localhost:5174"
$env:AppSettings__EnableSwaggerUi = "true"
dotnet run --project API/API.csproj --urls http://0.0.0.0:5296 --environment Development
```

Run from `WEB/` in a second terminal:

```powershell
npm run dev -- --port 5174
```

Expected: `/health/live` returns HTTP 200 and the financial-accounting frontend loads at `http://localhost:5174`.

- [ ] **Step 2: Write failing workflow assertions**

Add the navigation assertion to the live admin workflow immediately after `signInWithDemoUser`:

```tsx
await expect(page.getByRole("navigation", { name: "Accounting workspace" })).toBeVisible();
await expect(page.getByRole("link", { name: /Dashboard/i })).toBeVisible();
```

After admin sign-in, assert the top bar identifies the signed-in user and the dashboard contains a labelled live-system region:

```tsx
await expect(page.getByRole("banner")).toContainText("admin");
await expect(page.getByRole("region", { name: "Live system overview" })).toBeVisible();
```

- [ ] **Step 3: Run the live e2e workflow to verify it fails**

Run: `$env:WEB_BASE_URL="http://127.0.0.1:5174"; $env:RUN_LIVE_E2E="1"; npm run test:e2e -- --grep "admin can sign in"`

Expected: FAIL because the shell does not yet expose the named navigation, banner, and overview-region landmarks.

- [ ] **Step 4: Implement the semantic shell and toolbar pattern**

Update `Layout` in `WEB/src/App.tsx` to use semantic labels and a compact navigation control:

```tsx
<aside className="sidebar">
  <div className="sidebar-title">...</div>
  <nav aria-label="Accounting workspace">...</nav>
</aside>
<div className="content-shell">
  <header className="topbar" aria-label="Current session">...</header>
  <main className="workspace-main"><Routes>...</Routes></main>
</div>
```

Use `PageHeader` for Dashboard, Accounts, Journal Entries, Periods, Reports, Audit Logs, Users, and Research Evidence. Use a `toolbar` class for search/filter/input/action groups. On Dashboard, wrap the metric grid in `<section aria-label="Live system overview">`.

In `WEB/src/styles.css`, keep the rail fixed on desktop, allow toolbar contents to wrap, and at `max-width: 980px` convert the navigation into a horizontally scrollable row with a visible focus indicator. Do not hide routes that the current role is allowed to access.

- [ ] **Step 5: Run the live e2e workflow to verify it passes**

Run: `$env:WEB_BASE_URL="http://127.0.0.1:5174"; $env:RUN_LIVE_E2E="1"; npm run test:e2e -- --grep "admin can sign in"`

Expected: PASS.

- [ ] **Step 6: Commit the shell and toolbar update**

```powershell
git add WEB/src/App.tsx WEB/src/styles.css WEB/tests/e2e/research-demo.spec.ts
git commit -m "feat: refine accounting workspace shell"
```

## Task 3: Add Progressive Disclosure for Account Balances and Journal Lines

**Files:**
- Create: `WEB/src/components/journal-entry-table.tsx`
- Create: `WEB/src/components/journal-entry-table.test.tsx`
- Modify: `WEB/src/App.tsx`
- Modify: `WEB/src/styles.css`
- Modify: `WEB/tests/e2e/research-demo.spec.ts`

**Interfaces:**
- Consumes: `JournalEntry`, `Account`, `formatMoney`, `formatDate`, current role actions, and `DataTable` visual conventions.
- Produces: `JournalEntryTable` with `onPost`, `onReverse`, `onDelete`, and accessible `Show lines`/`Hide lines` controls.

- [ ] **Step 1: Write the failing disclosure test**

Create `WEB/src/components/journal-entry-table.test.tsx`:

```tsx
import { fireEvent, render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { JournalEntryTable } from "./journal-entry-table";

const entry = { journalEntryId: 10, entryDate: "2026-01-01", referenceNo: "JE-10", status: "Draft", debitTotal: 25, creditTotal: 25, lines: [{ accountId: 1, accountCode: "1000", accountName: "Cash", debit: 25, credit: 0, lineDescription: "Debit" }] };

describe("JournalEntryTable", () => {
  it("keeps lines collapsed until the user requests them", async () => {
    render(<JournalEntryTable entries={[entry]} canMutate={false} formatMoney={(value) => `$${value}`} formatDate={(value) => value} />);
    expect(screen.queryByText("Line debit")).not.toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: "Show lines for JE-10" }));
    expect(screen.getByText("Line debit")).toBeVisible();
    expect(screen.getByRole("button", { name: "Hide lines for JE-10" })).toHaveAttribute("aria-expanded", "true");
  });
});
```

- [ ] **Step 2: Run the focused test to verify it fails**

Run: `npm test -- journal-entry-table.test.tsx`

Expected: FAIL because `JournalEntryTable` has not been created.

- [ ] **Step 3: Implement the account and journal detail interactions**

Create `WEB/src/components/journal-entry-table.tsx`. It must maintain `expandedEntryId` with `useState<number | null>(null)`, render one compact parent row per entry, and render a second `<tr className="journal-detail-row">` only for the expanded ID. The disclosure control must use this contract:

```tsx
<button
  type="button"
  className="table-link-button"
  aria-expanded={expandedEntryId === entry.journalEntryId}
  aria-controls={`journal-lines-${entry.journalEntryId}`}
  onClick={() => setExpandedEntryId((current) => current === entry.journalEntryId ? null : entry.journalEntryId)}
>
  {expandedEntryId === entry.journalEntryId ? `Hide lines for ${entry.referenceNo ?? entry.journalEntryId}` : `Show lines for ${entry.referenceNo ?? entry.journalEntryId}`}
</button>
```

The detail row must have `id={`journal-lines-${entry.journalEntryId}`}` and show Account, Description, Line debit, and Line credit columns. Pass existing mutation callbacks from `JournalEntriesPage`; preserve the existing role rules for post/reverse/delete.

Replace `JournalEntriesPage`'s current nested `JournalEntryLines` cell with `JournalEntryTable`.

For Accounts, retain `selectedBalance` but make the action button `aria-expanded={selectedBalance?.accountId === a.accountId}` and label it `View balance for ${a.accountCode}`. Give the balance region `aria-label="Ledger balance details"`, place it immediately before the accounts table, and use right-aligned metric/table values.

Add styles for `.table-link-button`, `.journal-detail-row`, `.journal-detail`, and `.balance-panel` that preserve a compact parent row and use a subtle surface tint for the detail region. Do not render a table inside another table cell.

- [ ] **Step 4: Extend and run interaction checks**

Replace the journal line e2e assertions with:

```tsx
await expect(page.getByText("Line debit")).toHaveCount(0);
const disclosure = page.getByRole("button", { name: /Show lines for/i }).first();
await disclosure.click();
await expect(page.getByRole("columnheader", { name: "Line debit" })).toBeVisible();
await expect(disclosure).toHaveAttribute("aria-expanded", "true");
```

Update the account assertion to target `View balance for 1000` rather than the generic label. Then run:

Run: `npm test -- journal-entry-table.test.tsx`

Expected: PASS.

Run: `npm run test:e2e -- --grep "admin can sign in"`

Expected: PASS when the live test switch is not set (the test remains skipped); use Task 5 for the live assertion.

- [ ] **Step 5: Commit progressive details**

```powershell
git add WEB/src/App.tsx WEB/src/styles.css WEB/src/components/journal-entry-table.tsx WEB/src/components/journal-entry-table.test.tsx WEB/tests/e2e/research-demo.spec.ts
git commit -m "feat: add progressive accounting detail views"
```

## Task 4: Standardize Reports, Administrative Pages, and State Feedback

**Files:**
- Modify: `WEB/src/App.tsx`
- Modify: `WEB/src/styles.css`
- Modify: `WEB/tests/e2e/research-demo.spec.ts`

**Interfaces:**
- Consumes: `PageHeader`, `Metric`, `StatusMessages`, `DataTable`, `EmptyState`, existing report-client methods, and current RBAC helpers.
- Produces: a common report toolbar, right-aligned financial columns, explicit restricted messaging, and polished empty/loading/error states across remaining pages.

- [ ] **Step 1: Write failing e2e expectations for the revised reports surface**

In the live admin workflow, add:

```tsx
await expect(page.getByRole("group", { name: "Report parameters" })).toBeVisible();
await expect(page.getByRole("table", { name: "Trial balance report" })).toBeVisible();
await expect(page.getByText("No rows found")).toHaveCount(0);
```

In the auditor workflow, add:

```tsx
await expect(page.getByText("Read-only access")).toBeVisible();
```

- [ ] **Step 2: Run the e2e test file to verify the new assertions fail**

Run: `$env:RUN_LIVE_E2E="1"; npm run test:e2e`

Expected: FAIL at the missing report parameter group/table label and auditor read-only message. Do not proceed if the API is unavailable; resolve runtime setup in Task 5 first.

- [ ] **Step 3: Implement report and state refinements**

In `ReportsPage`, wrap period/account inputs in `<div className="toolbar" role="group" aria-label="Report parameters">`. Add a `reportTitle` state set by `runReport` (`"Trial balance report"`, `"Profit and loss report"`, `"Balance sheet report"`, or `"Account ledger report"`) and pass it as the `DataTable` caption. Pass numeric columns `[3, 4, 5]` for account reports and `[3, 4, 5]` for ledger reports.

Use `PageHeader` in Periods, Reports, Audit Logs, Users, and Research Evidence. Give all inputs visible labels rather than relying only on placeholders. Where a role cannot mutate data, replace generic muted copy with `<p className="read-only-note"><LockKeyhole size={16} />Read-only access: ...</p>` using the existing Lucide package.

In `WEB/src/styles.css`, add `.toolbar`, `.read-only-note`, `.status-stack`, `.empty-state`, `.table-wrap thead th { position: sticky; top: 0; }`, and loading skeleton classes. Use skeleton rows only while an existing page is fetching; do not remove the previous successful table content while a refresh is in flight.

- [ ] **Step 4: Run tests and production build**

Run: `npm test`

Expected: PASS for API, permission, workspace, and journal-detail tests.

Run: `npm run build`

Expected: TypeScript build and Vite production build complete with exit code 0.

- [ ] **Step 5: Commit report and feedback refinements**

```powershell
git add WEB/src/App.tsx WEB/src/styles.css WEB/tests/e2e/research-demo.spec.ts
git commit -m "feat: refine reports and workspace feedback"
```

## Task 5: Verify the Live UI and Refresh Evidence Screenshots

**Files:**
- Modify: `WEB/tests/e2e/research-demo.spec.ts` only if a discovered selector needs a stable accessible label.
- Replace: `Document/outputs/web-app-evidence/01-login.png`
- Replace: `Document/outputs/web-app-evidence/02-dashboard-admin.png`
- Replace: `Document/outputs/web-app-evidence/03-reports-trial-balance.png`
- Replace: `Document/outputs/web-app-evidence/04-audit-logs.png`
- Replace: `Document/outputs/web-app-evidence/05-auditor-role-view.png`
- Replace: `Document/outputs/web-app-evidence/06-research-evidence.png`

**Interfaces:**
- Consumes: the completed frontend build, seeded API, and demo users.
- Produces: visible proof that the redesign works across the main research-demo flows.

- [ ] **Step 1: Run the full live workflow tests against the existing Task 2 runtime**

Run from `WEB/`:

```powershell
$env:WEB_BASE_URL = "http://127.0.0.1:5174"
$env:RUN_LIVE_E2E = "1"
npm run test:e2e
```

Expected: all three tests pass, covering login, admin reports/account/journal/audit workflow, and auditor restrictions.

- [ ] **Step 2: Perform visual checks at desktop and narrow widths**

Inspect the rendered pages at 1440px and 390px widths:

```text
Login: API URL and demo credential controls fit without clipping.
Dashboard: metric values, role badges, and evidence table are readable.
Accounts: balance detail is labelled and does not shift or obscure the list.
Journal Entries: detail is initially collapsed and opens with debit/credit lines.
Reports: report parameters, totals, and financial table are visible; raw JSON is absent.
Auditor: restricted navigation is absent and read-only context is visible.
```

- [ ] **Step 3: Capture and verify the evidence bundle**

Replace the six screenshot files listed above only after the corresponding screen passes visual inspection. Open the saved PNG files after capture and verify they show the financial-accounting application, current quiet-workspace styling, and readable content; do not capture the unrelated project currently occupying port 5173.

- [ ] **Step 4: Commit verification artifacts if screenshots changed**

```powershell
git add WEB/tests/e2e/research-demo.spec.ts Document/outputs/web-app-evidence
git commit -m "docs: refresh accounting workspace evidence"
```

## Plan Self-Review

- Spec coverage: Task 1 establishes the visual system, shared states, focus, reduced motion, and semantic tables. Task 2 implements the layout and responsive navigation. Task 3 covers account balances and journal-line progressive disclosure. Task 4 covers reports, administrative surfaces, explicit restrictions, and state feedback. Task 5 covers desktop/mobile UAT and evidence capture.
- Placeholder scan: no unfinished markers or undefined deferred behavior; each implementation task names files, interfaces, tests, commands, and expected outcomes.
- Type consistency: shared primitives use `ReactNode` table cells compatible with existing call sites. `JournalEntryTable` consumes existing `JournalEntry` values and returns actions through callbacks owned by `JournalEntriesPage`. Report captions are strings passed into the shared `DataTable` contract.
