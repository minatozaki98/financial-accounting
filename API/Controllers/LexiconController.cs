using Asp.Versioning;
using BAL.IServices;
using Microsoft.AspNetCore.Mvc;
using MODEL.ApplicationConfig;
using MODEL.DTOs;
using REPOSITORY.UnitOfWork;
using System.Text.Json;

namespace API.Controllers
{
    [Produces("application/json")]
    [ApiController]
    [Route("api/v{version:apiVersion}/[controller]")]
    [ApiVersion("1")]
    public class LexiconController : ControllerBase
    {
        private readonly IUnitOfWork _unitOfWork;
        private readonly ILexiconService _lexiconService;
        public LexiconController(IUnitOfWork unitOfWork, ILexiconService lexiconService)
        {
            _unitOfWork = unitOfWork;
            _lexiconService = lexiconService;
        }
        [HttpGet("GetAllLexicon")]
        public async Task<IActionResult> GetAllLexicon()
        {
            try
            {
                var returndata = await _unitOfWork.Lexicon.GetByCondition(x => x.ActiveFlag);
              
                return Ok(new ResponseModel { Message = Messages.Successfully, Status = APIStatus.Successful, Data = returndata });
            }
            catch (Exception ex)
            {
                return Ok(new ResponseModel { Message = ex.Message, Status = APIStatus.SystemError });
            }
        }
        [HttpPost("AddLexicon")]
        public async Task<IActionResult> AddLexicon(AddLexiconDTO inputModel)
        {
            try
            {
                await _lexiconService.AddLexicon(inputModel);
                return Ok(new ResponseModel { Message = Messages.AddSucess, Status = APIStatus.Successful });
            }
            catch (Exception ex)
            {
                return Ok(new ResponseModel { Message = ex.Message, Status = APIStatus.SystemError });
            }
        }
        [HttpPost("UpdateLexicon")]
        public async Task<IActionResult> UpdateLexicon(UpdateLexiconDTO inputModel)
        {
            try
            {
                await _lexiconService.UpdateLexicon(inputModel);
                return Ok(new ResponseModel { Message = Messages.AddSucess, Status = APIStatus.Successful });
            }
            catch (Exception ex)
            {
                return Ok(new ResponseModel { Message = ex.Message, Status = APIStatus.SystemError });
            }
        }
    }
}
