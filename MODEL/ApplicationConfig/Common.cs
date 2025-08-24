using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MODEL.ApplicationConfig
{
    public class Common
    {
        public string CreatedBy { get; set; } = "System";
        public string UpdatedBy { get; set; } = "System";
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
        public DateTime UpdatedAt { get; set;} = DateTime.UtcNow;
        public bool ActiveFlag { get; set; } = true;
    }
}
