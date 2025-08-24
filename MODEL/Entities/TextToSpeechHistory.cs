using MODEL.ApplicationConfig;
using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MODEL.Entities
{
    public class TextToSpeechHistory:Common
    {
        [Key]
        public Guid TextToSpeechID { get; set; }
        public string? Title {  get; set; }
        public string? Text {  get; set; }
        public string? Url {  get; set; }
        public string? ObjSegments {  get; set; }
        public string? ObjAlias {  get; set; }
        public string? TextSSML {  get; set; }
        public string? Language {  get; set; }
    }
}
