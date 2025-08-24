using AutoMapper;
using BAL.IServices;
using MODEL.DTOs;
using MODEL.Entities;
using REPOSITORY.UnitOfWork;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;

namespace BAL.Services
{
    internal class TextToSpeechService:ITextToSpeechService
    {
        private readonly IUnitOfWork _unitOfWork;
        private readonly IMapper _mapper;
        public TextToSpeechService(IUnitOfWork unitOfWork, IMapper mapper) {
            _unitOfWork = unitOfWork;
            _mapper = mapper;
        }
        public async Task<Guid> AddTextToSpeech(TextToSpeechDTO inputModel)
        {
            try
            {
                var addtextdata = _mapper.Map<TextToSpeechHistory>(inputModel);
                await _unitOfWork.TextToSpeechHistory.Add(addtextdata);
                await _unitOfWork.SaveChangesAsync();
                return addtextdata.TextToSpeechID;
            }
            catch (Exception ex)
            {

                throw;
            }
        }
        static readonly JsonSerializerOptions _options = new()
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
            WriteIndented = true,
        };

        public async Task UpdateTextToSpeech(ResponseHistoryDTO inputModel)
        {
            try
            {
                var speechdata = (await _unitOfWork.TextToSpeechHistory.GetByCondition(x=>x.TextToSpeechID == inputModel.TextToSpeechID)).FirstOrDefault();
              
                if (speechdata != null) { 
                    speechdata.UpdatedAt = DateTime.UtcNow;
                    speechdata.Title = inputModel.Title;
                    speechdata.Text = inputModel.Text;
                    speechdata.Url = inputModel.Url;
                    speechdata.Language = inputModel.Language;
                    if(inputModel.SegmentList?.Count != 0)
                    {
                        var ByteTextSegments = JsonSerializer.SerializeToUtf8Bytes(inputModel.SegmentList, _options);
                        string jsonStringObjSegments = System.Text.Encoding.UTF8.GetString(ByteTextSegments);
                        speechdata.ObjSegments = jsonStringObjSegments;
                    }
                   
                    _unitOfWork.TextToSpeechHistory.Update(speechdata);
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
