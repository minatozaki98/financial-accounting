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
    internal class RoleRepository:GenericRepository<Role>, IRoleRepository
    {
        public RoleRepository(DataContext context) : base(context) { }
    }
}
