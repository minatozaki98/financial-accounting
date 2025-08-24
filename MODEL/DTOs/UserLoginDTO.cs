using MODEL.ApplicationConfig;
using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MODEL.DTOs
{
    public class UserLoginDTO
    {
        [Required(AllowEmptyStrings = false)]
        public string Email { get; set; } = null!;

        [Required(AllowEmptyStrings = false)]
        public string Password { get; set; } = null!;
    }
    public class ResponseUserLoginDTO:Common
    {
        public Guid UserId { get; set; }
        public Guid? RoleId { get; set; }
        public string? Email {  get; set; }
        public string? FullName {  get; set; }
        public string? DisplayName {  get; set; }
        public string? PhoneNumber {  get; set; }
        public string? ProfileUrl {  get; set; }
        public DateTime? LastActive { get; set; }
        public string? RoleName {  get; set; }
        public bool PasswordStatus {  get; set; }
        public bool EmailStatus {  get; set; }
        public string? Token {  get; set; }
    }
}
