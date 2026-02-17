using System.ComponentModel.DataAnnotations;

namespace MODEL.Entities
{
    public class Currency
    {
        [Key]
        [MaxLength(10)]
        public string CurrencyCode { get; set; } = null!;
        public string Name { get; set; } = null!;
        public string Symbol { get; set; } = null!;
    }
}
