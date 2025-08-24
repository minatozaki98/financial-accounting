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
    internal class LexiconService:ILexiconService
    {
        private readonly IUnitOfWork _unitOfWork;
        private readonly IMapper _mapper;
        public LexiconService(IUnitOfWork unitOfWork, IMapper mapper)
        {
            _unitOfWork = unitOfWork ?? throw new ArgumentNullException(nameof(unitOfWork));
            _mapper = mapper ?? throw new ArgumentNullException(nameof(mapper));
        }
        public async Task AddLexicon(AddLexiconDTO inputModel)
        {
            try
            {
                var addLexicon = _mapper.Map<Lexicon>(inputModel);
                await _unitOfWork.Lexicon.Add(addLexicon);
                await _unitOfWork.SaveChangesAsync();
            }
            catch (Exception)
            {
                throw;
            }
        }
        public async Task UpdateLexicon(UpdateLexiconDTO inputModel)
        {
            try
            {
                var lexicondata =(await _unitOfWork.Lexicon.GetByCondition(x=>x.LexiconID == inputModel.LexiconID)).FirstOrDefault();
                if (lexicondata != null) {
                    lexicondata.LexiconName = inputModel.LexiconName;
                    lexicondata.UpdatedAt = DateTime.UtcNow;
                    lexicondata.LexiconRewrite = inputModel.LexiconRewrite;
                    lexicondata.Language = inputModel.Language;
                    _unitOfWork.Lexicon.Update(lexicondata);
                    await _unitOfWork.SaveChangesAsync();
                }
               
            }
            catch (Exception)
            {
                throw;
            }
        }
    }
}
