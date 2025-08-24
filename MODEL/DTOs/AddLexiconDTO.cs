using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MODEL.DTOs
{
    public class AddLexiconDTO
    {
        public string? LexiconName {  get; set; }
        public string? LexiconRewrite {  get; set; }
        public string? Language {  get; set; }
    }
    public class UpdateLexiconDTO
    {
        public Guid LexiconID { get; set; }
        public string? LexiconName { get; set; }
        public string? LexiconRewrite { get; set; }
        public string? Language {  get; set; }
    }
}
