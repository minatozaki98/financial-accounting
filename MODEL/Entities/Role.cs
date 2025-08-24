using MODEL.ApplicationConfig;
using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MODEL.Entities
{
    public class Role :Common
    {
        [Key]
        public Guid RoleId { get; set; }
        public string RoleName { get; set; } = null!;
    }
}
