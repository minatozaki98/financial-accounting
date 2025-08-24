using MODEL.DTOs;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace BAL.IServices
{
    public interface ITextToSpeechService
    {
        Task<Guid> AddTextToSpeech(TextToSpeechDTO inputModel);

        Task UpdateTextToSpeech(ResponseHistoryDTO inputModel);

    }
}
