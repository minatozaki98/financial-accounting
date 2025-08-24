using API.Helpers;
using Asp.Versioning;
using BAL.IServices;
using Microsoft.AspNetCore.Mvc;
using MODEL.ApplicationConfig;
using MODEL.DTOs;
using MODEL.Entities;
using REPOSITORY.UnitOfWork;
using System.Net;

namespace API.Controllers
{
    [Produces("application/json")]
    [ApiController]
    [Route("api/v{version:apiVersion}/[controller]")]
    [ApiVersion("1")]
    public class AuthenticationController : ControllerBase
    {
        private readonly IUnitOfWork _unitOfWork;
        private readonly IAuthenticationService _authenticationService;
        private readonly ILogService _logService;
        public AuthenticationController(IUnitOfWork unitOfWork, IAuthenticationService authenticationService,ILogService logService)
        {
           _unitOfWork = unitOfWork ?? throw new ArgumentNullException(nameof(unitOfWork));
            _authenticationService = authenticationService ?? throw new ArgumentNullException(nameof(authenticationService));
            _logService = logService ?? throw new ArgumentNullException(nameof(logService));
        }
        [HttpPost("Login")]
        public async Task<ActionResult<string>> Login(UserLoginDTO request)
        {
            try
            {
                var user = await GetUserByEmail(request.Email);

                if (user == null)
                {
                    return BadRequest(new { msg = "Wrong username or password", StatusCode = 404 });
                }

                if (!await VerifyPassword(request.Password, user))
                {
                    return BadRequest(new { msg = "Wrong username or password", StatusCode = 404 });
                }

                var userRole = await GetUserRole(user);

                if (userRole != null)
                {
                    string token = GenerateToken(user, userRole.RoleName);
                    //string token = GenerateToken(user, "Admin");
                    return Ok(new { token = token });
                }

                return BadRequest(new { msg = "user not found", StatusCode = 404 });
            }
            catch (Exception ex)
            {
                var ipAddress = HttpContext?.Connection?.RemoteIpAddress?.ToString();

                //AppLogDTO appLog = new AppLogDTO
                //{
                //    UserId = 0,
                //    UserName = "-",
                //    IP = ipAddress,
                //    Description = "Failed to login to customer web.",
                //    LogType = "Critical",
                //    MethodName = "Login",
                //    Exception = ex.Message,
                //    LogTrace = ex.StackTrace!,
                //    CorrectionId = 101,
                //    CompanyId = 0,
                //    ApplicationName = "API",
                //};
                //await _appLogService.AddAppLog(appLog);
                return BadRequest(new { ErrMessage = ex.Message.ToString(), Status = 200 });
            }
        }


        [HttpPost("LoginWeb")]
        public async Task<IActionResult> LoginWeb(UserLoginDTO request)
        {
            try
            {
                var returndata = await _authenticationService.LoginWeb(request);
                if (!returndata.EmailStatus)
                {
                    return Ok(new ResponseModel { Message = "Your email is invalid!", Status = APIStatus.Error });
                }else if (!returndata.PasswordStatus)
                {
                    return Ok(new ResponseModel { Message = "Your password is invalid!", Status = APIStatus.Error });
                }
                return Ok(new ResponseModel { Message = Messages.Successfully, Status = APIStatus.Successful, Data = returndata });
            }
            catch (Exception ex)
            {
                return Ok(new ResponseModel { Message = ex.Message, Status = APIStatus.SystemError });
            }
        }

        private async Task<Users> GetUserByEmail(string email)
        {
            var userData = await _unitOfWork.Users.GetByCondition(u => u.Email == email);

            var user = userData.FirstOrDefault();

            if (user != null)
            {
                return user;
            }
            else
            {
                var errors = new Dictionary<string, string>
                {
                    { "error", $"No user was found with the specified username or email"}
                };
                throw new ArgumentException();
            }
        }

        private static async Task<bool> VerifyPassword(string password, Users user)
        {
            return await Task.Run(() => Authentication.VerifyPasswordHash(password, user.PasswordHash, user.PasswordSalt));
        }
        private static string GenerateToken(Users user, string roleName)
        {
            return TokenGenerator.GenerateToken(user, roleName);
        }
        private async Task<Role> GetUserRole(Users user)
        {
            var role = await _unitOfWork.Role.GetByCondition(x => x.RoleId == user.RoleId);

            if (role != null)
            {
                return role.First();
            }
            else
            {
                throw new InvalidOperationException("No role was found with the specified user");
            }
        }

        [HttpPost("UploadImage")]
        public async Task<ActionResult> UploadImage(IFormFile image)
        {
            try
            {
                if (image == null || image.Length == 0) // check if file is empty
                {
                    return BadRequest("Please provide a valid image file");
                }

                // check if file size is greater than 2MB
                //if (image.Length > 2 * 1024 * 1024) 
                //{
                //    return BadRequest("File size should be equal or smaller than 2MB");
                //}

                // Check if the file is a PNG or JPEG image
                if (image.ContentType != "image/png" && image.ContentType != "image/jpeg")
                {
                    return BadRequest("Only PNG and JPEG images are allowed");
                }

                var imageUrl = await ImageHandler.UploadImage(image);

                if (imageUrl == null)
                {
                    return BadRequest("Error uploading image.");
                }

                return Ok(new { image = imageUrl });
            }
            catch (Exception ex)
            {
                var ipAddress = HttpContext?.Connection?.RemoteIpAddress?.ToString();

                AddLogDTO appLog = new AddLogDTO
                {
                    UserId = 0,
                    UserName = "-",
                    IP = ipAddress,
                    Description = "Failed to upload image photo.",
                    LogType = "Critical",
                    MethodName = "UploadImage",
                    Exception = ex.Message,
                    LogTrace = ex.StackTrace!,
                };
                await _logService.AddLog(appLog);
                return Ok(new { ErrMessage = ex.Message.ToString(), Status = 200 });
            }
        }

        [HttpPost("UploadFile")]
        public async Task<ActionResult> UploadFile(IFormFile file)
        {
            try
            {
                if (file == null || file.Length == 0) // check if file is empty
                {
                    return BadRequest("Please provide a valid image file");
                }

                // check if file size is greater than 2MB
                //if (image.Length > 2 * 1024 * 1024) 
                //{
                //    return BadRequest("File size should be equal or smaller than 2MB");
                //}

                // Check if the file is a PNG or JPEG image
                //if (file.ContentType != "image/png" && file.ContentType != "image/jpeg")
                //{
                //    return BadRequest("Only PNG and JPEG images are allowed");
                //}

                var imageUrl = await ImageHandler.UploadFile(file);

                if (imageUrl == null)
                {
                    return BadRequest("Error uploading image.");
                }
                return Ok(new { file = imageUrl });
            }
            catch (Exception ex)
            {
                var ipAddress = HttpContext?.Connection?.RemoteIpAddress?.ToString();

                AddLogDTO appLog = new AddLogDTO
                {
                    UserId = 0,
                    UserName = "-",
                    IP = ipAddress,
                    Description = "Failed to upload image photo.",
                    LogType = "Critical",
                    MethodName = "UploadImage",
                    Exception = ex.Message,
                    LogTrace = ex.StackTrace!
                };
                await _logService.AddLog(appLog);
                return Ok(new { ErrMessage = ex.Message.ToString(), Status = 200 });
            }
        }


    }
}
