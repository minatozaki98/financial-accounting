import { Fragment, useState } from "react";
import type { JournalEntry } from "../lib/api";

type JournalEntryTableProps = {
  entries: JournalEntry[];
  canMutate: boolean;
  canDelete?: boolean;
  formatMoney: (value?: number) => string;
  formatDate: (value?: string) => string;
  onPost?: (journalEntryId: number) => void;
  onReverse?: (journalEntryId: number) => void;
  onDelete?: (journalEntryId: number) => void;
};

function entryLabel(entry: JournalEntry) {
  return entry.referenceNo ?? `entry ${entry.journalEntryId}`;
}

export function JournalEntryTable({
  entries,
  canMutate,
  canDelete = false,
  formatMoney,
  formatDate,
  onPost,
  onReverse,
  onDelete,
}: JournalEntryTableProps) {
  const [expandedEntryId, setExpandedEntryId] = useState<number | null>(null);

  return (
    <div className="table-wrap">
      <table aria-label="Journal entries">
        <thead>
          <tr>
            <th>ID</th>
            <th>Date</th>
            <th>Reference</th>
            <th>Status</th>
            <th className="numeric">Debit</th>
            <th className="numeric">Credit</th>
            <th>Detail</th>
            <th>Actions</th>
          </tr>
        </thead>
        <tbody>
          {entries.length === 0 ? (
            <tr><td colSpan={8}>No journal entries found.</td></tr>
          ) : entries.map((entry) => {
            const expanded = expandedEntryId === entry.journalEntryId;
            const label = entryLabel(entry);
            return (
              <Fragment key={entry.journalEntryId}>
                <tr>
                  <td className="numeric">{entry.journalEntryId}</td>
                  <td>{formatDate(entry.entryDate)}</td>
                  <td>{entry.referenceNo ?? "-"}</td>
                  <td><span className="status-badge">{entry.status}</span></td>
                  <td className="numeric">{formatMoney(entry.debitTotal)}</td>
                  <td className="numeric">{formatMoney(entry.creditTotal)}</td>
                  <td>
                    <button
                      type="button"
                      className="table-link-button"
                      aria-expanded={expanded}
                      aria-controls={`journal-lines-${entry.journalEntryId}`}
                      onClick={() => setExpandedEntryId((current) => current === entry.journalEntryId ? null : entry.journalEntryId)}
                    >
                      {expanded ? `Hide lines for ${label}` : `Show lines for ${label}`}
                    </button>
                  </td>
                  <td>
                    {canMutate ? (
                      <div className="table-actions">
                        <button type="button" onClick={() => onPost?.(entry.journalEntryId)}>Post</button>
                        <button type="button" onClick={() => onReverse?.(entry.journalEntryId)}>Reverse</button>
                        {canDelete ? <button type="button" onClick={() => onDelete?.(entry.journalEntryId)}>Delete</button> : null}
                      </div>
                    ) : "Restricted"}
                  </td>
                </tr>
                {expanded ? (
                  <tr className="journal-detail-row">
                    <td colSpan={8}>
                      <section className="journal-detail" id={`journal-lines-${entry.journalEntryId}`} aria-label={`Journal lines for ${label}`}>
                        <div className="journal-detail-heading"><strong>Journal lines</strong><span>{entry.lines.length} line{entry.lines.length === 1 ? "" : "s"}</span></div>
                        <div className="journal-line-grid" role="list">
                          {entry.lines.map((line, index) => (
                            <div className="journal-line" role="listitem" key={`${line.accountId}-${index}`}>
                              <div><span>Account</span><strong>{line.accountCode ?? line.accountId}</strong>{line.accountName ? <small>{line.accountName}</small> : null}</div>
                              <div><span>Description</span><strong>{line.lineDescription ?? "-"}</strong></div>
                              <div className="numeric"><span>Line debit</span><strong>{formatMoney(line.debit)}</strong></div>
                              <div className="numeric"><span>Line credit</span><strong>{formatMoney(line.credit)}</strong></div>
                            </div>
                          ))}
                        </div>
                      </section>
                    </td>
                  </tr>
                ) : null}
              </Fragment>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}
