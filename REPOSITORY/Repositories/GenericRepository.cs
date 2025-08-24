using Microsoft.EntityFrameworkCore;
using MODEL;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Linq.Expressions;
using System.Net;
using System.Text;
using System.Threading.Tasks;

namespace REPOSITORY.Repositories
{
    internal class GenericRepository<T>: IGenericRepository<T> where T : class
    {
        private readonly DataContext _context;
        private readonly DbSet<T> _entities;

        public GenericRepository(DataContext context)
        {
            _context = context;
            _entities = _context.Set<T>();
        }

        public async Task Add(T entity)
        {

            if (entity == null)
            {
                throw new ArgumentNullException(nameof(entity));
            }

            await _entities.AddAsync(entity);
        }

        public async Task AddMultiple(IEnumerable<T> entity)
        {
            if (entity == null)
            {
                throw new ArgumentNullException(nameof(entity));
            }

            await _entities.AddRangeAsync(entity);
        }

        public void Delete(T entity)
        {
            if (entity == null)
            {
                throw new ArgumentNullException(nameof(entity));
            }

            _entities.Remove(entity);
        }

        public void DeleteMultiple(IEnumerable<T> entity)
        {
            if (entity == null)
            {
                throw new ArgumentNullException(nameof(entity));
            }

            _entities.RemoveRange(entity);
        }

        public async Task<IEnumerable<T>> GetAll() => await _entities.ToListAsync();

        public async Task<IEnumerable<T>> GetAllAsyncWithPagination(int page, int pageSize)
        {
            var entities = await _entities.ToListAsync();
            var totalCount = entities.Count();
            var totalPages = (int)Math.Ceiling((double)totalCount / pageSize);

            if (page < 1 || page > totalPages)
            {
                var errors = new Dictionary<string, string>
                {
                    { "Pagination", $"Invalid page number. The page number should be between 1 and {totalPages}." },
                };
                throw new Exception();//CustomException(errors, HttpStatusCode.BadRequest);
            }

            var entitiesPerPage = entities.Skip((page - 1) * pageSize).Take(pageSize);

            if (!entitiesPerPage.Any())
            {
                var errors = new Dictionary<string, string>
                {
                    { "Pagination", $"No entities found on page {page}." },
                };
                throw new ArgumentNullException(nameof(entitiesPerPage));
              //  throw new CustomException(errors, HttpStatusCode.NotFound);
            }

            return entitiesPerPage;
        }

        public async Task<T?> GetById(int id) => await _entities.FindAsync(id);

        public async Task<T?> GetByIdAsync(int id)
        {
            var entities = await _entities.FindAsync(id);

            if (entities == null)
            {
                var errors = new Dictionary<string, string>
                {
                    { "Category", $"Category with ID {id} not found." },
                };
               // throw new CustomException(errors, HttpStatusCode.NotFound);
               throw new ArgumentNullException($"{nameof(entities)}");
            }

            return entities;
        }

        public void Update(T entity)
        {
            if (entity == null)
            {
                throw new ArgumentNullException(nameof(entity));
            }

            _entities.Update(entity);
        }

        public void UpdateMultiple(IEnumerable<T> entity)
        {
            if (entity == null)
            {
                throw new ArgumentNullException(nameof(entity));
            }

            _entities.UpdateRange(entity);
        }

        public async Task<IEnumerable<T>> GetByCondition(Expression<Func<T, bool>> expression)
        {
            var entities = _entities.Where(expression);

            if (entities == null)
            {
                var errors = new Dictionary<string, string>
                {
                    { "Entity", "Entities not found." },
                };
                // throw new CustomException(errors, HttpStatusCode.NotFound);
                throw new ArgumentException();
            }

            return await Task.FromResult(entities.ToList());
        }

        public async Task<IEnumerable<T>> GetByConditionWithPagination(Expression<Func<T, bool>> expression, int page, int pageSize)
        {
            var entities = _entities.Where(expression);
            var totalCount = await entities.CountAsync();
            var totalPages = (int)Math.Ceiling((double)totalCount / pageSize);

            if (page < 1 || page > totalPages)
            {
                var errors = new Dictionary<string, string>
                {
                    { "Pagination", $"Invalid page number. The page number should be between 1 and {totalPages}." },
                };
                throw new ArgumentNullException();
             //   throw new CustomException(errors, HttpStatusCode.BadRequest);
            }

            var entitiesPerPage = entities.Skip((page - 1) * pageSize).Take(pageSize);

            if (!entitiesPerPage.Any())
            {
                var errors = new Dictionary<string, string>
                {
                    { "Pagination", $"No entities found on page {page}." },
                };
                throw new ArgumentNullException();
                //throw new CustomException(errors, HttpStatusCode.NotFound);
            }

            return entitiesPerPage;
        }

        public async Task<bool> Create(T entity)
        {
            try
            {
                await _context.Set<T>().AddAsync(entity);
                await _context.SaveChangesAsync();
                return true;

            }
            catch (Exception ex)
            {
                Console.WriteLine(ex.Message.ToString());
                return false;
            }
        }
        public List<T> GetByExp(Expression<Func<T, bool>> predicate)
        {
            try
            {
                return new List<T>(_context.Set<T>().Where(predicate).AsNoTracking());
            }
            catch (Exception ex)
            {
                Console.WriteLine(ex.Message.ToString());
                throw;
            }
        }
    }
}
