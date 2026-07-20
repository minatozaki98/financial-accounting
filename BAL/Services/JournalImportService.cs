using BAL.IServices;
using Microsoft.EntityFrameworkCore;
using MODEL;
using MODEL.DTOs;
using MODEL.Entities;
using System.Globalization;
using System.Text;

namespace BAL.Services
{
    internal sealed class JournalImportService : IJournalImportService
    {
        private const string ExpectedHeader = "EntryDate,ReferenceNo,Description,AccountCode,Debit,Credit";
        private const string ValidatedStatus = "Validated";
        private const string CommittedStatus = "Committed";
        private const string DraftStatus = "Draft";
        private const int MaximumRows = 10_000;

        private readonly DataContext _context;
        private readonly IAuditLogService _auditLogService;

        public JournalImportService(DataContext context, IAuditLogService auditLogService)
        {
            _context = context;
            _auditLogService = auditLogService;
        }

        public async Task<JournalImportValidationResponseDto> ValidateCsvAsync(
            Stream csv,
            string fileName,
            string idempotencyKey,
            bool atomic,
            Guid actorUserId,
            string? ipAddress,
            CancellationToken cancellationToken = default)
        {
            var existing = await _context.JournalImportBatches
                .AsNoTracking()
                .Include(batch => batch.Rows)
                .FirstOrDefaultAsync(
                    batch => batch.CreatedByUserId == actorUserId &&
                             batch.IdempotencyKey == idempotencyKey,
                    cancellationToken);
            if (existing != null)
            {
                return MapValidation(existing, replayed: true);
            }

            var rows = await ParseRowsAsync(csv, cancellationToken);
            await ValidateRowsAsync(rows, cancellationToken);

            var batch = new JournalImportBatch
            {
                ImportId = Guid.NewGuid(),
                CreatedByUserId = actorUserId,
                IdempotencyKey = idempotencyKey,
                FileName = fileName,
                Atomic = atomic,
                Status = ValidatedStatus,
                TotalRows = rows.Count,
                ValidRows = rows.Count(row => row.IsValid),
                InvalidRows = rows.Count(row => !row.IsValid),
                Rows = rows
            };

            _context.JournalImportBatches.Add(batch);
            await _context.SaveChangesAsync(cancellationToken);
            await _auditLogService.WriteAsync(
                actorUserId,
                "VALIDATE_JOURNAL_IMPORT",
                "JournalImportBatches",
                batch.ImportId.ToString(),
                ipAddress,
                new
                {
                    batch.TotalRows,
                    batch.ValidRows,
                    batch.InvalidRows,
                    batch.Atomic
                });

            return MapValidation(batch, replayed: false);
        }

        public async Task<JournalImportCommitResponseDto> CommitAsync(
            Guid importId,
            Guid actorUserId,
            string? ipAddress,
            CancellationToken cancellationToken = default)
        {
            var batch = await _context.JournalImportBatches
                .Include(item => item.Rows)
                .Include(item => item.CreatedEntries)
                .FirstOrDefaultAsync(
                    item => item.ImportId == importId && item.CreatedByUserId == actorUserId,
                    cancellationToken)
                ?? throw new KeyNotFoundException("Journal import was not found.");

            if (string.Equals(batch.Status, CommittedStatus, StringComparison.OrdinalIgnoreCase))
            {
                return MapCommit(batch, replayed: true);
            }

            if (batch.Atomic && batch.InvalidRows > 0)
            {
                throw new InvalidOperationException("Atomic journal import contains invalid rows.");
            }

            var validGroups = batch.Rows
                .GroupBy(row => row.EntryReference, StringComparer.OrdinalIgnoreCase)
                .Where(group => group.All(row => row.IsValid))
                .ToList();
            if (validGroups.Count == 0)
            {
                throw new InvalidOperationException("Journal import has no valid journal entries to commit.");
            }

            await using var transaction = await _context.Database.BeginTransactionAsync(cancellationToken);
            try
            {
                foreach (var group in validGroups)
                {
                    var first = group.First();
                    var entry = new JournalEntry
                    {
                        EntryDate = first.EntryDate!.Value.Date,
                        Description = first.Description,
                        ReferenceNo = first.EntryReference,
                        Status = DraftStatus,
                        CreatedByUserId = actorUserId,
                        CreatedAt = DateTime.UtcNow,
                        ImportBatchId = batch.ImportId
                    };

                    foreach (var row in group.OrderBy(item => item.RowNumber))
                    {
                        entry.Lines.Add(new JournalEntryLine
                        {
                            AccountId = row.AccountId!.Value,
                            LineDescription = row.Description,
                            Debit = row.Debit,
                            Credit = row.Credit
                        });
                    }

                    batch.CreatedEntries.Add(entry);
                }

                batch.Status = CommittedStatus;
                batch.CommittedAt = DateTime.UtcNow;
                await _context.SaveChangesAsync(cancellationToken);
                await _auditLogService.WriteAsync(
                    actorUserId,
                    "COMMIT_JOURNAL_IMPORT",
                    "JournalImportBatches",
                    batch.ImportId.ToString(),
                    ipAddress,
                    new { EntryCount = batch.CreatedEntries.Count });
                await transaction.CommitAsync(cancellationToken);

                return MapCommit(batch, replayed: false);
            }
            catch
            {
                await transaction.RollbackAsync(cancellationToken);
                throw;
            }
        }

        private static async Task<List<JournalImportRow>> ParseRowsAsync(
            Stream csv,
            CancellationToken cancellationToken)
        {
            using var reader = new StreamReader(
                csv,
                new UTF8Encoding(encoderShouldEmitUTF8Identifier: false, throwOnInvalidBytes: true),
                detectEncodingFromByteOrderMarks: true,
                leaveOpen: true);
            var header = await reader.ReadLineAsync(cancellationToken);
            if (!string.Equals(header?.TrimStart('\uFEFF'), ExpectedHeader, StringComparison.Ordinal))
            {
                throw new InvalidOperationException($"CSV header must be exactly: {ExpectedHeader}.");
            }

            var rows = new List<JournalImportRow>();
            var rowNumber = 1;
            while (await reader.ReadLineAsync(cancellationToken) is { } line)
            {
                rowNumber++;
                if (rows.Count >= MaximumRows)
                {
                    throw new InvalidOperationException($"CSV cannot contain more than {MaximumRows} data rows.");
                }

                rows.Add(ParseRow(line, rowNumber));
            }

            if (rows.Count == 0)
            {
                throw new InvalidOperationException("CSV must contain at least one data row.");
            }

            return rows;
        }

        private static JournalImportRow ParseRow(string line, int rowNumber)
        {
            var values = ParseCsvLine(line);
            var row = new JournalImportRow
            {
                RowNumber = rowNumber,
                IsValid = true
            };
            if (values.Count != 6)
            {
                MarkInvalid(row, "Row must contain exactly six columns.");
                return row;
            }

            row.EntryReference = values[1].Trim();
            row.Description = NullIfWhiteSpace(values[2]);
            row.AccountCode = values[3].Trim();

            if (!DateTime.TryParseExact(
                    values[0].Trim(),
                    "yyyy-MM-dd",
                    CultureInfo.InvariantCulture,
                    DateTimeStyles.None,
                    out var entryDate))
            {
                MarkInvalid(row, "EntryDate must use yyyy-MM-dd.");
            }
            else
            {
                row.EntryDate = entryDate.Date;
            }

            if (string.IsNullOrWhiteSpace(row.EntryReference))
            {
                MarkInvalid(row, "ReferenceNo is required.");
            }
            if (string.IsNullOrWhiteSpace(row.AccountCode))
            {
                MarkInvalid(row, "AccountCode is required.");
            }
            if (!TryParseAmount(values[4], out var debit))
            {
                MarkInvalid(row, "Debit must be a non-negative invariant decimal.");
            }
            if (!TryParseAmount(values[5], out var credit))
            {
                MarkInvalid(row, "Credit must be a non-negative invariant decimal.");
            }

            row.Debit = debit;
            row.Credit = credit;
            if ((row.Debit > 0m) == (row.Credit > 0m))
            {
                MarkInvalid(row, "Each row must contain exactly one positive debit or credit.");
            }

            return row;
        }

        private async Task ValidateRowsAsync(
            List<JournalImportRow> rows,
            CancellationToken cancellationToken)
        {
            var accountCodes = rows
                .Where(row => !string.IsNullOrWhiteSpace(row.AccountCode))
                .Select(row => row.AccountCode)
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .ToList();
            var accounts = await _context.ChartOfAccounts
                .AsNoTracking()
                .Where(account => accountCodes.Contains(account.AccountCode) && account.IsActive)
                .ToListAsync(cancellationToken);
            var accountMap = accounts.ToDictionary(
                account => account.AccountCode,
                StringComparer.OrdinalIgnoreCase);

            foreach (var row in rows)
            {
                if (!accountMap.TryGetValue(row.AccountCode, out var account))
                {
                    MarkInvalid(row, "AccountCode is unknown or inactive.");
                }
                else
                {
                    row.AccountId = account.AccountId;
                }
            }

            var dates = rows
                .Where(row => row.EntryDate.HasValue)
                .Select(row => row.EntryDate!.Value)
                .Distinct()
                .ToList();
            var periods = await _context.AccountingPeriods
                .AsNoTracking()
                .Where(period => dates.Any(date => date >= period.StartDate && date <= period.EndDate))
                .ToListAsync(cancellationToken);
            foreach (var row in rows.Where(item => item.EntryDate.HasValue))
            {
                var period = periods.FirstOrDefault(item =>
                    row.EntryDate!.Value >= item.StartDate &&
                    row.EntryDate.Value <= item.EndDate);
                if (period == null)
                {
                    MarkInvalid(row, "EntryDate does not belong to an accounting period.");
                }
                else if (period.IsClosed)
                {
                    MarkInvalid(row, "EntryDate belongs to a closed accounting period.");
                }
            }

            var references = rows
                .Where(row => !string.IsNullOrWhiteSpace(row.EntryReference))
                .Select(row => row.EntryReference)
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .ToList();
            var existingReferences = await _context.JournalEntries
                .AsNoTracking()
                .Where(entry => entry.ReferenceNo != null && references.Contains(entry.ReferenceNo))
                .Select(entry => entry.ReferenceNo!)
                .ToListAsync(cancellationToken);
            var duplicateReferences = existingReferences.ToHashSet(StringComparer.OrdinalIgnoreCase);

            foreach (var group in rows.GroupBy(row => row.EntryReference, StringComparer.OrdinalIgnoreCase))
            {
                if (group.Key.Length == 0)
                {
                    continue;
                }
                if (duplicateReferences.Contains(group.Key))
                {
                    MarkGroupInvalid(group, "ReferenceNo already exists.");
                }
                if (group.Count() < 2)
                {
                    MarkGroupInvalid(group, "A journal entry must contain at least two rows.");
                }
                if (group.Where(row => row.EntryDate.HasValue)
                    .Select(row => row.EntryDate!.Value)
                    .Distinct()
                    .Count() > 1)
                {
                    MarkGroupInvalid(group, "Rows for one ReferenceNo must use the same EntryDate.");
                }

                var debitTotal = decimal.Round(group.Sum(row => row.Debit), 2);
                var creditTotal = decimal.Round(group.Sum(row => row.Credit), 2);
                if (debitTotal <= 0m || debitTotal != creditTotal)
                {
                    MarkGroupInvalid(group, "Journal entry debit and credit totals must balance.");
                }
            }
        }

        private static List<string> ParseCsvLine(string line)
        {
            var values = new List<string>();
            var current = new StringBuilder();
            var quoted = false;
            for (var index = 0; index < line.Length; index++)
            {
                var character = line[index];
                if (character == '"')
                {
                    if (quoted && index + 1 < line.Length && line[index + 1] == '"')
                    {
                        current.Append('"');
                        index++;
                    }
                    else
                    {
                        quoted = !quoted;
                    }
                }
                else if (character == ',' && !quoted)
                {
                    values.Add(current.ToString());
                    current.Clear();
                }
                else
                {
                    current.Append(character);
                }
            }

            values.Add(current.ToString());
            return values;
        }

        private static bool TryParseAmount(string value, out decimal amount)
        {
            var parsed = decimal.TryParse(
                value.Trim(),
                NumberStyles.AllowDecimalPoint,
                CultureInfo.InvariantCulture,
                out amount);
            if (!parsed || amount < 0m)
            {
                amount = 0m;
                return false;
            }

            amount = decimal.Round(amount, 2);
            return true;
        }

        private static string? NullIfWhiteSpace(string value)
        {
            var trimmed = value.Trim();
            return trimmed.Length == 0 ? null : trimmed;
        }

        private static void MarkGroupInvalid(
            IEnumerable<JournalImportRow> rows,
            string error)
        {
            foreach (var row in rows)
            {
                MarkInvalid(row, error);
            }
        }

        private static void MarkInvalid(JournalImportRow row, string error)
        {
            row.IsValid = false;
            row.Error = string.IsNullOrWhiteSpace(row.Error)
                ? error
                : $"{row.Error} {error}";
        }

        private static JournalImportValidationResponseDto MapValidation(
            JournalImportBatch batch,
            bool replayed)
        {
            return new JournalImportValidationResponseDto
            {
                ImportId = batch.ImportId,
                Status = batch.Status,
                Atomic = batch.Atomic,
                TotalRows = batch.TotalRows,
                ValidRows = batch.ValidRows,
                InvalidRows = batch.InvalidRows,
                Replayed = replayed,
                Errors = batch.Rows
                    .Where(row => !row.IsValid)
                    .OrderBy(row => row.RowNumber)
                    .Select(row => new JournalImportErrorDto
                    {
                        RowNumber = row.RowNumber,
                        Error = row.Error ?? "Invalid row."
                    })
                    .ToList()
            };
        }

        private static JournalImportCommitResponseDto MapCommit(
            JournalImportBatch batch,
            bool replayed)
        {
            return new JournalImportCommitResponseDto
            {
                ImportId = batch.ImportId,
                Status = batch.Status,
                CreatedEntryIds = batch.CreatedEntries
                    .Select(entry => entry.JournalEntryId)
                    .OrderBy(id => id)
                    .ToList(),
                Replayed = replayed
            };
        }
    }
}
