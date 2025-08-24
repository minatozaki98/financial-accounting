using Microsoft.AspNetCore.Mvc;
using REPOSITORY.UnitOfWork;
using System.Net.NetworkInformation;
using MODEL.ApplicationConfig;
using Asp.Versioning;
using Microsoft.AspNetCore.Authorization;
using BAL.IServices;
using MODEL.DTOs;

namespace API.Controllers
{
    [Produces("application/json")]
    [ApiController]
    [Route("api/v{version:apiVersion}/[controller]")]
    [ApiVersion("1")]
    //[Authorize]
    public class LogController : ControllerBase
    {
        private readonly IUnitOfWork _unitOfWork;
        private readonly ILogService _logService;
        public LogController(IUnitOfWork unitOfWork, ILogService logService)
        {
           _unitOfWork = unitOfWork;
            _logService = logService;
        }
        [HttpGet("GetLog")]
        public async Task<IActionResult> GetLog()
        {
            try
            {
                 var returndata = await _unitOfWork.Log.GetAll();
               // var returndata = await _unitOfWork.Log.GetLogAll();
                return Ok(new ResponseModel { Message = Messages.Successfully, Status = APIStatus.Successful, Data = returndata });
            }
            catch (Exception ex)
            {
                return Ok(new ResponseModel { Message = ex.Message, Status = APIStatus.SystemError });
            }
        }
        [HttpPost("AddLog")]
        public async Task<IActionResult> AddLog(AddLogDTO inputModel)
        {
            try
            {
                await _logService.AddLog(inputModel);
                return Ok(new ResponseModel { Message = Messages.AddSucess, Status = APIStatus.Successful });
            }
            catch (Exception ex)
            {
                return Ok(new ResponseModel { Message = ex.Message, Status = APIStatus.SystemError });
            }
        }
    }
}
