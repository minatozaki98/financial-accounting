using Microsoft.EntityFrameworkCore;
using MODEL;
using MODEL.Entities;

namespace BAL.Shared
{
    public sealed class FinancialRoleStartupSeeder
    {
        private readonly DataContext _context;

        public FinancialRoleStartupSeeder(DataContext context)
        {
            _context = context;
        }

        public async Task SeedAsync(CancellationToken cancellationToken = default)
        {
            var definitions = new[]
            {
                new { Name = "Admin", Description = "System administrator role" },
                new { Name = "User", Description = "Default application user role" },
                new { Name = "Auditor", Description = "Read-only financial audit role" },
                new { Name = "FinanceManager", Description = "Financial operations manager role" }
            };

            var existing = await _context.FinancialRoles
                .Select(x => x.RoleName)
                .ToListAsync(cancellationToken);

            var toAdd = new List<FinancialRole>();
            foreach (var definition in definitions)
            {
                if (existing.Any(x => string.Equals(x, definition.Name, StringComparison.OrdinalIgnoreCase)))
                {
                    continue;
                }

                toAdd.Add(new FinancialRole
                {
                    RoleName = definition.Name,
                    Description = definition.Description
                });
            }

            if (toAdd.Count == 0)
            {
                return;
            }

            await _context.FinancialRoles.AddRangeAsync(toAdd, cancellationToken);
            await _context.SaveChangesAsync(cancellationToken);
        }
    }
}
