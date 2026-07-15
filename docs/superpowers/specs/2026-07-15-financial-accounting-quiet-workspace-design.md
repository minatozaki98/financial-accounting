# Financial Accounting Quiet Workspace Design

## Purpose

Redesign the existing React/Vite research web app as a quiet accounting workspace. The frontend remains a live demonstration of the ASP.NET Core API and its RBAC behavior; this work changes presentation, interaction clarity, and responsive behavior without changing API routes or permission rules.

## Scope

- Refresh the authenticated app shell, login screen, shared controls, data tables, forms, notices, and empty/loading states.
- Improve the Accounts, Journal Entries, Periods, Reports, Audit Logs, Users, and Research Evidence pages.
- Preserve the existing routes, API client contracts, demo credentials, and role-aware navigation.
- Keep the visual language appropriate for a research/demo artifact rather than a production accounting suite.

## Layout Direction

Use a ledger-first product layout:

- Persistent left navigation on desktop, with the active route clearly marked.
- Compact top bar showing the connected API endpoint, current user, roles, and logout action.
- Each page starts with a concise page header containing the title, operational context, and primary action.
- Filters and create actions sit in a compact toolbar above one main data surface.
- Tables are the dominant visual element. Use sticky headers, right-aligned monetary values, clear numeric weight, and horizontal scrolling when required.
- Avoid nested cards. Use a single framed page surface when grouping is needed and unframed content bands for the surrounding layout.

## Visual System

- Palette: cool neutral application canvas, deep ink navigation, white data surfaces, restrained blue as the action/selection color, and semantic green/amber/red for states.
- Typography: retain a single practical sans-serif family. Use a compact, fixed product type scale with regular case for page labels and no tracked all-caps decoration.
- Shape and elevation: 6-8px control and surface radii. Use either a light border or a subtle short shadow per surface, not both as decoration.
- Motion: 150-200ms transitions only for interaction feedback and panel expansion. Respect `prefers-reduced-motion`.

## Page Behavior

### Login

Keep the live API endpoint and demo credentials accessible, but make the sign-in task primary. Credential selectors should be compact role cards with clear role descriptions. Show validation and connection failures beside the relevant action.

### Dashboard

Show a short operational snapshot: current user, accessible accounts, periods, and permitted report total. The research evidence summary remains available but is visually secondary to the live system state.

### Accounts

Place search and create actions in the page toolbar. The accounts table exposes a balance action. Selecting it opens a dedicated inline detail region or side detail panel that presents debit total, credit total, and balance without disrupting the list.

### Journal Entries

Keep journal rows concise: date, reference, status, debit, credit, and available actions. Replace the permanently rendered nested line table with progressive disclosure. An explicit row-level control reveals a structured detail region for journal lines, including account, description, debit, and credit.

### Periods

Use a compact period table with clearly visible closed/open status. Creation and close actions stay adjacent to the list and use success/error feedback that does not shift the table layout.

### Reports

Use a report toolbar with period and account parameters, followed by report-type controls. On load, render the report identity and totals before the table. Trial balance, profit/loss, and balance-sheet results share a consistent financial table. Account ledger results display opening/closing balances and a running-balance table. Do not show raw JSON.

### Audit Logs and Research Evidence

Keep filtering visible and tables dense but legible. Research Evidence should communicate API coverage and role validation as supporting proof, not as a marketing dashboard.

## Feedback States

- Loading: skeleton rows and summary placeholders instead of bare spinners.
- Empty: explain whether a filter returned no results or the API returned no records, with a clear next action where one exists.
- Success: compact in-context notice near the action that triggered it.
- Error: readable error message near the affected data surface, retaining the previous visible state where possible.
- Restricted: use an explicit lock/status treatment and short explanation; do not simply remove context that would help explain RBAC.

## Responsive Rules

- Desktop: fixed navigation rail and full table workspace.
- Tablet: narrower navigation rail and responsive toolbar wrapping.
- Mobile: replace the rail with a compact navigation control; retain table horizontal scrolling, preserve row actions, and stack summary values without altering their order.
- Do not scale type with viewport width. Prevent controls, headings, and monetary values from overflowing their containers.

## Acceptance Criteria

1. All existing pages remain reachable according to the current RBAC rules.
2. Tables show financial values in a scan-friendly layout and no report page renders raw JSON.
3. Journal line debit/credit details are available through a deliberate progressive-disclosure control.
4. Account balance information remains available from the accounts list.
5. Login, dashboard, reports, journal entries, audit logs, and restricted role views have coherent loading, empty, error, and responsive states.
6. Keyboard focus and semantic labels remain visible and usable.
7. The frontend builds successfully and the existing unit/e2e coverage is updated for the changed interactions.

## Verification

- Run frontend unit tests and production build.
- Run the live Playwright workflow against a seeded API instance.
- Visually inspect the login page, admin dashboard, journal entry detail expansion, account balance detail, reports, audit logs, and auditor restricted view at desktop and narrow mobile widths.
- Capture refreshed evidence screenshots only after the visible product output matches this specification.
