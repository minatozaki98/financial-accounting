using AutoMapper;
using BAL.IServices;
using MODEL.DTOs;
using MODEL.Entities;
using REPOSITORY.UnitOfWork;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace BAL.Services
{
    internal class LogService:ILogService
    {
        private readonly IUnitOfWork _unitOfWork;
        private readonly IMapper _mapper;
        public LogService(IUnitOfWork unitOfWork, IMapper mapper) {
            _unitOfWork = unitOfWork ?? throw new ArgumentNullException(nameof(unitOfWork));
            _mapper = mapper ?? throw new ArgumentNullException(nameof(mapper));
        }
        public async Task AddLog(AddLogDTO inputmodel)
        {
            try
            {
                var addlogmapper = _mapper.Map<Log>(inputmodel);
               await _unitOfWork.Log.Add(addlogmapper);
                await _unitOfWork.SaveChangesAsync();
            }
            catch (Exception)
            {

                throw;
            }
        }
    }
}
