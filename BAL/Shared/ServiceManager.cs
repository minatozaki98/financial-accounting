using Microsoft.Extensions.DependencyInjection;
using MODEL.ApplicationConfig;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using MODEL;
using BAL.IServices;
using BAL.Services;

namespace BAL.Shared
{
    public class ServiceManager
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
