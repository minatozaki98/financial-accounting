using Microsoft.Extensions.DependencyInjection;
using MODEL.ApplicationConfig;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using MODEL;
using REPOSITORY.UnitOfWork;
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
            services.AddScoped<IUnitOfWork, UnitOfWork>();
            services.AddScoped<IAuthenticationService, AuthenticationService>();
            services.AddScoped<ILogService, LogService>();
            services.AddScoped<ITodoService, TodoService>();
            services.AddScoped<ITextToSpeechService, TextToSpeechService>();
            services.AddScoped<ILexiconService, LexiconService>();
        }
    }
}
