import { describe, expect, it, vi } from "vitest";
import { ApiClient, ApiError } from "./api";

describe("ApiClient", () => {
  it("sends bearer tokens and parses JSON responses", async () => {
    const fetchMock = vi.fn().mockResolvedValue(
      new Response(JSON.stringify({ items: [{ accountId: 1 }] }), {
        status: 200,
        headers: { "content-type": "application/json" },
      }),
    );
    const client = new ApiClient("http://api.test", () => "token-123", fetchMock);

    const result = await client.getAccounts({ search: "cash", isActive: true });

    const items = Array.isArray(result) ? result : result.items ?? [];
    expect(items[0].accountId).toBe(1);
    expect(fetchMock).toHaveBeenCalledWith(
      "http://api.test/accounts?search=cash&isActive=true",
      expect.objectContaining({
        headers: expect.objectContaining({ Authorization: "Bearer token-123" }),
      }),
    );
  });

  it("raises typed API errors with response status and message", async () => {
    const fetchMock = vi.fn().mockResolvedValue(
      new Response(JSON.stringify({ message: "Forbidden" }), {
        status: 403,
        headers: { "content-type": "application/json" },
      }),
    );
    const client = new ApiClient("http://api.test", () => "token-123", fetchMock);

    await expect(client.getCurrentUser()).rejects.toMatchObject({
      status: 403,
      message: "Forbidden",
    });
  });

  it("normalizes PascalCase account ledger payloads returned by file endpoints", async () => {
    const fetchMock = vi.fn().mockResolvedValue(
      new Response(JSON.stringify({
        PeriodId: 202601,
        AccountId: 1,
        AccountCode: "1000",
        AccountName: "Cash",
        OpeningBalance: 0,
        ClosingBalance: 442467.16,
        Lines: [{
          EntryDate: "2026-01-01T00:00:00",
          JournalEntryId: 1,
          ReferenceNo: "OPENING-001",
          LineDescription: "Capital in cash",
          Debit: 10000,
          Credit: 0,
          RunningBalance: 10000,
        }],
      }), {
        status: 200,
        headers: { "content-type": "application/json" },
      }),
    );
    const client = new ApiClient("http://api.test", () => "token-123", fetchMock);

    const result = await client.getAccountLedger(1, 202601);

    expect(result.lines).toHaveLength(1);
    expect(result.closingBalance).toBe(442467.16);
    expect(result.lines[0]).toMatchObject({
      journalEntryId: 1,
      lineDescription: "Capital in cash",
      debit: 10000,
      runningBalance: 10000,
    });
  });
});
