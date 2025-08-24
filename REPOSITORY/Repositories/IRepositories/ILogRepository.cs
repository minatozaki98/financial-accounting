using MODEL.Entities;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace REPOSITORY.Repositories.IRepositories
{
    public interface ILogRepository: IGenericRepository<Log>
    {
        Task<List<Log>> GetLogAll();
    }
}
