using MODEL.ApplicationConfig;
using REPOSITORY.Repositories.IRepositories;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace REPOSITORY.UnitOfWork
{
    public interface IUnitOfWork: IDisposable
    {
        ILogRepository Log { get; }
        IUserRepository Users { get; }
        IRoleRepository Role { get; }
        ITodoRepository Todo { get; }
        ITextToSpeechHistoryRepository TextToSpeechHistory { get; }
        ILexiconRepository Lexicon {  get; }
        AppSettings AppSettings { get; }    
        Task<int> SaveChangesAsync();
    }
}
