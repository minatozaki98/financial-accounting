using BAL.IServices;
using BAL.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using MODEL;
using MODEL.ApplicationConfig;

namespace BAL.Shared
{
    public static class ServiceManager
    {
        public static void SetServiceInfo(IServiceCollection services, AppSettings appSettings)
        {
            services.AddDbContextPool<DataContext>(options =>
            {
                options.UseSqlServer(appSettings.ConnectionStrings);
            });
            services.AddSingleton<IAccountLedgerCache, AccountLedgerCache>();
            services.AddScoped<FinancialTokenProvider>();
            services.AddScoped<FinancialRoleStartupSeeder>();
            services.AddScoped<SqlServerPerformanceIndexStartup>();
            services.AddScoped<IAuditLogService, AuditLogService>();
            services.AddScoped<IFinancialAuthService, FinancialAuthService>();
            services.AddScoped<IChartOfAccountsService, ChartOfAccountsService>();
            services.AddScoped<IAccountingPeriodService, AccountingPeriodService>();
            services.AddScoped<IJournalEntryService, JournalEntryService>();
            services.AddScoped<IFinancialReportService, FinancialReportService>();
        }
    }
}
