using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using System.Text.RegularExpressions;
using LoopWorth.Application.DTOs;
using LoopWorth.Infrastructure.Identity;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.IdentityModel.Tokens;

namespace LoopWorth.Api.Controllers;

[ApiController]
[Route("api/auth")]
public class AuthController : ControllerBase
{
    private readonly UserManager<ApplicationUser> _userManager;
    private readonly SignInManager<ApplicationUser> _signInManager;
    private readonly IConfiguration _config;

    public AuthController(UserManager<ApplicationUser> userManager, SignInManager<ApplicationUser> signInManager, IConfiguration config)
    {
        _userManager = userManager;
        _signInManager = signInManager;
        _config = config;
    }

    [HttpPost("register")]
    public async Task<IActionResult> Register([FromBody] RegisterDto dto)
    {
        try
        {
            if (string.IsNullOrWhiteSpace(dto.Email) || string.IsNullOrWhiteSpace(dto.Password) || string.IsNullOrWhiteSpace(dto.Name))
                return BadRequest(new { error = "Name, email, and password are required." });

            if (!Regex.IsMatch(dto.Email.Trim(), @"^[^@\s]+@[^@\s]+\.[^@\s]+$"))
                return BadRequest(new { error = "Please provide a valid email address." });

            if (dto.Password.Length < 8 || !dto.Password.Any(char.IsUpper) || !dto.Password.Any(char.IsDigit))
            {
                return BadRequest(new { error = "Password must be at least 8 characters long and contain at least one uppercase letter (A-Z) and one number (0-9)." });
            }

            if (string.IsNullOrWhiteSpace(dto.Phone) || string.IsNullOrWhiteSpace(dto.Address) || 
                string.IsNullOrWhiteSpace(dto.District) || string.IsNullOrWhiteSpace(dto.Town))
            {
                return BadRequest(new { error = "Phone number, address, district, and town are required for collection logistics." });
            }

            var cleanPhone = Regex.Replace(dto.Phone.Trim(), @"[\s\-()]", "");
            if (cleanPhone.StartsWith("+94"))
            {
                cleanPhone = "0" + cleanPhone.Substring(3);
            }
            if (!Regex.IsMatch(cleanPhone, @"^[0-9]{10}$"))
            {
                return BadRequest(new { error = "Phone number must be exactly 10 digits (e.g. 0771234567)." });
            }

            var existing = await _userManager.FindByEmailAsync(dto.Email.Trim());
            if (existing != null)
                return Conflict(new { error = "An account with this email already exists." });

            var user = new ApplicationUser
            {
                UserName = dto.Email.Trim(),
                Email = dto.Email.Trim(),
                FullName = dto.Name.Trim(),
                PhoneNumber = cleanPhone,
                Address = dto.Address.Trim(),
                District = dto.District.Trim(),
                Town = dto.Town.Trim(),
                EmailConfirmed = true
            };

            var result = await _userManager.CreateAsync(user, dto.Password);
            if (!result.Succeeded)
                return BadRequest(new { error = string.Join(", ", result.Errors.Select(e => e.Description)) });

            // Customer only registration
            await _userManager.AddToRoleAsync(user, "Customer");

            var token = await GenerateToken(user);
            return Ok(new AuthResponseDto
            {
                Token = token,
                UserId = user.Id,
                Name = user.FullName ?? user.UserName ?? user.Email ?? "User",
                Email = user.Email!,
                Role = "Customer",
                Phone = user.PhoneNumber,
                Address = user.Address,
                District = user.District,
                Town = user.Town
            });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = "Registration failed: " + ex.Message });
        }
    }

    [HttpPost("login")]
    public async Task<IActionResult> Login([FromBody] LoginDto dto)
    {
        try
        {
            if (string.IsNullOrWhiteSpace(dto.Email) || string.IsNullOrWhiteSpace(dto.Password))
                return BadRequest(new { error = "Email and password are required." });

            var email = dto.Email.Trim();
            var user = await _userManager.FindByEmailAsync(email);
            if (user == null)
                return Unauthorized(new { error = "Invalid email or password." });

            var signInResult = await _signInManager.CheckPasswordSignInAsync(user, dto.Password, false);
            if (!signInResult.Succeeded)
                return Unauthorized(new { error = "Invalid email or password." });

            var roles = await _userManager.GetRolesAsync(user);
            var role = roles.FirstOrDefault() ?? "Customer";
            var token = await GenerateToken(user);

            return Ok(new AuthResponseDto
            {
                Token = token,
                UserId = user.Id,
                Name = user.FullName ?? user.UserName ?? user.Email ?? "User",
                Email = user.Email!,
                Role = role,
                Phone = user.PhoneNumber,
                Address = user.Address,
                District = user.District,
                Town = user.Town
            });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = "Login failed: " + ex.Message });
        }
    }

    [Authorize]
    [HttpGet("me")]
    public async Task<IActionResult> Me()
    {
        var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (userId == null) return Unauthorized();

        var user = await _userManager.FindByIdAsync(userId);
        if (user == null) return NotFound();

        var roles = await _userManager.GetRolesAsync(user);
        return Ok(new UserProfileDto
        {
            UserId = user.Id,
            Name = user.FullName,
            Email = user.Email!,
            Role = roles.FirstOrDefault() ?? "Customer",
            Phone = user.PhoneNumber,
            Address = user.Address,
            District = user.District,
            Town = user.Town
        });
    }

    [Authorize]
    [HttpPut("profile")]
    [HttpPut("me")]
    public async Task<IActionResult> UpdateProfile([FromBody] UpdateUserProfileDto dto)
    {
        var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (userId == null) return Unauthorized();

        var user = await _userManager.FindByIdAsync(userId);
        if (user == null) return NotFound(new { error = "User not found." });

        if (!string.IsNullOrWhiteSpace(dto.Name))
        {
            user.FullName = dto.Name.Trim();
        }

        if (dto.Phone != null)
        {
            var cleanPhone = Regex.Replace(dto.Phone.Trim(), @"[\s\-()]", "");
            if (cleanPhone.StartsWith("+94"))
            {
                cleanPhone = "0" + cleanPhone.Substring(3);
            }
            if (!string.IsNullOrWhiteSpace(cleanPhone) && !Regex.IsMatch(cleanPhone, @"^[0-9]{10}$"))
            {
                return BadRequest(new { error = "Phone number must be exactly 10 digits (e.g. 0771234567)." });
            }
            user.PhoneNumber = cleanPhone;
        }

        if (dto.Address != null)
        {
            user.Address = dto.Address.Trim();
        }

        if (dto.District != null)
        {
            user.District = dto.District.Trim();
        }

        if (dto.Town != null)
        {
            user.Town = dto.Town.Trim();
        }

        var result = await _userManager.UpdateAsync(user);
        if (!result.Succeeded)
        {
            var errors = string.Join(", ", result.Errors.Select(e => e.Description));
            return BadRequest(new { error = errors });
        }

        var roles = await _userManager.GetRolesAsync(user);
        return Ok(new UserProfileDto
        {
            UserId = user.Id,
            Name = user.FullName,
            Email = user.Email!,
            Role = roles.FirstOrDefault() ?? "Customer",
            Phone = user.PhoneNumber,
            Address = user.Address,
            District = user.District,
            Town = user.Town
        });
    }

    private async Task<string> GenerateToken(ApplicationUser user)
    {
        var roles = await _userManager.GetRolesAsync(user);
        var claims = new List<Claim>
        {
            new(ClaimTypes.NameIdentifier, user.Id),
            new(ClaimTypes.Email, user.Email ?? ""),
            new(ClaimTypes.Name, user.FullName ?? user.UserName ?? user.Email ?? "User"),
        };
        foreach (var role in roles)
            claims.Add(new Claim(ClaimTypes.Role, role));

        var secret = _config["JwtSettings:Secret"]
            ?? _config["JWT_SECRET"]
            ?? Environment.GetEnvironmentVariable("JWT_SECRET")
            ?? "DevOnly-LoopWorth-Secret-Key-Minimum-32-Characters-Long!";

        var issuer = _config["JwtSettings:Issuer"]
            ?? _config["JWT_ISSUER"]
            ?? Environment.GetEnvironmentVariable("JWT_ISSUER")
            ?? "LoopWorth";

        var audience = _config["JwtSettings:Audience"]
            ?? _config["JWT_AUDIENCE"]
            ?? Environment.GetEnvironmentVariable("JWT_AUDIENCE")
            ?? "LoopWorth";

        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(secret));
        var creds = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

        var token = new JwtSecurityToken(
            issuer: issuer,
            audience: audience,
            claims: claims,
            expires: DateTime.UtcNow.AddDays(7),
            signingCredentials: creds
        );

        return new JwtSecurityTokenHandler().WriteToken(token);
    }
}
