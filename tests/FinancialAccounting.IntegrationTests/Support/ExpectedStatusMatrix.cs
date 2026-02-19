namespace FinancialAccounting.IntegrationTests.Support;

public static class ExpectedStatusMatrix
{
    public static readonly IReadOnlyDictionary<string, IDictionary<string, int>> EndpointRoleStatus =
        new Dictionary<string, IDictionary<string, int>>(StringComparer.OrdinalIgnoreCase)
        {
            ["GET /users/me"] = new Dictionary<string, int> { ["Admin"] = 200, ["FinanceManager"] = 200, ["User"] = 200, ["Auditor"] = 200, ["Anonymous"] = 401 },
            ["POST /users"] = new Dictionary<string, int> { ["Admin"] = 201, ["FinanceManager"] = 403, ["User"] = 403, ["Auditor"] = 403, ["Anonymous"] = 401 },
            ["GET /accounts"] = new Dictionary<string, int> { ["Admin"] = 200, ["FinanceManager"] = 200, ["User"] = 200, ["Auditor"] = 200, ["Anonymous"] = 401 },
            ["POST /accounts"] = new Dictionary<string, int> { ["Admin"] = 201, ["FinanceManager"] = 403, ["User"] = 403, ["Auditor"] = 403, ["Anonymous"] = 401 },
            ["GET /periods"] = new Dictionary<string, int> { ["Admin"] = 200, ["FinanceManager"] = 200, ["User"] = 200, ["Auditor"] = 200, ["Anonymous"] = 401 },
            ["POST /periods"] = new Dictionary<string, int> { ["Admin"] = 201, ["FinanceManager"] = 403, ["User"] = 403, ["Auditor"] = 403, ["Anonymous"] = 401 },
            ["POST /periods/{id}/close"] = new Dictionary<string, int> { ["Admin"] = 204, ["FinanceManager"] = 404, ["User"] = 403, ["Auditor"] = 403, ["Anonymous"] = 401 },
            ["POST /journal-entries"] = new Dictionary<string, int> { ["Admin"] = 201, ["FinanceManager"] = 201, ["User"] = 201, ["Auditor"] = 403, ["Anonymous"] = 401 },
            ["POST /journal-entries/bulk"] = new Dictionary<string, int> { ["Admin"] = 200, ["FinanceManager"] = 200, ["User"] = 403, ["Auditor"] = 403, ["Anonymous"] = 401 },
            ["POST /journal-entries/{id}/post"] = new Dictionary<string, int> { ["Admin"] = 204, ["FinanceManager"] = 404, ["User"] = 403, ["Auditor"] = 403, ["Anonymous"] = 401 },
            ["POST /journal-entries/{id}/reverse"] = new Dictionary<string, int> { ["Admin"] = 200, ["FinanceManager"] = 200, ["User"] = 403, ["Auditor"] = 403, ["Anonymous"] = 401 },
            ["DELETE /journal-entries/{id}"] = new Dictionary<string, int> { ["Admin"] = 404, ["FinanceManager"] = 403, ["User"] = 403, ["Auditor"] = 403, ["Anonymous"] = 401 },
            ["GET /reports/trial-balance"] = new Dictionary<string, int> { ["Admin"] = 200, ["FinanceManager"] = 200, ["User"] = 403, ["Auditor"] = 200, ["Anonymous"] = 401 },
            ["GET /audit-logs"] = new Dictionary<string, int> { ["Admin"] = 200, ["FinanceManager"] = 403, ["User"] = 403, ["Auditor"] = 200, ["Anonymous"] = 401 }
        };
}
