using MODEL.ApplicationConfig;
using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MODEL.Entities
{
    public class Lexicon:Common
    {
        [Key]
        public Guid LexiconID { get; set; }
        public string? LexiconName {  get; set; }
        public string? LexiconRewrite {  get; set; }
        public string? Language {  get; set; }
    }
}
