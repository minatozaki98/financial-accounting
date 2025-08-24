using MODEL.DTOs;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace BAL.IServices
{
    public interface IAuthenticationService
    {
        Task<ResponseUserLoginDTO> LoginWeb(UserLoginDTO loginDTO);
    }
}
