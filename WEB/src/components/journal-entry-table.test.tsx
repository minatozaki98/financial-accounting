import { fireEvent, render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import type { JournalEntry } from "../lib/api";
import { JournalEntryTable } from "./journal-entry-table";

const entry: JournalEntry = {
  journalEntryId: 10,
  entryDate: "2026-01-01",
  referenceNo: "JE-10",
  status: "Draft",
  debitTotal: 25,
  creditTotal: 25,
  lines: [{ accountId: 1, accountCode: "1000", accountName: "Cash", debit: 25, credit: 0, lineDescription: "Debit" }],
};

describe("JournalEntryTable", () => {
  it("keeps lines collapsed until the user requests them", () => {
    render(<JournalEntryTable entries={[entry]} canMutate={false} formatMoney={(value) => `$${value}`} formatDate={(value) => value ?? ""} />);

    expect(screen.queryByText("Line debit")).not.toBeInTheDocument();

    fireEvent.click(screen.getByRole("button", { name: "Show lines for JE-10" }));

    expect(screen.getByText("Line debit")).toBeVisible();
    expect(screen.getByRole("button", { name: "Hide lines for JE-10" })).toHaveAttribute("aria-expanded", "true");
  });
});
