using BAL.IServices;
using BAL.Shared;
using Microsoft.EntityFrameworkCore;
using MODEL;
using MODEL.DTOs;
using MODEL.Entities;

namespace BAL.Services
{
    internal class FinancialAuthService : IFinancialAuthService
    {
        private readonly DataContext _context;
        private readonly FinancialTokenProvider _tokenProvider;
        private readonly IAuditLogService _auditLogService;

        public FinancialAuthService(DataContext context, FinancialTokenProvider tokenProvider, IAuditLogService auditLogService)
        {
            _context = context;
            _tokenProvider = tokenProvider;
            _auditLogService = auditLogService;
        }

        public async Task<FinancialTokenResponseDto?> LoginAsync(FinancialLoginRequestDto request, string? ipAddress)
        {
            var username = request.Username.Trim();
            var user = await _context.Users
                .FirstOrDefaultAsync(x =>
                    x.IsActive &&
                    x.ActiveFlag &&
                    (
                        x.Username == username ||
                        x.Email == username));

            if (user == null)
            {
                return null;
            }

            if (!CommonAuthentication.VerifyPasswordHash(request.Password, user.PasswordHash, user.PasswordSalt))
            {
                return null;
            }

            var roles = await EnsureAndGetRolesAsync(user);
            var accessToken = _tokenProvider.CreateAccessToken(user, roles);

            await _auditLogService.WriteAsync(
                user.UserId,
                "LOGIN",
                "Users",
                user.UserId.ToString(),
                ipAddress,
                new { user.Username, user.Email });

            return new FinancialTokenResponseDto
            {
                AccessToken = accessToken.Token,
                AccessTokenExpiresAtUtc = accessToken.ExpiresAtUtc,
                Roles = roles
            };
        }

        public async Task<CurrentUserResponseDto?> GetCurrentUserAsync(Guid userId)
        {
            var user = await _context.Users
                .AsNoTracking()
                .FirstOrDefaultAsync(x => x.UserId == userId && x.IsActive && x.ActiveFlag);

            if (user == null)
            {
                return null;
            }

            var roles = await GetRolesAsync(userId);
            if (roles.Count == 0)
            {
                // Requery the tracked user and materialize default role mapping if needed.
                var trackedUser = await _context.Users.FirstAsync(x => x.UserId == userId);
                roles = await EnsureAndGetRolesAsync(trackedUser);
            }

            return new CurrentUserResponseDto
            {
                UserId = user.UserId,
                Username = user.Username,
                Email = user.Email,
                IsActive = user.IsActive,
                Roles = roles
            };
        }

        public async Task<CreatedUserResponseDto> CreateUserAsync(CreateUserRequestDto request, Guid actorUserId, string? ipAddress)
        {
            var username = request.Username.Trim();
            var email = request.Email.Trim();
            var roleName = request.Role.Trim();

            if (string.IsNullOrWhiteSpace(username))
            {
                throw new InvalidOperationException("Username is required.");
            }

            if (string.IsNullOrWhiteSpace(email))
            {
                throw new InvalidOperationException("Email is required.");
            }

            if (string.IsNullOrWhiteSpace(request.Password))
            {
                throw new InvalidOperationException("Password is required.");
            }

            if (string.IsNullOrWhiteSpace(roleName))
            {
                throw new InvalidOperationException("Role is required.");
            }

            if (await _context.Users.AnyAsync(x => x.Username == username))
            {
                throw new InvalidOperationException($"Username '{username}' already exists.");
            }

            if (await _context.Users.AnyAsync(x => x.Email == email))
            {
                throw new InvalidOperationException($"Email '{email}' already exists.");
            }

            var role = await _context.FinancialRoles
                .AsNoTracking()
                .FirstOrDefaultAsync(x => x.RoleName.ToLower() == roleName.ToLower());
            if (role == null)
            {
                throw new InvalidOperationException($"Role '{roleName}' is invalid.");
            }

            CommonAuthentication.CreatePasswordHash(request.Password, out var passwordHash, out var passwordSalt);
            var now = DateTime.UtcNow;

            var user = new Users
            {
                UserId = Guid.NewGuid(),
                Username = username,
                Email = email,
                IsActive = true,
                RoleId = null,
                PasswordHash = passwordHash,
                PasswordSalt = passwordSalt,
                FullName = username,
                DisplayName = username,
                PhoneNumber = string.Empty,
                ProfileUrl = string.Empty,
                LastAcvite = null,
                CreatedBy = actorUserId.ToString(),
                UpdatedBy = actorUserId.ToString(),
                CreatedAt = now,
                UpdatedAt = now,
                ActiveFlag = true
            };

            await _context.Users.AddAsync(user);
            await _context.UserRoles.AddAsync(new UserRole
            {
                UserId = user.UserId,
                RoleId = role.RoleId
            });
            await _context.SaveChangesAsync();

            await _auditLogService.WriteAsync(
                actorUserId,
                "CREATE_USER",
                "Users",
                user.UserId.ToString(),
                ipAddress,
                new { user.Username, user.Email, Role = role.RoleName });

            return new CreatedUserResponseDto
            {
                UserId = user.UserId,
                Username = user.Username,
                Email = user.Email,
                Role = role.RoleName,
                IsActive = user.IsActive
            };
        }

        private async Task<List<string>> EnsureAndGetRolesAsync(Users user)
        {
            var roles = await GetRolesAsync(user.UserId);
            if (roles.Count > 0)
            {
                return roles;
            }

            var roleName = "User";
            if (user.RoleId.HasValue)
            {
                var legacyRole = await _context.Role.AsNoTracking().FirstOrDefaultAsync(x => x.RoleId == user.RoleId.Value);
                if (legacyRole != null && !string.IsNullOrWhiteSpace(legacyRole.RoleName))
                {
                    roleName = legacyRole.RoleName;
                }
            }

            var financialRoles = await _context.FinancialRoles.ToListAsync();
            if (financialRoles.Count == 0)
            {
                throw new InvalidOperationException("No financial roles are configured.");
            }

            var role = financialRoles.FirstOrDefault(x => string.Equals(x.RoleName, roleName, StringComparison.OrdinalIgnoreCase))
                ?? financialRoles.First(x => x.RoleName == "User");

            await _context.UserRoles.AddAsync(new UserRole
            {
                UserId = user.UserId,
                RoleId = role.RoleId
            });
            await _context.SaveChangesAsync();

            return new List<string> { role.RoleName };
        }

        private Task<List<string>> GetRolesAsync(Guid userId)
        {
            return _context.UserRoles
                .Where(ur => ur.UserId == userId)
                .Join(_context.FinancialRoles, ur => ur.RoleId, r => r.RoleId, (_, r) => r.RoleName)
                .Distinct()
                .ToListAsync();
        }
    }
}
