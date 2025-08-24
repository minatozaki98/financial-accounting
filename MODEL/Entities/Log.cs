using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MODEL.Entities
{
    public class Log
    {
        [Key]
        public int LogId {  get; set; }
        public string? UserName {  get; set; }
        public int UserId {  get; set; }
        public string? IP {  get; set; }
        public string? LaptopModel {  get; set; }
        public string? Description {  get; set; }
        public string? LogType {  get; set; }
        public string? MethodName {  get; set; }
        public string? Exception {  get; set; }
        public string? LogTrace {  get; set; }
        public DateTime CreateDate { get; set; }= DateTime.UtcNow;
        public bool ActiveFlag { get; set; } = true;
    }
}
