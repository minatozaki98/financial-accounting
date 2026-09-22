from __future__ import annotations

import json
import subprocess
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "Document" / "paper" / "figures"
SQLCMD = r"C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\170\Tools\Binn\SQLCMD.EXE"


def font(name: str, size: int):
    candidate = Path("C:/Windows/Fonts") / name
    fallback = Path("C:/Windows/Fonts/arial.ttf")
    return ImageFont.truetype(str(candidate if candidate.exists() else fallback), size)


TITLE_FONT = font("arialbd.ttf", 34)
SUBTITLE_FONT = font("arial.ttf", 20)
HEADER_FONT = font("arialbd.ttf", 20)
BODY_FONT = font("arial.ttf", 19)
FOOT_FONT = font("arial.ttf", 17)


QUERIES = (
    {
        "file": "dataset-accounts.png",
        "title": "Accounts sample",
        "count_table": "ChartOfAccounts",
        "columns": ["AccountCode", "AccountName", "AccountType", "Active"],
        "sql": """
            SELECT TOP 6
                AccountCode,
                AccountName,
                AccountType,
                CASE WHEN IsActive = 1 THEN 'Yes' ELSE 'No' END AS Active
            FROM ChartOfAccounts
            ORDER BY AccountId
            FOR JSON PATH;
        """,
    },
    {
        "file": "dataset-users-roles.png",
        "title": "Users and roles sample",
        "count_table": "Users",
        "columns": ["Username", "RoleName", "Active"],
        "sql": """
            WITH ranked AS (
                SELECT
                    u.Username,
                    COALESCE(r.RoleName, 'Unassigned') AS RoleName,
                    CASE WHEN u.IsActive = 1 THEN 'Yes' ELSE 'No' END AS Active,
                    ROW_NUMBER() OVER (
                        PARTITION BY COALESCE(r.RoleName, 'Unassigned')
                        ORDER BY u.CreatedAt, u.Username
                    ) AS rn
                FROM Users u
                LEFT JOIN UserRoles ur ON ur.UserId = u.UserId
                LEFT JOIN Roles r ON r.RoleId = ur.RoleId
            )
            SELECT TOP 6 Username, RoleName, Active
            FROM ranked
            WHERE rn = 1
            ORDER BY RoleName, Username
            FOR JSON PATH;
        """,
    },
    {
        "file": "dataset-journal-lines.png",
        "title": "Journal entries and balanced lines",
        "count_table": "JournalEntries",
        "columns": ["EntryId", "EntryDate", "ReferenceNo", "Status", "AccountCode", "Debit", "Credit"],
        "sql": """
            WITH selected AS (
                SELECT TOP 3 JournalEntryId, EntryDate, ReferenceNo, Status
                FROM JournalEntries
                ORDER BY JournalEntryId DESC
            )
            SELECT TOP 6
                s.JournalEntryId AS EntryId,
                CONVERT(varchar(10), s.EntryDate, 23) AS EntryDate,
                s.ReferenceNo,
                s.Status,
                a.AccountCode,
                CAST(l.Debit AS decimal(18,2)) AS Debit,
                CAST(l.Credit AS decimal(18,2)) AS Credit
            FROM selected s
            JOIN JournalEntryLines l ON l.JournalEntryId = s.JournalEntryId
            JOIN ChartOfAccounts a ON a.AccountId = l.AccountId
            ORDER BY s.JournalEntryId DESC, l.JournalEntryLineId
            FOR JSON PATH;
        """,
    },
    {
        "file": "dataset-periods.png",
        "title": "Accounting periods sample",
        "count_table": "AccountingPeriods",
        "columns": ["PeriodId", "StartDate", "EndDate", "Closed"],
        "sql": """
            SELECT TOP 6
                PeriodId,
                CONVERT(varchar(10), StartDate, 23) AS StartDate,
                CONVERT(varchar(10), EndDate, 23) AS EndDate,
                CASE WHEN IsClosed = 1 THEN 'Yes' ELSE 'No' END AS Closed
            FROM AccountingPeriods
            ORDER BY PeriodId
            FOR JSON PATH;
        """,
    },
    {
        "file": "dataset-trial-balance.png",
        "title": "Derived trial-balance sample",
        "count_table": "JournalEntryLines",
        "columns": ["AccountCode", "AccountName", "DebitTotal", "CreditTotal", "Balance"],
        "sql": """
            SELECT TOP 6
                a.AccountCode,
                a.AccountName,
                CAST(SUM(l.Debit) AS decimal(18,2)) AS DebitTotal,
                CAST(SUM(l.Credit) AS decimal(18,2)) AS CreditTotal,
                CAST(SUM(l.Debit - l.Credit) AS decimal(18,2)) AS Balance
            FROM JournalEntryLines l
            JOIN JournalEntries e ON e.JournalEntryId = l.JournalEntryId
            JOIN ChartOfAccounts a ON a.AccountId = l.AccountId
            WHERE e.Status = 'Posted'
            GROUP BY a.AccountCode, a.AccountName, a.AccountId
            ORDER BY a.AccountId
            FOR JSON PATH;
        """,
    },
    {
        "file": "dataset-audit-logs.png",
        "title": "Audit-log sample",
        "count_table": "AuditLogs",
        "columns": ["Action", "EntityName", "EntityId", "Timestamp"],
        "sql": """
            SELECT TOP 6
                Action,
                EntityName,
                EntityId,
                CONVERT(varchar(19), Timestamp, 120) AS Timestamp
            FROM AuditLogs
            ORDER BY AuditLogId DESC
            FOR JSON PATH;
        """,
    },
)


def query_json(sql: str):
    command = [
        SQLCMD,
        "-S",
        "localhost",
        "-d",
        "Financial",
        "-E",
        "-C",
        "-y",
        "0",
        "-w",
        "65535",
        "-Q",
        "SET NOCOUNT ON; " + " ".join(sql.split()),
    ]
    result = subprocess.run(command, check=True, capture_output=True, text=True, encoding="utf-8")
    return json.loads(result.stdout.strip() or "[]")


def row_count(table: str) -> int:
    command = [
        SQLCMD,
        "-S",
        "localhost",
        "-d",
        "Financial",
        "-E",
        "-C",
        "-h",
        "-1",
        "-W",
        "-Q",
        f"SET NOCOUNT ON; SELECT COUNT_BIG(*) FROM {table};",
    ]
    result = subprocess.run(command, check=True, capture_output=True, text=True, encoding="utf-8")
    return int(result.stdout.strip())


def fit_text(draw: ImageDraw.ImageDraw, text: str, width: int, font_obj) -> str:
    value = str(text if text is not None else "")
    if draw.textbbox((0, 0), value, font=font_obj)[2] <= width:
        return value
    while value and draw.textbbox((0, 0), value + "...", font=font_obj)[2] > width:
        value = value[:-1]
    return value + "..."


def render(config, rows, count: int):
    columns = config["columns"]
    width = 1700
    margin = 55
    title_height = 104
    header_height = 52
    row_height = 54
    footer_height = 58
    height = title_height + header_height + max(1, len(rows)) * row_height + footer_height + 30
    image = Image.new("RGB", (width, height), "#F4F5F7")
    draw = ImageDraw.Draw(image)

    draw.rectangle((0, 0, width, title_height), fill="#25282D")
    draw.text((margin, 22), config["title"], font=TITLE_FONT, fill="white")
    draw.text(
        (margin, 68),
        f"Financial database | {count:,} source rows | read-only sample query",
        font=SUBTITLE_FONT,
        fill="#CCD3DC",
    )

    available = width - margin * 2
    weights = []
    for column in columns:
        max_len = max([len(column)] + [len(str(row.get(column, ""))) for row in rows])
        weights.append(max(8, min(max_len, 28)))
    total_weight = sum(weights)
    col_widths = [int(available * weight / total_weight) for weight in weights]
    col_widths[-1] += available - sum(col_widths)

    x = margin
    y = title_height
    for column, col_width in zip(columns, col_widths):
        draw.rectangle((x, y, x + col_width, y + header_height), fill="#DCE6F1", outline="#8190A0", width=2)
        draw.text((x + 10, y + 14), fit_text(draw, column, col_width - 20, HEADER_FONT), font=HEADER_FONT, fill="#17212B")
        x += col_width

    for row_index, row in enumerate(rows or [{}]):
        x = margin
        row_y = y + header_height + row_index * row_height
        fill = "#FFFFFF" if row_index % 2 == 0 else "#EDF1F5"
        for column, col_width in zip(columns, col_widths):
            draw.rectangle((x, row_y, x + col_width, row_y + row_height), fill=fill, outline="#A5AFBA", width=1)
            value = fit_text(draw, row.get(column, ""), col_width - 20, BODY_FONT)
            draw.text((x + 10, row_y + 15), value, font=BODY_FONT, fill="#20252B")
            x += col_width

    footer_y = y + header_height + max(1, len(rows)) * row_height + 14
    draw.text(
        (margin, footer_y),
        "Synthetic seeded data. Credentials, password fields, IP addresses, and raw audit JSON are excluded.",
        font=FOOT_FONT,
        fill="#56616D",
    )
    image.save(OUTPUT / config["file"], quality=95)


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for config in QUERIES:
        rows = query_json(config["sql"])
        count = row_count(config["count_table"])
        render(config, rows, count)
        print(OUTPUT / config["file"])


if __name__ == "__main__":
    main()
