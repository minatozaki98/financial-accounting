namespace MODEL.ApplicationConfig
{
    public class AppSettings
    {
        public string? ConnectionStrings { get; set; }
        public string? LocalTestUrl { get; set; }
        public string[] AllowedOrigins { get; set; } = System.Array.Empty<string>();
        public bool EnableSwaggerInProduction { get; set; }
        public bool EnableSwaggerUi { get; set; }
        public string JwtSecret { get; set; } = "MFwwDQYJKoZIhvcNAQEBBQADSwAwSAJBAL0zIKgOk+azCEuVZvrvtkgjRk3VcSq4 kDzbi51WD2xCUGNafzI8cmoY9KqFh7s1V7C6nw3/QbzvTytwYR/c5Q0CAwEAAQ==";
        public string JwtIssuer { get; set; } = "Allianz_DEV";
        public string JwtAudience { get; set; } = "Allianz_DEV";
        public int AccessTokenMinutes { get; set; } = 60;
        public SecurityHeadersOptions SecurityHeaders { get; set; } = new SecurityHeadersOptions();
        public PerformanceGatesOptions PerformanceGates { get; set; } = new PerformanceGatesOptions();
    }

    public class SecurityHeadersOptions
    {
        public bool Enabled { get; set; } = true;
        public string ContentSecurityPolicy { get; set; } = "default-src 'self'; frame-ancestors 'none'; base-uri 'self'; object-src 'none';";
        public string SwaggerContentSecurityPolicy { get; set; } = "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self' data:; connect-src 'self'; frame-ancestors 'none'; base-uri 'self'; object-src 'none'; form-action 'self';";
        public string XFrameOptions { get; set; } = "DENY";
        public string XContentTypeOptions { get; set; } = "nosniff";
        public string PermissionsPolicy { get; set; } = "camera=(), microphone=(), geolocation=()";
        public string CrossOriginOpenerPolicy { get; set; } = "same-origin";
        public string CrossOriginEmbedderPolicy { get; set; } = "require-corp";
        public string CrossOriginResourcePolicy { get; set; } = "same-origin";
    }

    public class PerformanceGatesOptions
    {
        public PerformanceProfileGate Profile50 { get; set; } = new PerformanceProfileGate
        {
            MaxErrorPct = 0.5,
            MaxP95Ms = 300
        };

        public PerformanceProfileGate Profile100 { get; set; } = new PerformanceProfileGate
        {
            MaxErrorPct = 1.0,
            MaxP95Ms = 500
        };

        public PerformanceProfileGate Profile500 { get; set; } = new PerformanceProfileGate
        {
            MaxErrorPct = 2.0,
            MaxP95Ms = 1200
        };

        public double SoakMaxErrorPct { get; set; } = 1.0;
        public double SoakMaxP95DriftPct { get; set; } = 20.0;
        public int SpikeRecoveryMinutes { get; set; } = 10;
    }

    public class PerformanceProfileGate
    {
        public double MaxErrorPct { get; set; }
        public double MaxP95Ms { get; set; }
    }
}
