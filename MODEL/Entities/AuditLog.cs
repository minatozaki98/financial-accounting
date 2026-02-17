using System.ComponentModel.DataAnnotations;

namespace MODEL.Entities
{
    public class AuditLog
    {
        [Key]
        public long AuditLogId { get; set; }
        public Guid? UserId { get; set; }
        public string Action { get; set; } = null!;
        public string? EntityName { get; set; }
        public string? EntityId { get; set; }
        public DateTime Timestamp { get; set; } = DateTime.UtcNow;
        public string? IpAddress { get; set; }
        public string? DetailsJson { get; set; }

        public Users? User { get; set; }
    }
}
