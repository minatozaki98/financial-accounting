using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MODEL.DTOs
{
    public class AddTodoDTO
    {
        public string? Title { get; set; }
        public string? Description { get; set; }
        public string? Status {  get; set; }
    }
    public class UpdateTodoDTO
    {
        public Guid ID { get; set; }
        public string? Title { get; set; }
        public string? Description { get; set; }
        public string? Status { get; set; }
    }
}
