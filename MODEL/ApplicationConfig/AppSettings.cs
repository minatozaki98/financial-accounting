using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MODEL.ApplicationConfig
{
    public class AppSettings
    {
        public string? ConnectionStrings { get; set; }
        public string? LocalTestUrl { get; set; }
        public string JwtSecret { get; set; } = "MFwwDQYJKoZIhvcNAQEBBQADSwAwSAJBAL0zIKgOk+azCEuVZvrvtkgjRk3VcSq4 kDzbi51WD2xCUGNafzI8cmoY9KqFh7s1V7C6nw3/QbzvTytwYR/c5Q0CAwEAAQ==";
        public string JwtIssuer { get; set; } = "Allianz_DEV";
        public string JwtAudience { get; set; } = "Allianz_DEV";
        public int AccessTokenMinutes { get; set; } = 60;
    }
}
