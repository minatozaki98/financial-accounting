using System.ComponentModel.DataAnnotations;

namespace MODEL.Entities
{
    public class FinancialRole
    {
        [Key]
        public int RoleId { get; set; }
        public string RoleName { get; set; } = null!;
        public string? Description { get; set; }

        public ICollection<UserRole> UserRoles { get; set; } = new List<UserRole>();
    }
}
