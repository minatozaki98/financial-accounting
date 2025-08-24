using AutoMapper;
using BAL.IServices;
using MODEL.DTOs;
using MODEL.Entities;
using REPOSITORY.UnitOfWork;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Net.Http.Headers;
using System.Text;
using System.Threading.Tasks;

namespace BAL.Services
{
    internal class TodoService:ITodoService
    {
        private readonly IUnitOfWork _unitOfWork;
        private readonly IMapper _mapper;
        public TodoService(IUnitOfWork unitOfWork, IMapper mapper) { 
            _unitOfWork = unitOfWork ?? throw new ArgumentNullException(nameof(unitOfWork));
            _mapper = mapper ?? throw new ArgumentNullException(nameof(mapper));
        }
        public async Task AddTodo(AddTodoDTO inputModel)
        {
            try
            {
                var addtodomapper = _mapper.Map<Todo>(inputModel);
                //var tododata = new Todo()
                //{
                //    Title = inputModel.Title,
                //    Description = inputModel.Description,
                //    Status = inputModel.Status,
                //};
               await _unitOfWork.Todo.Add(addtodomapper);
               await _unitOfWork.SaveChangesAsync();
            }
            catch (Exception)
            {

                throw;
            }
        }
        public async Task<bool> UpdateTodo(UpdateTodoDTO inputModel)
        {
            try
            {
                var tododata = (await _unitOfWork.Todo.GetByCondition(x => x.ActiveFlag && x.ID == inputModel.ID)).FirstOrDefault();
                if (tododata != null)
                {
                    tododata.Title = inputModel.Title;
                    tododata.Description = inputModel.Description;
                    tododata.Status = inputModel.Status;
                    _unitOfWork.Todo.Update(tododata);
                    await _unitOfWork.SaveChangesAsync();
                    return true;
                }
                return false;
            }
            catch (Exception)
            {
                
                throw;
            }
        }
    }
}
