using System.ComponentModel.DataAnnotations;

namespace MODEL.Entities
{
    public class UserRole
    {
        [Key]
        public int UserRoleId { get; set; }
        public Guid UserId { get; set; }
        public int RoleId { get; set; }

        public Users User { get; set; } = null!;
        public FinancialRole Role { get; set; } = null!;
    }
}
