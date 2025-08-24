using MODEL.ApplicationConfig;
using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MODEL.Entities
{
    public class Quotation : Common
    {
        [Key]
        public int ID { get; set; }
        public string? Code { get; set; }
        public decimal? Grandtotal { get; set; }
        public decimal? Subtotal { get; set; }
        public string? Customer { get; set; }
        public string? Seller { get; set; }
        public decimal? Vatamount { get; set; }
    }
}
