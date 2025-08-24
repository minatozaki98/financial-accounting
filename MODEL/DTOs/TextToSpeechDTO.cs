using MODEL.ApplicationConfig;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MODEL.DTOs
{
    public class TextToSpeechDTO
    {
        public string? Title { get; set; }
        public string? Text { get; set; }
        public string? Url { get; set; }
        public string? ObjSegments {  get; set; }
        public string? ObjAlias {  get; set; }
        public string? TextSSML {  get; set; }
        public string? Language { get; set; }
    }

    public class TextSegments
    {
        public string? Text { get; set; }
        public double StartTime { get; set; }
        public double EndTime { get; set; }
        public double Confidence { get; set; }
    }
    public class TextAlias
    {
        public string? TextToMap { get; set; }
        public string? Alias { get; set; }

    }

    public class ResponseHistoryDTO:Common
    {
        public Guid TextToSpeechID { get; set; }
        public string? Title { get; set; }
        public string? Text { get; set; }
        public string? Url { get; set; }
        public string? Language { get; set; }
        public List<TextSegments>? SegmentList { get; set; }
        public List<TextAlias>? AliasList { get; set; }
    }

    public class DetailedResultDTO
    {
        public List<NBestResultDTO> NBest { get; set; }
    }

    public class NBestResultDTO
    {
        public List<WordInfoDTO> Words { get; set; }
    }

    public class WordInfoDTO
    {
        public string Word { get; set; }
        public long Offset { get; set; }
        public long Duration { get; set; }
        public double Confidence { get; set; }
    }

    public class SpeechRecognitionResultDTO
    {
        public string Id { get; set; } 
        public string RecognitionStatus { get; set; } 
        public string DisplayText { get; set; } 
        public long Offset { get; set; } 
        public long Duration { get; set; } 
        public int Channel { get; set; }
    }
}
