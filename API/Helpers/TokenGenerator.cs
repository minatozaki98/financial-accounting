using Microsoft.IdentityModel.Tokens;
using MODEL.Entities;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;

namespace API.Helpers
{
    public class TokenGenerator
    {
        //private const string VaultUrl = "";
        //private static readonly SecretClient Client = new(new Uri(VaultUrl), new DefaultAzureCredential());

        //private const string SecretKeyName = "JWT--SecretKey--DotNet8";
        //private static readonly KeyVaultSecret SecretKey = Client.GetSecret(SecretKeyName).Value;

        //private const string IssuerName = "JWT--Issuer";
        //private static readonly KeyVaultSecret Issuer = Client.GetSecret(IssuerName).Value;
        private static readonly string Issuer = "Allianz_DEV";

        //private const string AudienceName = "JWT--Audience";
        //private static readonly KeyVaultSecret Audience = Client.GetSecret(AudienceName).Value;
        private static readonly string Audience = "Allianz_DEV";

        //private static readonly SymmetricSecurityKey Key = new(Encoding.UTF8.GetBytes(SecretKey.Value));


        private static readonly SymmetricSecurityKey Key = new(Encoding.UTF8.GetBytes("MFwwDQYJKoZIhvcNAQEBBQADSwAwSAJBAL0zIKgOk+azCEuVZvrvtkgjRk3VcSq4 kDzbi51WD2xCUGNafzI8cmoY9KqFh7s1V7C6nw3/QbzvTytwYR/c5Q0CAwEAAQ=="));
        private static readonly SigningCredentials Credientials = new(Key, SecurityAlgorithms.HmacSha512Signature);

        public static string GenerateToken(Users user, string role)
        {
            List<Claim> claims = new()
            {
                new Claim(ClaimTypes.NameIdentifier, user.UserId.ToString()),
                new Claim(ClaimTypes.Name, user.Email),
                new Claim(ClaimTypes.Role, role)
            };

            var token = new JwtSecurityToken(
                //issuer: Issuer.Value,
                //audience: Audience.Value,
                issuer: Issuer,
                audience: Audience,
                claims: claims,
                expires: DateTime.UtcNow.AddDays(3),
            signingCredentials: Credientials
            );

            return new JwtSecurityTokenHandler().WriteToken(token);
        }

        public static string GeneratePasswordResetTokenForUser(Users user)
        {

            List<Claim> claims = new()
            {
                new Claim(ClaimTypes.NameIdentifier, user.UserId.ToString()),
                new Claim(ClaimTypes.Name, user.Email)
            };

            var token = new JwtSecurityToken(
                //issuer: Issuer.Value,
                //audience: Audience.Value,
                issuer: Issuer,
                audience: Audience,
                claims: claims,
                expires: DateTime.UtcNow.AddMinutes(30),
                signingCredentials: Credientials
            );

            return new JwtSecurityTokenHandler().WriteToken(token);

        }

        public static async Task<bool> CheckTokenIsValid(string token)
        {
            var tokenHandler = new JwtSecurityTokenHandler();
            var validationParameters = new TokenValidationParameters
            {
                ValidateIssuer = true,
                ValidateAudience = true,
                ValidateIssuerSigningKey = true,
                //ValidIssuer = Issuer.Value,
                //ValidAudience = Audience.Value,
                ValidIssuer = Issuer,
                ValidAudience = Audience,
                IssuerSigningKey = Key
            };

            try
            {
                var principal = tokenHandler.ValidateToken(token, validationParameters, out var validatedToken);

                if (validatedToken is JwtSecurityToken jwtSecurityToken && jwtSecurityToken.ValidTo < DateTime.UtcNow)
                {
                    return false; // Token is expired
                }

                return true; // Token is valid
            }
            catch (Exception)
            {
                return false; // Token validation failed
            }
        }




    }
}
