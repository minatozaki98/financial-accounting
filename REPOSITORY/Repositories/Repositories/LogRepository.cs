using MODEL;
using MODEL.Entities;
using REPOSITORY.Repositories.IRepositories;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace REPOSITORY.Repositories.Repositories
{
    internal class LogRepository:GenericRepository<Log>,ILogRepository
    {
        private readonly DataContext _dataContext;
        public LogRepository(DataContext context) : base(context) { 
            _dataContext = context;
        }
        public async Task<List<Log>> GetLogAll()
        {
            var returndata = (from td in _dataContext.Log
                             select td).ToList();
            return returndata;
        }
    }
}
