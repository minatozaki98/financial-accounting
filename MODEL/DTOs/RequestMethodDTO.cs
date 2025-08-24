using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MODEL.DTOs
{
    public class RequestMethodDTO
    {
        public string? RequestMessage { get; set; }
        public string? Languagedata { get; set; }
        public string? LanguageSecond { get; set; }
        public string? Gender { get; set; }
        public string? Title { get; set; }
        public List<AliasDTO>? ListAlias { get; set; }

    }

    public class AliasDTO
    {
        public string? TextToMap { get; set; }
        public string? Alias { get; set; }
    }

    public class RequestMethodSpeechToTextDTO
    {
        public Microsoft.AspNetCore.Http.IFormFile AudioFile { get; set; }  // This will hold the uploaded audio or image file
        public string? Languagedata { get; set; }  // This is the language data for recognition
        public string? Title { get; set; }  // This is the title of the recognition task
    }


}
