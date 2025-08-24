using System;
using System.Collections.Generic;
using System.Linq;
using System.Linq.Expressions;
using System.Text;
using System.Threading.Tasks;

namespace REPOSITORY.Repositories
{
    public interface IGenericRepository<T> where T : class
    {
        Task<IEnumerable<T>> GetAll();
        Task<IEnumerable<T>> GetAllAsyncWithPagination(int page, int pageSize);
        Task<T?> GetById(int id);
        Task<T?> GetByIdAsync(int id);
        Task Add(T entity);
        Task AddMultiple(IEnumerable<T> entity);
        void Update(T entity);
        void UpdateMultiple(IEnumerable<T> entity);
        void Delete(T entity);
        void DeleteMultiple(IEnumerable<T> entity);
        Task<IEnumerable<T>> GetByCondition(Expression<Func<T, bool>> expression);
        Task<IEnumerable<T>> GetByConditionWithPagination(Expression<Func<T, bool>> expression, int page, int pageSize);
        Task<bool> Create(T entity);
        List<T> GetByExp(Expression<Func<T, bool>> predicate);
    }
}
