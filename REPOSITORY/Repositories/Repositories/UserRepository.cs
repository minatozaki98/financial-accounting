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
    internal class UserRepository:GenericRepository<Users>, IUserRepository
    {
        public UserRepository(DataContext context) : base(context) { }
    }
}
