using System.Security.Claims;

namespace API.Helpers
{
    public static class UserClaimsHelper
    {
        public static Guid? GetUserId(ClaimsPrincipal user)
        {
            var claimValue = user.FindFirstValue(ClaimTypes.NameIdentifier);
            if (Guid.TryParse(claimValue, out var userId))
            {
                return userId;
            }

            return null;
        }
    }
}
