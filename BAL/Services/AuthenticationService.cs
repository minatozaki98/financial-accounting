using BAL.IServices;
using BAL.Shared;
using MODEL.DTOs;
using MODEL.Entities;
using REPOSITORY.UnitOfWork;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using System.Threading.Tasks;

namespace BAL.Services
{
    internal class AuthenticationService:IAuthenticationService
    {
        private readonly IUnitOfWork _unitOfWork;
        public AuthenticationService(IUnitOfWork unitOfWork) {
            _unitOfWork = unitOfWork;
        }

        public async Task<ResponseUserLoginDTO> LoginWeb(UserLoginDTO loginDTO)
        {
            try
            {
                var returndata = new ResponseUserLoginDTO();
                var userdata = (await _unitOfWork.Users.GetByCondition(x => x.Email == loginDTO.Email && x.ActiveFlag)).FirstOrDefault();
                if (userdata == null)
                {
                    returndata.EmailStatus = false;
                    return returndata;
                }
                else
                {
                    var roledata = (await _unitOfWork.Role.GetByCondition(x => x.RoleId == userdata.RoleId)).FirstOrDefault();
                    returndata.EmailStatus = true;
                    var checkpassword = CommonAuthentication.VerifyPasswordHash(loginDTO.Password, userdata.PasswordHash, userdata.PasswordSalt);
                    if (checkpassword && roledata != null)
                    {
                        returndata.PasswordStatus = true;
                        returndata.Token = CommonTokenGenerator.GenerateToken(userdata, roledata.RoleName);
                        returndata.Email = userdata.Email;
                        returndata.FullName = userdata.FullName;
                        returndata.RoleName = roledata.RoleName;
                        returndata.DisplayName = userdata.DisplayName;
                        returndata.RoleId = userdata.RoleId;
                        returndata.UserId = userdata.UserId;
                        returndata.PhoneNumber = userdata.PhoneNumber;
                        returndata.ProfileUrl = userdata.ProfileUrl;
                        returndata.LastActive = userdata.LastAcvite;
                        returndata.CreatedAt = userdata.CreatedAt;
                        returndata.UpdatedAt = userdata.UpdatedAt;
                        return returndata;
                    }
                    else
                    {
                        returndata.PasswordStatus = false;
                        return returndata;
                    }

                }
            }
            catch (Exception)
            {

                throw;
            }
        }

    }
}
