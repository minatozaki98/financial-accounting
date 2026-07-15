import type { ReactNode } from "react";
import { AlertTriangle, CheckCircle2 } from "lucide-react";

export function PageHeader({ title, context, action }: { title: string; context?: string; action?: ReactNode }) {
  return (
    <header className="page-header">
      <div>
        <h2>{title}</h2>
        {context ? <p>{context}</p> : null}
      </div>
      {action ? <div className="page-header-actions">{action}</div> : null}
    </header>
  );
}

export function Metric({ label, value, tone = "default" }: { label: string; value: string; tone?: "default" | "positive" | "warning" }) {
  return (
    <article className={`metric metric-${tone}`}>
      <span>{label}</span>
      <strong>{value}</strong>
    </article>
  );
}

export function StatusMessages({ error, message }: { error?: string | null; message?: string | null }) {
  return (
    <div className="status-stack" aria-live="polite">
      {error ? <div className="notice notice-error" role="alert"><AlertTriangle size={16} />{error}</div> : null}
      {message ? <div className="notice notice-success" role="status"><CheckCircle2 size={16} />{message}</div> : null}
    </div>
  );
}

export function EmptyState({ title, detail }: { title: string; detail: string }) {
  return (
    <div className="empty-state">
      <strong>{title}</strong>
      <p>{detail}</p>
    </div>
  );
}

export function DataTable({
  caption,
  headers,
  rows,
  numericColumns = [],
}: {
  caption: string;
  headers: string[];
  rows: Array<Array<ReactNode>>;
  numericColumns?: number[];
}) {
  return (
    <div className="table-wrap">
      <table aria-label={caption}>
        <thead>
          <tr>
            {headers.map((header, index) => <th className={numericColumns.includes(index) ? "numeric" : undefined} key={header}>{header}</th>)}
          </tr>
        </thead>
        <tbody>
          {rows.length === 0 ? (
            <tr><td colSpan={headers.length}><EmptyState title="No rows found" detail="Adjust the current filter or load data again." /></td></tr>
          ) : rows.map((row, rowIndex) => (
            <tr key={rowIndex}>
              {row.map((cell, cellIndex) => <td className={numericColumns.includes(cellIndex) ? "numeric" : undefined} key={cellIndex}>{cell}</td>)}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
