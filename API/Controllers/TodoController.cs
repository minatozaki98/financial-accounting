using Asp.Versioning;
using BAL.IServices;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MODEL.ApplicationConfig;
using MODEL.DTOs;
using REPOSITORY.UnitOfWork;

namespace API.Controllers
{
    [Produces("application/json")]
    [ApiController]
    [Route("api/v{version:apiVersion}/[controller]")]
    [ApiVersion("1")]
  //  [Authorize]
    public class TodoController : ControllerBase
    {
        private readonly IUnitOfWork _unitOfWork;
        private readonly ITodoService _todoService;
        public TodoController(IUnitOfWork unitOfWork, ITodoService todoService)
        {
          _unitOfWork = unitOfWork ?? throw new ArgumentNullException(nameof(unitOfWork));
            _todoService = todoService ?? throw new ArgumentNullException(nameof(todoService));
        }
        [HttpGet("GetTodoAll")]
        public async Task<IActionResult> GetTodoAll()
        {
            try
            {
                var returndata = await _unitOfWork.Todo.GetByCondition(x=>x.ActiveFlag);
                return Ok(new ResponseModel { Message = Messages.Successfully, Status = APIStatus.Successful, Data = returndata });
            }
            catch (Exception ex)
            {
                return Ok(new ResponseModel { Message = ex.Message, Status = APIStatus.SystemError });
            }
        }
        [HttpPost("AddTodo")]
        public async Task<IActionResult> AddTodo(AddTodoDTO inputModel)
        {
            try
            {
                await _todoService.AddTodo(inputModel);
                return Ok(new ResponseModel { Message = Messages.AddSucess, Status = APIStatus.Successful });
            }
            catch (Exception ex)
            {
                return Ok(new ResponseModel { Message = ex.Message, Status = APIStatus.SystemError });
            }
        }
        [HttpPost("UpdateTodo")]
        public async Task<IActionResult> UpdateTodo(UpdateTodoDTO inputModel)
        {
            try
            {
                var updatetodo = await _todoService.UpdateTodo(inputModel);
                if (updatetodo)
                {
                    return Ok(new ResponseModel { Message = Messages.UpdateSucess, Status = APIStatus.Successful });
                }
                return Ok(new ResponseModel { Message = Messages.UpdateFail, Status = APIStatus.Error });
            }
            catch (Exception ex)
            {
                return Ok(new ResponseModel { Message = ex.Message, Status = APIStatus.SystemError });
            }
        }
        [HttpDelete("DeleteTodo/{todoID}")]
        public async Task<IActionResult> DeleteTodo(Guid todoID)
        {
            try
            {
                var deletetodo = (await _unitOfWork.Todo.GetByCondition(x=>x.ID == todoID)).FirstOrDefault();
                if (deletetodo != null)
                {
                    deletetodo.ActiveFlag = false;
                     _unitOfWork.Todo.Update(deletetodo);
                    await _unitOfWork.SaveChangesAsync();
                    return Ok(new ResponseModel { Message = Messages.DeleteSucess, Status = APIStatus.Successful });
                }
                return Ok(new ResponseModel { Message = Messages.UpdateFail, Status = APIStatus.Error });
            }
            catch (Exception ex)
            {
                return Ok(new ResponseModel { Message = ex.Message, Status = APIStatus.SystemError });
            }
        }
    }
}
