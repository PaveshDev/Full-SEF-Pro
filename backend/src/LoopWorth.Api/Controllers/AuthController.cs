using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
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
        if (string.IsNullOrWhiteSpace(dto.Email) || string.IsNullOrWhiteSpace(dto.Password) || string.IsNullOrWhiteSpace(dto.Name))
            return BadRequest(new { error = "Name, email, and password are required." });

        if (dto.Password.Length < 8 || !dto.Password.Any(char.IsUpper) || !dto.Password.Any(char.IsDigit))
        {
            return BadRequest(new { error = "Password must be at least 8 characters long and contain at least one uppercase letter (A-Z) and one number (0-9)." });
        }

        if (string.IsNullOrWhiteSpace(dto.Phone) || string.IsNullOrWhiteSpace(dto.Address) || 
            string.IsNullOrWhiteSpace(dto.District) || string.IsNullOrWhiteSpace(dto.Town))
        {
            return BadRequest(new { error = "Phone number, address, district, and town are required for collection logistics." });
        }

        var existing = await _userManager.FindByEmailAsync(dto.Email);
        if (existing != null)
            return Conflict(new { error = "An account with this email already exists." });

        var user = new ApplicationUser
        {
            UserName = dto.Email,
            Email = dto.Email,
            FullName = dto.Name,
            PhoneNumber = dto.Phone.Trim(),
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
            Name = user.FullName,
            Email = user.Email!,
            Role = "Customer",
            Phone = user.PhoneNumber,
            Address = user.Address,
            District = user.District,
            Town = user.Town
        });
    }

    [HttpPost("login")]
    public async Task<IActionResult> Login([FromBody] LoginDto dto)
    {
        if (string.IsNullOrWhiteSpace(dto.Email) || string.IsNullOrWhiteSpace(dto.Password))
            return BadRequest(new { error = "Email and password are required." });

        var user = await _userManager.FindByEmailAsync(dto.Email);
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
            Name = user.FullName,
            Email = user.Email!,
            Role = role,
            Phone = user.PhoneNumber,
            Address = user.Address,
            District = user.District,
            Town = user.Town
        });
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
            user.PhoneNumber = dto.Phone.Trim();
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
            new(ClaimTypes.Email, user.Email!),
            new(ClaimTypes.Name, user.FullName),
        };
        foreach (var role in roles)
            claims.Add(new Claim(ClaimTypes.Role, role));

        var secret = _config["JwtSettings:Secret"]!;
        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(secret));
        var creds = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

        var token = new JwtSecurityToken(
            issuer: _config["JwtSettings:Issuer"],
            audience: _config["JwtSettings:Audience"],
            claims: claims,
            expires: DateTime.UtcNow.AddDays(7),
            signingCredentials: creds
        );

        return new JwtSecurityTokenHandler().WriteToken(token);
    }
}
