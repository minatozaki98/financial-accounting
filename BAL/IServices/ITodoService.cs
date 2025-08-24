using MODEL.DTOs;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace BAL.IServices
{
    public interface ITodoService
    {
        Task AddTodo(AddTodoDTO inputModel);
        Task<bool> UpdateTodo(UpdateTodoDTO inputModel);
    }
}
