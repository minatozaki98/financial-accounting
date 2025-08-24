using Microsoft.Extensions.Options;
using MODEL;
using MODEL.ApplicationConfig;
using REPOSITORY.Repositories.IRepositories;
using REPOSITORY.Repositories.Repositories;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace REPOSITORY.UnitOfWork
{
    public class UnitOfWork:IUnitOfWork
    {
        private DataContext _dataContext;
        public UnitOfWork(DataContext dataContext, IOptions<AppSettings> appsettings)
        {
            _dataContext = dataContext;
            AppSettings = appsettings.Value;
            Log = new LogRepository(_dataContext);
            Users = new UserRepository(_dataContext);
            Role = new RoleRepository(_dataContext);
            Todo = new TodoRepository(_dataContext);
            Lexicon = new LexiconRepository(_dataContext);
            TextToSpeechHistory = new TextToSpeechRepository(_dataContext);
        }
        public ILogRepository Log {  get; set; }
        public IUserRepository Users { get; set; }
        public IRoleRepository Role { get; set; }
        public ITodoRepository Todo { get; set; }
        public ITextToSpeechHistoryRepository TextToSpeechHistory {  get; set; }
        public ILexiconRepository Lexicon { get; set; }
        public AppSettings AppSettings { get; private set; }

        public void Dispose()
        {
            _dataContext.Dispose();
        }

        public async Task<int> SaveChangesAsync()
        {
            return await _dataContext.SaveChangesAsync();
        }
    }
}
