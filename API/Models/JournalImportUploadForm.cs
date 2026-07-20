using System.ComponentModel.DataAnnotations;

namespace API.Models
{
    public sealed class JournalImportUploadForm
    {
        [Required]
        public IFormFile File { get; set; } = null!;

        [Required]
        [StringLength(100, MinimumLength = 8)]
        public string IdempotencyKey { get; set; } = string.Empty;

        public bool Atomic { get; set; } = true;
    }
}
