using MODEL.ApplicationConfig;
using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MODEL.Entities
{
    public class Todo:Common
    {
        [Key]
        public Guid ID { get; set; }
        public string? Title { get; set; }
        public string? Description { get; set; }
        public string? Status {  get; set; }

    }
}
