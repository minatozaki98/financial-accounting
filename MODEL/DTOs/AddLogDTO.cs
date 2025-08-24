using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MODEL.DTOs
{
    public class AddLogDTO
    {
        public string? UserName { get; set; }
        public int UserId { get; set; }
        public string? IP { get; set; }
        public string? LaptopModel { get; set; }
        public string? Description { get; set; }
        public string? LogType { get; set; }
        public string? MethodName { get; set; }
        public string? Exception { get; set; }
        public string? LogTrace { get; set; }
    }
}
