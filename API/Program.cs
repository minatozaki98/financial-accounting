using Asp.Versioning;
using BAL.Shared;
using Microsoft.Net.Http.Headers;
using MODEL.ApplicationConfig;
using Microsoft.IdentityModel.Tokens;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using System.Text;
using Microsoft.OpenApi.Models;
using Swashbuckle.AspNetCore.Filters;
using MODEL;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);
var appSettings = new AppSettings();
// Add services to the container.

builder.Services.AddControllers();
builder.Configuration.GetSection("AppSettings").Bind(appSettings);
builder.Services.Configure<AppSettings>(builder.Configuration.GetSection("AppSettings"));
ServiceManager.SetServiceInfo(builder.Services, appSettings);
// Learn more about configuring Swagger/OpenAPI at https://aka.ms/aspnetcore/swashbuckle
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

builder.Services.AddAutoMapper(typeof(Program).Assembly);
builder.Services.AddCors(options =>
{
    options.AddPolicy("MyAllowSpecificOrigins",
        builder => builder.WithMethods("GET", "POST", "PATCH", "DELETE", "OPTIONS")
        .WithHeaders(
        HeaderNames.Accept,
        HeaderNames.ContentType,
        HeaderNames.Authorization)
        .SetIsOriginAllowed(origin => true)
        .AllowCredentials());
});
//builder.Services.AddCors(options =>
//{
//    options.AddPolicy(name: "dev", policy =>
//    {
//        policy.WithOrigins(builder.Configuration["AppSettings:LocalTestUrl"])
//            .AllowAnyHeader()
//            .AllowAnyMethod()
//            .AllowCredentials()
//            .SetIsOriginAllowed((hosts) => true);
//    });

//});
//DB
//builder.Services.AddDbContextPool<DataContext>(options =>
//    options.UseSqlServer(builder.Configuration["AppSettings:ConnectionStrings"]));


builder.Services.AddApiVersioning(options =>
{
    options.DefaultApiVersion = new Asp.Versioning.ApiVersion(1);
    options.AssumeDefaultVersionWhenUnspecified = true;
    options.ReportApiVersions = true;
    options.ApiVersionReader = ApiVersionReader.Combine(
        new UrlSegmentApiVersionReader(),
        new HeaderApiVersionReader("X-Api-Version")
    );
}).AddApiExplorer(options =>
{
    options.GroupNameFormat = "'v'VVV";
    options.SubstituteApiVersionInUrl = true;
});

builder.Services.AddAuthentication(options =>
{
    options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
    options.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
    options.DefaultScheme = JwtBearerDefaults.AuthenticationScheme;
})
   .AddJwtBearer(options =>
   {
       options.SaveToken = true;
       options.RequireHttpsMetadata = !builder.Environment.IsDevelopment();
       options.RequireHttpsMetadata = true;
       options.TokenValidationParameters = new()
       {
           ValidateIssuerSigningKey = true,
           IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes("MFwwDQYJKoZIhvcNAQEBBQADSwAwSAJBAL0zIKgOk+azCEuVZvrvtkgjRk3VcSq4 kDzbi51WD2xCUGNafzI8cmoY9KqFh7s1V7C6nw3/QbzvTytwYR/c5Q0CAwEAAQ==")),
           ValidateLifetime = true,
           ValidateIssuer = true,
           ValidateAudience = true,
           ValidIssuer = "Allianz_DEV",
           ValidAudience = "Allianz_DEV"
       };
   });


// Add Swagger Authorization
builder.Services.AddSwaggerGen(options =>
{
    options.SwaggerDoc("v1", new OpenApiInfo { Title = "Your API", Version = "v1" });
    options.AddSecurityDefinition("oauth2", new OpenApiSecurityScheme
    {
        Description = "JWT Authorization header using the Bearer scheme",
        Name = "Authorization",
        In = ParameterLocation.Header,
        Type = SecuritySchemeType.ApiKey
    });
    options.OperationFilter<SecurityRequirementsOperationFilter>();
});

// HTTP ONlY COOKIE
builder.Services.ConfigureApplicationCookie(options =>
{
    options.Cookie.HttpOnly = false;
    options.Cookie.SecurePolicy = CookieSecurePolicy.Always;
});
var app = builder.Build();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}
app.UseSwagger();
app.UseSwaggerUI();
app.UseHttpsRedirection();
app.UseCors("MyAllowSpecificOrigins");
app.UseAuthorization();
app.UseCookiePolicy(new CookiePolicyOptions
{
    Secure = CookieSecurePolicy.Always,
    MinimumSameSitePolicy = Microsoft.AspNetCore.Http.SameSiteMode.None
});
app.MapControllers();

app.Run();
