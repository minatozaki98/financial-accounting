import { FormEvent, useEffect, useMemo, useState } from "react";
import { NavLink, Navigate, Route, Routes, useLocation, useNavigate } from "react-router-dom";
import {
  CheckCircle2,
  Database,
  LockKeyhole,
  LogOut,
  RefreshCw,
  Shield,
  Sparkles,
} from "lucide-react";
import { ApiError, type Account, type AccountingPeriod, type AuditLog, type JournalEntry } from "./lib/api";
import { canAccessRoute, canMutate, getAllowedNavigation } from "./lib/permissions";
import { useAuth } from "./state/AuthContext";
import { DataTable, Metric, PageHeader, StatusMessages } from "./components/workspace";
import { JournalEntryTable } from "./components/journal-entry-table";

const demoUsers = [
  { label: "Use admin", username: "admin", password: "Admin@123", role: "Admin + FinanceManager" },
  { label: "Use finance manager", username: "finance-manager", password: "Admin@123", role: "FinanceManager" },
  { label: "Use normal user", username: "normal-user", password: "Admin@123", role: "User" },
  { label: "Use auditor", username: "auditor-user", password: "Admin@123", role: "Auditor" },
];

function formatMoney(value?: number) {
  return new Intl.NumberFormat("en-US", { style: "currency", currency: "USD" }).format(value ?? 0);
}

function formatDate(value?: string) {
  if (!value) return "-";
  return new Intl.DateTimeFormat("en-US", { dateStyle: "medium" }).format(new Date(value));
}

function useAsyncAction() {
  const [error, setError] = useState<string | null>(null);
  const [message, setMessage] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function run<T>(action: () => Promise<T>, success?: string): Promise<T | null> {
    setLoading(true);
    setError(null);
    setMessage(null);
    try {
      const result = await action();
      if (success) setMessage(success);
      return result;
    } catch (err) {
      setError(err instanceof ApiError ? `${err.status}: ${err.message}` : err instanceof Error ? err.message : "Unknown error");
      return null;
    } finally {
      setLoading(false);
    }
  }

  return { error, message, loading, run, setError, setMessage };
}

function LoginPage() {
  const { apiBaseUrl, setApiBaseUrl, login } = useAuth();
  const navigate = useNavigate();
  const action = useAsyncAction();
  const [username, setUsername] = useState("admin");
  const [password, setPassword] = useState("Admin@123");
  const [baseUrlDraft, setBaseUrlDraft] = useState(apiBaseUrl);

  async function submit(event: FormEvent) {
    event.preventDefault();
    setApiBaseUrl(baseUrlDraft);
    const result = await action.run(() => login(username, password), "Signed in.");
    if (result !== null) navigate("/dashboard");
  }

  return (
    <main className="login-shell">
      <section className="login-panel">
        <div className="brand-row">
          <div className="brand-mark"><Database size={28} /></div>
          <div>
            <h1>Financial Accounting API Demo</h1>
            <p>Live research web app for the ASP.NET Core financial accounting APIs.</p>
          </div>
        </div>

        <form onSubmit={submit} className="form-grid">
          <label>
            API base URL
            <input aria-label="API base URL" value={baseUrlDraft} onChange={(event) => setBaseUrlDraft(event.target.value)} />
          </label>
          <label>
            Username
            <input value={username} onChange={(event) => setUsername(event.target.value)} />
          </label>
          <label>
            Password
            <input type="password" value={password} onChange={(event) => setPassword(event.target.value)} />
          </label>
          <button disabled={action.loading}>{action.loading ? "Signing in..." : "Sign in"}</button>
        </form>
        <StatusMessages error={action.error} message={action.message} />
      </section>

      <section className="demo-users">
        <h2>Demo credentials</h2>
        <div className="demo-grid">
          {demoUsers.map((user) => (
            <button
              key={user.username}
              type="button"
              onClick={() => {
                setUsername(user.username);
                setPassword(user.password);
              }}
            >
              <strong>{user.label}</strong>
              <span>{user.username} / {user.password}</span>
              <small>{user.role}</small>
            </button>
          ))}
        </div>
      </section>
    </main>
  );
}

function ProtectedRoute({ children, path }: { children: React.ReactNode; path: string }) {
  const auth = useAuth();
  const location = useLocation();
  if (!auth.isAuthenticated) return <Navigate to="/" replace state={{ from: location }} />;
  if (!canAccessRoute(auth.roles, path)) return <AccessDenied />;
  return <>{children}</>;
}

function AccessDenied() {
  return (
    <section className="page-card">
      <h2>Access restricted</h2>
      <p>Your current role is not allowed to use this API surface. This is expected RBAC behavior for the research demo.</p>
    </section>
  );
}

function Layout() {
  const auth = useAuth();
  const navigate = useNavigate();
  const nav = getAllowedNavigation(auth.roles);

  return (
    <div className="app-shell">
      <aside className="sidebar">
        <div className="sidebar-title">
          <Shield size={24} />
          <div>
            <strong>Financial API</strong>
            <span>Research demo</span>
          </div>
        </div>
        <nav aria-label="Accounting workspace">
          {nav.map((item) => {
            const Icon = item.icon;
            return (
              <NavLink key={item.path} to={item.path}>
                <Icon size={18} />
                {item.label}
              </NavLink>
            );
          })}
        </nav>
      </aside>
      <div className="content-shell">
        <header className="topbar" aria-label="Current session">
          <div>
            <span className="eyebrow">Connected to {auth.apiBaseUrl}</span>
            <h1>{auth.currentUser?.username ?? "Financial Accounting"}</h1>
          </div>
          <div className="role-row">
            {auth.roles.map((role) => <span className="role-pill" key={role}>{role}</span>)}
            <button className="ghost-button" onClick={() => { auth.logout(); navigate("/"); }}><LogOut size={16} /> Logout</button>
          </div>
        </header>
        <main className="workspace-main">
          <Routes>
            <Route path="/dashboard" element={<ProtectedRoute path="/dashboard"><Dashboard /></ProtectedRoute>} />
            <Route path="/accounts" element={<ProtectedRoute path="/accounts"><AccountsPage /></ProtectedRoute>} />
            <Route path="/journal-entries" element={<ProtectedRoute path="/journal-entries"><JournalEntriesPage /></ProtectedRoute>} />
            <Route path="/periods" element={<ProtectedRoute path="/periods"><PeriodsPage /></ProtectedRoute>} />
            <Route path="/reports" element={<ProtectedRoute path="/reports"><ReportsPage /></ProtectedRoute>} />
            <Route path="/audit-logs" element={<ProtectedRoute path="/audit-logs"><AuditLogsPage /></ProtectedRoute>} />
            <Route path="/users" element={<ProtectedRoute path="/users"><UsersPage /></ProtectedRoute>} />
            <Route path="/research-evidence" element={<ProtectedRoute path="/research-evidence"><ResearchEvidencePage /></ProtectedRoute>} />
            <Route path="*" element={<Navigate to="/dashboard" replace />} />
          </Routes>
        </main>
      </div>
    </div>
  );
}

function Dashboard() {
  const { client, currentUser, roles } = useAuth();
  const action = useAsyncAction();
  const [accounts, setAccounts] = useState<Account[]>([]);
  const [periods, setPeriods] = useState<AccountingPeriod[]>([]);
  const [trialBalance, setTrialBalance] = useState<number | null>(null);

  async function load() {
    await action.run(async () => {
      const [accountResult, periodResult] = await Promise.all([client.getAccounts(), client.getPeriods()]);
      const normalizedAccounts = Array.isArray(accountResult) ? accountResult : accountResult.items ?? [];
      setAccounts(normalizedAccounts);
      setPeriods(periodResult);
      if (roles.some((role) => ["Admin", "FinanceManager", "Auditor"].includes(role))) {
        const report = await client.getTrialBalance(202601);
        setTrialBalance(report.totalDebit);
      }
    });
  }

  useEffect(() => { void load(); }, []);

  return (
    <section>
      <PageHeader title="Dashboard" context="Live API overview" action={<button className="ghost-button" onClick={load}><RefreshCw size={16} /> Refresh</button>} />
      <StatusMessages error={action.error} message={action.message} />
      <section aria-label="Live system overview">
        <div className="metric-grid">
          <Metric label="Current user" value={currentUser?.email ?? "-"} />
          <Metric label="Accounts loaded" value={String(accounts.length)} />
          <Metric label="Periods loaded" value={String(periods.length)} />
          <Metric label="Trial balance debit" value={trialBalance === null ? "Role restricted" : formatMoney(trialBalance)} />
        </div>
      </section>
      <ResearchEvidencePage compact />
    </section>
  );
}

function AccountsPage() {
  const { client, roles } = useAuth();
  const action = useAsyncAction();
  const [accounts, setAccounts] = useState<Account[]>([]);
  const [selectedBalance, setSelectedBalance] = useState<Account | null>(null);
  const [search, setSearch] = useState("");
  const [form, setForm] = useState({ accountCode: "", accountName: "", accountType: "Asset", isActive: true });

  async function load() {
    await action.run(async () => {
      const result = await client.getAccounts({ search, isActive: true });
      setAccounts(Array.isArray(result) ? result : result.items ?? []);
    });
  }

  async function create(event: FormEvent) {
    event.preventDefault();
    await action.run(async () => {
      await client.createAccount(form);
      setForm({ accountCode: "", accountName: "", accountType: "Asset", isActive: true });
      await load();
    }, "Account created.");
  }

  async function viewBalance(accountId: number) {
    await action.run(async () => {
      const result = await client.getAccountBalance(accountId);
      setSelectedBalance(result);
    });
  }

  useEffect(() => { void load(); }, []);

  return (
    <section className="page-card">
      <PageHeader title="Accounts" context="Search the chart of accounts and inspect current ledger balances." action={<button onClick={load}>Search</button>} />
      <label>Search accounts<input placeholder="Account code or name" value={search} onChange={(event) => setSearch(event.target.value)} /></label>
      <StatusMessages error={action.error} message={action.message} />
      {canMutate(roles, "accounts") ? (
        <form onSubmit={create} className="inline-form">
          <label>Account code<input value={form.accountCode} onChange={(e) => setForm({ ...form, accountCode: e.target.value })} /></label>
          <label>Account name<input value={form.accountName} onChange={(e) => setForm({ ...form, accountName: e.target.value })} /></label>
          <label>Account type<select value={form.accountType} onChange={(e) => setForm({ ...form, accountType: e.target.value })}>
            {["Asset", "Liability", "Equity", "Revenue", "Expense"].map((type) => <option key={type}>{type}</option>)}
          </select></label>
          <button>Create</button>
        </form>
      ) : <p className="read-only-note"><LockKeyhole size={16} />Read-only access: account maintenance is restricted for this role.</p>}
      {selectedBalance ? (
        <section className="balance-panel" aria-label="Ledger balance details">
          <div className="section-heading">
            <div>
              <span className="eyebrow">Ledger balance</span>
              <h3>{selectedBalance.accountCode} - {selectedBalance.accountName}</h3>
            </div>
            <button className="ghost-button" onClick={() => setSelectedBalance(null)}>Clear</button>
          </div>
          <div className="metric-grid">
            <Metric label="Debit total" value={formatMoney(selectedBalance.debitTotal)} />
            <Metric label="Credit total" value={formatMoney(selectedBalance.creditTotal)} />
            <Metric label="Balance" value={formatMoney(selectedBalance.balance)} />
          </div>
          <DataTable
            caption="Ledger balance details"
            headers={["Account ID", "Code", "Name", "Type", "Debit total", "Credit total", "Balance"]}
            numericColumns={[0, 4, 5, 6]}
            rows={[[
              selectedBalance.accountId,
              selectedBalance.accountCode,
              selectedBalance.accountName,
              selectedBalance.accountType,
              formatMoney(selectedBalance.debitTotal),
              formatMoney(selectedBalance.creditTotal),
              formatMoney(selectedBalance.balance),
            ]]}
          />
        </section>
      ) : null}
      <DataTable
        caption="Accounts"
        headers={["Code", "Name", "Type", "Active", "Ledger balance"]}
        rows={accounts.slice(0, 30).map((a) => [
          a.accountCode,
          a.accountName,
          a.accountType,
          a.isActive ? "Yes" : "No",
          <button aria-expanded={selectedBalance?.accountId === a.accountId} onClick={() => viewBalance(a.accountId)}>View balance for {a.accountCode}</button>,
        ])}
      />
    </section>
  );
}

function JournalEntriesPage() {
  const { client, roles } = useAuth();
  const action = useAsyncAction();
  const [entries, setEntries] = useState<JournalEntry[]>([]);
  const [accounts, setAccounts] = useState<Account[]>([]);
  const [amount, setAmount] = useState(25);

  async function load() {
    await action.run(async () => {
      const [entryResult, accountResult] = await Promise.all([
        client.getJournalEntries({ page: 1, pageSize: 20, sort: "entryDate_desc" }),
        client.getAccounts({ isActive: true }),
      ]);
      setEntries(entryResult.items ?? []);
      setAccounts((Array.isArray(accountResult) ? accountResult : accountResult.items ?? []).slice(0, 5));
    });
  }

  async function createDraft() {
    const debit = accounts[0];
    const credit = accounts[1];
    if (!debit || !credit) {
      action.setError("At least two active accounts are required.");
      return;
    }
    await action.run(async () => {
      await client.createJournalEntry({
        entryDate: new Date().toISOString(),
        description: "Web demo draft",
        referenceNo: `WEB-${Date.now()}`,
        lines: [
          { accountId: debit.accountId, debit: amount, credit: 0, lineDescription: "Web demo debit" },
          { accountId: credit.accountId, debit: 0, credit: amount, lineDescription: "Web demo credit" },
        ],
      });
      await load();
    }, "Draft journal entry created.");
  }

  useEffect(() => { void load(); }, []);

  return (
    <section className="page-card">
      <PageHeader title="Journal Entries" context="Review balanced entries and their posting status." action={<button className="ghost-button" onClick={load}>Refresh</button>} />
      <StatusMessages error={action.error} message={action.message} />
      {canMutate(roles, "journals") ? (
        <div className="inline-form">
          <label>Entry amount<input type="number" value={amount} onChange={(e) => setAmount(Number(e.target.value))} /></label>
          <button onClick={createDraft}>Create balanced draft</button>
          <button onClick={() => action.run(async () => {
            const debit = accounts[0];
            const credit = accounts[1];
            if (!debit || !credit) throw new Error("At least two accounts are required.");
            await client.bulkCreateJournalEntries([{
              entryDate: new Date().toISOString(),
              description: "Web demo bulk draft",
              lines: [
                { accountId: debit.accountId, debit: amount, credit: 0 },
                { accountId: credit.accountId, debit: 0, credit: amount },
              ],
            }]);
            await load();
          }, "Bulk entry created.")}>Bulk create</button>
        </div>
      ) : <p className="muted">Auditors cannot create journal entries.</p>}
      <JournalEntryTable
        entries={entries}
        canMutate={canMutate(roles, "journals")}
        canDelete={roles.includes("Admin")}
        formatMoney={formatMoney}
        formatDate={formatDate}
        onPost={(journalEntryId) => { void action.run(() => client.postJournalEntry(journalEntryId).then(load), "Entry posted."); }}
        onReverse={(journalEntryId) => { void action.run(() => client.reverseJournalEntry(journalEntryId).then(load), "Entry reversed."); }}
        onDelete={(journalEntryId) => { void action.run(() => client.deleteJournalEntry(journalEntryId).then(load), "Draft deleted."); }}
      />
    </section>
  );
}

function PeriodsPage() {
  const { client, roles } = useAuth();
  const action = useAsyncAction();
  const [periods, setPeriods] = useState<AccountingPeriod[]>([]);
  const [periodId, setPeriodId] = useState(202700);

  async function load() {
    await action.run(async () => setPeriods(await client.getPeriods()));
  }

  useEffect(() => { void load(); }, []);

  return (
    <section className="page-card">
      <PageHeader title="Accounting Periods" context="Manage reporting windows and period close status." action={<button className="ghost-button" onClick={load}>Refresh</button>} />
      <StatusMessages error={action.error} message={action.message} />
      {roles.includes("Admin") ? (
        <form className="inline-form" onSubmit={(event) => {
          event.preventDefault();
          void action.run(async () => {
            await client.createPeriod({ periodId, startDate: `${periodId.toString().slice(0, 4)}-01-01`, endDate: `${periodId.toString().slice(0, 4)}-12-31` });
            await load();
          }, "Period created.");
        }}>
          <label>Period ID<input type="number" value={periodId} onChange={(e) => setPeriodId(Number(e.target.value))} /></label>
          <button>Create period</button>
        </form>
      ) : null}
      <DataTable
        caption="Accounting periods"
        headers={["Period", "Start", "End", "Closed", "Actions"]}
        numericColumns={[0]}
        rows={periods.map((period) => [
          String(period.periodId),
          formatDate(period.startDate),
          formatDate(period.endDate),
          period.isClosed ? "Yes" : "No",
          canMutate(roles, "periods") ? <button onClick={() => action.run(() => client.closePeriod(period.periodId).then(load), "Period close requested.")}>Close</button> : "Restricted",
        ])}
      />
    </section>
  );
}

function ReportsPage() {
  const { client } = useAuth();
  const action = useAsyncAction();
  const [periodId, setPeriodId] = useState(202601);
  const [accountId, setAccountId] = useState(1);
  const [reportTitle, setReportTitle] = useState("Financial report");
  const [summary, setSummary] = useState<Array<[string, string]>>([]);
  const [reportTable, setReportTable] = useState<{ headers: string[]; rows: Array<Array<React.ReactNode>> }>({ headers: [], rows: [] });

  async function runReport(kind: "trial" | "profit" | "balance" | "ledger") {
    await action.run(async () => {
      if (kind === "trial") {
        const report = await client.getTrialBalance(periodId);
        setReportTitle("Trial balance report");
        setSummary([["Total debit", formatMoney(report.totalDebit)], ["Total credit", formatMoney(report.totalCredit)]]);
        setReportTable({
          headers: ["Account code", "Account name", "Type", "Debit", "Credit", "Balance"],
          rows: report.items.map((item) => [
            item.accountCode,
            item.accountName,
            item.accountType,
            formatMoney(item.debitTotal),
            formatMoney(item.creditTotal),
            formatMoney(item.balance),
          ]),
        });
      } else if (kind === "profit") {
        const report = await client.getProfitLoss(periodId);
        setReportTitle("Profit and loss report");
        setSummary([["Revenue", formatMoney(report.totalRevenue)], ["Expense", formatMoney(report.totalExpense)], ["Net profit", formatMoney(report.netProfit)]]);
        setReportTable({
          headers: ["Account code", "Account name", "Type", "Debit", "Credit", "Balance"],
          rows: report.items.map((item) => [
            item.accountCode,
            item.accountName,
            item.accountType,
            formatMoney(item.debitTotal),
            formatMoney(item.creditTotal),
            formatMoney(item.balance),
          ]),
        });
      } else if (kind === "balance") {
        const report = await client.getBalanceSheet(periodId);
        setReportTitle("Balance sheet report");
        setSummary([["Assets", formatMoney(report.totalAssets)], ["Liabilities", formatMoney(report.totalLiabilities)], ["Equity", formatMoney(report.totalEquity)]]);
        setReportTable({
          headers: ["Account code", "Account name", "Type", "Debit", "Credit", "Balance"],
          rows: report.items.map((item) => [
            item.accountCode,
            item.accountName,
            item.accountType,
            formatMoney(item.debitTotal),
            formatMoney(item.creditTotal),
            formatMoney(item.balance),
          ]),
        });
      } else {
        const report = await client.getAccountLedger(accountId, periodId);
        setReportTitle("Account ledger report");
        setSummary([["Opening", formatMoney(report.openingBalance)], ["Closing", formatMoney(report.closingBalance)], ["Lines", String(report.lines.length)]]);
        setReportTable({
          headers: ["Date", "Journal ID", "Reference", "Debit", "Credit", "Running balance"],
          rows: report.lines.map((line) => [
            formatDate(line.entryDate),
            line.journalEntryId,
            line.referenceNo ?? "-",
            formatMoney(line.debit),
            formatMoney(line.credit),
            formatMoney(line.runningBalance),
          ]),
        });
      }
    });
  }

  return (
    <section className="page-card">
      <PageHeader title="Reports Workspace" context="Generate live financial statements from the selected period and account." />
      <div className="toolbar" role="group" aria-label="Report parameters">
        <label>Period <input type="number" value={periodId} onChange={(e) => setPeriodId(Number(e.target.value))} /></label>
        <label>Account <input type="number" value={accountId} onChange={(e) => setAccountId(Number(e.target.value))} /></label>
        <button onClick={() => runReport("trial")}>Trial balance</button>
        <button onClick={() => runReport("profit")}>Profit/loss</button>
        <button onClick={() => runReport("balance")}>Balance sheet</button>
        <button onClick={() => runReport("ledger")}>Account ledger</button>
      </div>
      <StatusMessages error={action.error} message={action.message} />
      <div className="metric-grid">{summary.map(([label, value]) => <Metric key={label} label={label} value={value} />)}</div>
      {reportTable.headers.length > 0 ? (
        <DataTable caption={reportTitle} headers={reportTable.headers} rows={reportTable.rows} numericColumns={[3, 4, 5]} />
      ) : (
        <p className="muted">Select a report to load table rows.</p>
      )}
    </section>
  );
}

function AuditLogsPage() {
  const { client } = useAuth();
  const action = useAsyncAction();
  const [logs, setLogs] = useState<AuditLog[]>([]);
  const [actionFilter, setActionFilter] = useState("");

  async function load() {
    await action.run(async () => {
      const result = await client.getAuditLogs({ page: 1, pageSize: 50, action: actionFilter });
      setLogs(result.items ?? []);
    });
  }

  useEffect(() => { void load(); }, []);

  return (
    <section className="page-card">
      <PageHeader title="Audit Logs" context="Review recorded actions and their source context." action={<button className="ghost-button" onClick={load}>Refresh</button>} />
      <label>Filter by action<input placeholder="For example: JournalEntry.Posted" value={actionFilter} onChange={(e) => setActionFilter(e.target.value)} /></label>
      <StatusMessages error={action.error} message={action.message} />
      <DataTable caption="Audit logs" headers={["Time", "Action", "Entity", "Entity ID", "IP"]} rows={logs.map((log) => [formatDate(log.timestamp), log.action, log.entityName ?? "-", log.entityId ?? "-", log.ipAddress ?? "-"])} />
    </section>
  );
}

function UsersPage() {
  const { client } = useAuth();
  const action = useAsyncAction();
  const [form, setForm] = useState({ username: "", email: "", password: "Admin@123", role: "User" });

  return (
    <section className="page-card">
      <PageHeader title="User Administration" context="Create local demo users to verify role-based access." />
      <p className="muted">Admin-only endpoint for creating demo users and proving RBAC behavior.</p>
      <form className="form-grid" onSubmit={(event) => {
        event.preventDefault();
        void action.run(async () => {
          await client.createUser(form);
          setForm({ username: "", email: "", password: "Admin@123", role: "User" });
        }, "User created.");
      }}>
        <label>Username<input value={form.username} onChange={(e) => setForm({ ...form, username: e.target.value })} /></label>
        <label>Email<input value={form.email} onChange={(e) => setForm({ ...form, email: e.target.value })} /></label>
        <label>Password<input type="password" value={form.password} onChange={(e) => setForm({ ...form, password: e.target.value })} /></label>
        <label>Role<select value={form.role} onChange={(e) => setForm({ ...form, role: e.target.value })}>
          {["Admin", "FinanceManager", "User", "Auditor"].map((role) => <option key={role}>{role}</option>)}
        </select></label>
        <button>Create user</button>
      </form>
      <StatusMessages error={action.error} message={action.message} />
    </section>
  );
}

function ResearchEvidencePage({ compact = false }: { compact?: boolean }) {
  const { roles } = useAuth();
  const evidence = [
    ["Auth", "POST /auth/login and GET /users/me", "JWT token, expiry, current user"],
    ["RBAC", "Role-aware navigation", `Current roles: ${roles.join(", ") || "none"}`],
    ["Accounting", "Accounts, journals, periods", "CRUD and protected actions"],
    ["Reports", "Trial balance, P/L, balance sheet, ledger", "Live financial report endpoints"],
    ["Audit", "GET /audit-logs", "Admin/Auditor evidence path"],
  ];

  return (
    <section className={compact ? "evidence-compact" : "page-card"}>
      <PageHeader title="Research Evidence" context="Final report evidence for the live API workflow." action={<Sparkles size={22} aria-hidden="true" />} />
      <DataTable caption="Research evidence" headers={["Area", "API coverage", "Evidence value"]} rows={evidence} />
      <div className="checklist">
        {["Login screenshot", "Dashboard screenshot", "Role-restricted navigation", "Reports workspace", "Audit logs", "Final report insertion"].map((item) => (
          <span key={item}><CheckCircle2 size={14} /> {item}</span>
        ))}
      </div>
    </section>
  );
}

export function App() {
  const auth = useAuth();
  if (!auth.isAuthenticated) {
    return (
      <Routes>
        <Route path="*" element={<LoginPage />} />
      </Routes>
    );
  }
  return <Layout />;
}
