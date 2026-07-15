export type FetchLike = typeof fetch;

export class ApiError extends Error {
  status: number;
  details: unknown;

  constructor(status: number, message: string, details?: unknown) {
    super(message);
    this.name = "ApiError";
    this.status = status;
    this.details = details;
  }
}

export type LoginResponse = {
  accessToken: string;
  accessTokenExpiresAtUtc: string;
  roles: string[];
};

export type CurrentUser = {
  userId: string;
  username: string;
  email: string;
  isActive: boolean;
  roles: string[];
};

export type Account = {
  accountId: number;
  accountCode: string;
  accountName: string;
  accountType: string;
  isActive: boolean;
  debitTotal?: number;
  creditTotal?: number;
  balance?: number;
};

export type JournalEntryLine = {
  accountId: number;
  accountCode?: string;
  accountName?: string;
  lineDescription?: string;
  debit: number;
  credit: number;
};

export type JournalEntry = {
  journalEntryId: number;
  entryDate: string;
  description?: string;
  referenceNo?: string;
  status: string;
  debitTotal: number;
  creditTotal: number;
  lines: JournalEntryLine[];
};

export type PagedResult<T> = {
  page: number;
  pageSize: number;
  totalCount: number;
  items: T[];
};

export type AccountingPeriod = {
  periodId: number;
  startDate: string;
  endDate: string;
  isClosed: boolean;
  closedAt?: string;
};

export type ReportItem = Account & {
  debitTotal: number;
  creditTotal: number;
  balance: number;
};

export type TrialBalance = {
  periodId: number;
  startDate: string;
  endDate: string;
  totalDebit: number;
  totalCredit: number;
  items: ReportItem[];
};

export type ProfitLoss = {
  periodId: number;
  totalRevenue: number;
  totalExpense: number;
  netProfit: number;
  items: ReportItem[];
};

export type BalanceSheet = {
  periodId: number;
  totalAssets: number;
  totalLiabilities: number;
  totalEquity: number;
  items: ReportItem[];
};

export type AccountLedger = {
  periodId: number;
  accountId: number;
  accountCode: string;
  accountName: string;
  accountType?: string;
  startDate?: string;
  endDate?: string;
  openingBalance: number;
  closingBalance: number;
  lines: Array<{
    entryDate: string;
    journalEntryId: number;
    referenceNo?: string;
    entryDescription?: string;
    lineDescription?: string;
    debit: number;
    credit: number;
    runningBalance: number;
  }>;
};

export type AuditLog = {
  auditLogId: number;
  userId?: string;
  action: string;
  entityName?: string;
  entityId?: string;
  timestamp: string;
  ipAddress?: string;
  detailsJson?: string;
};

type QueryValue = string | number | boolean | null | undefined;

function queryString(query?: Record<string, QueryValue>): string {
  if (!query) return "";
  const params = new URLSearchParams();
  Object.entries(query).forEach(([key, value]) => {
    if (value !== undefined && value !== null && value !== "") {
      params.set(key, String(value));
    }
  });
  const serialized = params.toString();
  return serialized ? `?${serialized}` : "";
}

async function parseResponse(response: Response): Promise<unknown> {
  if (response.status === 204) return null;
  const contentType = response.headers.get("content-type") ?? "";
  if (contentType.includes("application/json")) {
    return response.json();
  }
  return response.text();
}

function resolveMessage(body: unknown, fallback: string): string {
  if (typeof body === "string" && body.trim()) return body;
  if (body && typeof body === "object") {
    const candidate = body as { message?: string; title?: string; detail?: string };
    return candidate.message ?? candidate.detail ?? candidate.title ?? fallback;
  }
  return fallback;
}

type RawAccountLedgerLine = {
  entryDate?: string;
  journalEntryId?: number;
  referenceNo?: string;
  entryDescription?: string;
  lineDescription?: string;
  debit?: number;
  credit?: number;
  runningBalance?: number;
  EntryDate?: string;
  JournalEntryId?: number;
  ReferenceNo?: string;
  EntryDescription?: string;
  LineDescription?: string;
  Debit?: number;
  Credit?: number;
  RunningBalance?: number;
};

type RawAccountLedger = {
  periodId?: number;
  accountId?: number;
  accountCode?: string;
  accountName?: string;
  accountType?: string;
  startDate?: string;
  endDate?: string;
  openingBalance?: number;
  closingBalance?: number;
  lines?: RawAccountLedgerLine[];
  PeriodId?: number;
  AccountId?: number;
  AccountCode?: string;
  AccountName?: string;
  AccountType?: string;
  StartDate?: string;
  EndDate?: string;
  OpeningBalance?: number;
  ClosingBalance?: number;
  Lines?: RawAccountLedgerLine[];
};

function normalizeAccountLedger(raw: RawAccountLedger): AccountLedger {
  const rawLines = raw.lines ?? raw.Lines ?? [];
  return {
    periodId: raw.periodId ?? raw.PeriodId ?? 0,
    accountId: raw.accountId ?? raw.AccountId ?? 0,
    accountCode: raw.accountCode ?? raw.AccountCode ?? "",
    accountName: raw.accountName ?? raw.AccountName ?? "",
    accountType: raw.accountType ?? raw.AccountType,
    startDate: raw.startDate ?? raw.StartDate,
    endDate: raw.endDate ?? raw.EndDate,
    openingBalance: raw.openingBalance ?? raw.OpeningBalance ?? 0,
    closingBalance: raw.closingBalance ?? raw.ClosingBalance ?? 0,
    lines: rawLines.map((line) => ({
      entryDate: line.entryDate ?? line.EntryDate ?? "",
      journalEntryId: line.journalEntryId ?? line.JournalEntryId ?? 0,
      referenceNo: line.referenceNo ?? line.ReferenceNo,
      entryDescription: line.entryDescription ?? line.EntryDescription,
      lineDescription: line.lineDescription ?? line.LineDescription,
      debit: line.debit ?? line.Debit ?? 0,
      credit: line.credit ?? line.Credit ?? 0,
      runningBalance: line.runningBalance ?? line.RunningBalance ?? 0,
    })),
  };
}

export class ApiClient {
  private readonly baseUrl: string;
  private readonly getToken: () => string | null;
  private readonly fetchImpl: FetchLike;

  constructor(baseUrl: string, getToken: () => string | null, fetchImpl: FetchLike = globalThis.fetch.bind(globalThis)) {
    this.baseUrl = baseUrl.replace(/\/$/, "");
    this.getToken = getToken;
    this.fetchImpl = fetchImpl;
  }

  private async request<T>(path: string, init: RequestInit = {}): Promise<T> {
    const token = this.getToken();
    const headers: Record<string, string> = {
      Accept: "application/json",
      ...(init.headers as Record<string, string> | undefined),
    };
    if (init.body && !headers["Content-Type"]) {
      headers["Content-Type"] = "application/json";
    }
    if (token) {
      headers.Authorization = `Bearer ${token}`;
    }

    const response = await this.fetchImpl(`${this.baseUrl}${path}`, { ...init, headers });
    const body = await parseResponse(response);
    if (!response.ok) {
      throw new ApiError(response.status, resolveMessage(body, response.statusText), body);
    }
    return body as T;
  }

  getHealth(): Promise<string> {
    return this.request<string>("/health/live");
  }

  login(username: string, password: string): Promise<LoginResponse> {
    return this.request<LoginResponse>("/auth/login", {
      method: "POST",
      body: JSON.stringify({ username, password }),
    });
  }

  getCurrentUser(): Promise<CurrentUser> {
    return this.request<CurrentUser>("/users/me");
  }

  createUser(payload: { username: string; email: string; password: string; role: string }) {
    return this.request<CurrentUser>("/users", { method: "POST", body: JSON.stringify(payload) });
  }

  getAccounts(query?: { type?: string; isActive?: boolean; search?: string }) {
    return this.request<Account[] | { items?: Account[] }>(`/accounts${queryString(query)}`);
  }

  createAccount(payload: { accountCode: string; accountName: string; accountType: string; isActive: boolean }) {
    return this.request<Account>("/accounts", { method: "POST", body: JSON.stringify(payload) });
  }

  updateAccount(accountId: number, payload: { accountName: string; accountType: string; isActive: boolean }) {
    return this.request<void>(`/accounts/${accountId}`, { method: "PUT", body: JSON.stringify(payload) });
  }

  getAccountBalance(accountId: number) {
    return this.request<Account>(`/accounts/${accountId}/balance`);
  }

  getJournalEntries(query?: Record<string, QueryValue>) {
    return this.request<PagedResult<JournalEntry>>(`/journal-entries${queryString(query)}`);
  }

  createJournalEntry(payload: {
    entryDate: string;
    description?: string;
    referenceNo?: string;
    lines: Array<{ accountId: number; lineDescription?: string; debit: number; credit: number }>;
  }) {
    return this.request<JournalEntry>("/journal-entries", { method: "POST", body: JSON.stringify(payload) });
  }

  bulkCreateJournalEntries(entries: Array<Parameters<ApiClient["createJournalEntry"]>[0]>) {
    return this.request<{ ids: number[] }>("/journal-entries/bulk", {
      method: "POST",
      body: JSON.stringify({ entries }),
    });
  }

  postJournalEntry(id: number) {
    return this.request<void>(`/journal-entries/${id}/post`, { method: "POST" });
  }

  reverseJournalEntry(id: number) {
    return this.request<{ reversingEntryId: number }>(`/journal-entries/${id}/reverse`, { method: "POST" });
  }

  deleteJournalEntry(id: number) {
    return this.request<void>(`/journal-entries/${id}`, { method: "DELETE" });
  }

  getPeriods() {
    return this.request<AccountingPeriod[]>("/periods");
  }

  createPeriod(payload: { periodId: number; startDate: string; endDate: string }) {
    return this.request<AccountingPeriod>("/periods", { method: "POST", body: JSON.stringify(payload) });
  }

  closePeriod(periodId: number) {
    return this.request<void>(`/periods/${periodId}/close`, { method: "POST" });
  }

  getTrialBalance(periodId: number) {
    return this.request<TrialBalance>(`/reports/trial-balance${queryString({ periodId })}`);
  }

  getProfitLoss(periodId: number) {
    return this.request<ProfitLoss>(`/reports/profit-loss${queryString({ periodId })}`);
  }

  getBalanceSheet(periodId: number) {
    return this.request<BalanceSheet>(`/reports/balance-sheet${queryString({ periodId })}`);
  }

  getAccountLedger(accountId: number, periodId: number) {
    return this.request<RawAccountLedger>(`/reports/account-ledger${queryString({ accountId, periodId })}`)
      .then(normalizeAccountLedger);
  }

  getAuditLogs(query?: Record<string, QueryValue>) {
    return this.request<PagedResult<AuditLog>>(`/audit-logs${queryString(query)}`);
  }
}
