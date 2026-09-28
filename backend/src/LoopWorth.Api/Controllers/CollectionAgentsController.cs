using System.Text.RegularExpressions;
using LoopWorth.Application.DTOs;
using LoopWorth.Domain.Entities;
using LoopWorth.Domain.Enums;
using LoopWorth.Infrastructure.Data;
using LoopWorth.Infrastructure.Identity;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace LoopWorth.Api.Controllers;

[ApiController]
[Route("api/admin/collection-agents")]
[Authorize(Roles = "Admin")]
public class CollectionAgentsController : ControllerBase
{
    private readonly AppDbContext _context;
    private readonly UserManager<ApplicationUser> _userManager;

    public CollectionAgentsController(AppDbContext context, UserManager<ApplicationUser> userManager)
    {
        _context = context;
        _userManager = userManager;
    }

    // GET /api/admin/collection-agents
    [HttpGet]
    public async Task<IActionResult> GetAll()
    {
        var profiles = await _context.CollectionAgentProfiles
            .OrderBy(p => p.CreatedAt)
            .ToListAsync();

        var inProgressStatuses = new[] { CollectionStatus.Scheduled, CollectionStatus.Collected };
        var busyAgentUserIds = await _context.CollectionRequests
            .Where(c => c.AssignedCollectionAgentId != null && inProgressStatuses.Contains(c.Status))
            .Select(c => c.AssignedCollectionAgentId!)
            .Distinct()
            .ToListAsync();

        var dtos = new List<CollectionAgentDto>();
        bool changedAny = false;
        foreach (var p in profiles)
        {
            var user = await _userManager.FindByIdAsync(p.UserId);
            if (user != null)
            {
                var dynamicAvailable = !busyAgentUserIds.Contains(p.UserId);
                if (p.IsAvailable != dynamicAvailable)
                {
                    p.IsAvailable = dynamicAvailable;
                    p.UpdatedAt = DateTime.UtcNow;
                    changedAny = true;
                }

                dtos.Add(new CollectionAgentDto
                {
                    ProfileId = p.Id,
                    UserId = p.UserId,
                    Name = user.Name,
                    Email = user.Email ?? string.Empty,
                    Phone = p.Phone ?? user.PhoneNumber,
                    ServiceArea = p.ServiceArea,
                    TownArea = p.TownArea,
                    IsAvailable = dynamicAvailable,
                    IsActive = p.IsActive
                });
            }
        }

        if (changedAny)
        {
            await _context.SaveChangesAsync();
        }

        return Ok(dtos);
    }

    // GET /api/admin/collection-agents/{id}
    [HttpGet("{id:guid}")]
    public async Task<IActionResult> GetById(Guid id)
    {
        var profile = await _context.CollectionAgentProfiles.FindAsync(id);
        if (profile == null) return NotFound(new { error = "Collection agent profile not found." });

        var user = await _userManager.FindByIdAsync(profile.UserId);
        if (user == null) return NotFound(new { error = "Associated user not found." });

        var inProgressStatuses = new[] { CollectionStatus.Scheduled, CollectionStatus.Collected };
        var hasActiveJobs = await _context.CollectionRequests
            .AnyAsync(c => c.AssignedCollectionAgentId == profile.UserId && inProgressStatuses.Contains(c.Status));

        var dynamicAvailable = !hasActiveJobs;
        if (profile.IsAvailable != dynamicAvailable)
        {
            profile.IsAvailable = dynamicAvailable;
            profile.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync();
        }

        return Ok(new CollectionAgentDto
        {
            ProfileId = profile.Id,
            UserId = profile.UserId,
            Name = user.Name,
            Email = user.Email ?? string.Empty,
            Phone = profile.Phone ?? user.PhoneNumber,
            ServiceArea = profile.ServiceArea,
            TownArea = profile.TownArea,
            IsAvailable = dynamicAvailable,
            IsActive = profile.IsActive
        });
    }

    // POST /api/admin/collection-agents
    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CreateCollectionAgentDto dto)
    {
        if (string.IsNullOrWhiteSpace(dto.Name))
            return BadRequest(new { error = "Agent Name is required." });

        if (string.IsNullOrWhiteSpace(dto.Email))
            return BadRequest(new { error = "Email address is required." });

        if (!Regex.IsMatch(dto.Email.Trim(), @"^[^@\s]+@[^@\s]+\.[^@\s]+$"))
            return BadRequest(new { error = "Please provide a valid email address." });

        if (string.IsNullOrWhiteSpace(dto.Password) || dto.Password.Length < 8 ||
            !dto.Password.Any(char.IsUpper) || !dto.Password.Any(char.IsDigit))
        {
            return BadRequest(new { error = "Password must be at least 8 characters long, containing at least one uppercase letter and numbers." });
        }

        if (string.IsNullOrWhiteSpace(dto.Phone))
            return BadRequest(new { error = "Phone number is required." });

        var cleanPhone = Regex.Replace(dto.Phone.Trim(), @"[\s\-()]", "");
        if (cleanPhone.StartsWith("+94"))
        {
            cleanPhone = "0" + cleanPhone.Substring(3);
        }
        if (!Regex.IsMatch(cleanPhone, @"^[0-9]{10}$"))
            return BadRequest(new { error = "Phone number must be exactly 10 digits (e.g. 0771234567)." });

        if (string.IsNullOrWhiteSpace(dto.ServiceArea))
            return BadRequest(new { error = "Service Territory / District is required." });

        if (string.IsNullOrWhiteSpace(dto.TownArea))
            return BadRequest(new { error = "Town Area / Vicinity is required." });

        var existingUser = await _userManager.FindByEmailAsync(dto.Email.Trim());
        if (existingUser != null)
        {
            return Conflict(new { error = "A user with this email already exists." });
        }

        var user = new ApplicationUser
        {
            UserName = dto.Email.Trim(),
            Email = dto.Email.Trim(),
            FullName = dto.Name.Trim(),
            PhoneNumber = cleanPhone,
            EmailConfirmed = true
        };

        var result = await _userManager.CreateAsync(user, dto.Password);
        if (!result.Succeeded)
        {
            return BadRequest(new { errors = result.Errors.Select(e => e.Description) });
        }

        await _userManager.AddToRoleAsync(user, "CollectionAgent");

        var profile = new CollectionAgentProfile
        {
            UserId = user.Id,
            Phone = cleanPhone,
            ServiceArea = dto.ServiceArea.Trim(),
            TownArea = dto.TownArea.Trim(),
            IsAvailable = true,
            IsActive = true
        };

        _context.CollectionAgentProfiles.Add(profile);
        await _context.SaveChangesAsync();

        var agentDto = new CollectionAgentDto
        {
            ProfileId = profile.Id,
            UserId = user.Id,
            Name = user.Name,
            Email = user.Email,
            Phone = profile.Phone,
            ServiceArea = profile.ServiceArea,
            TownArea = profile.TownArea,
            IsAvailable = profile.IsAvailable,
            IsActive = profile.IsActive
        };

        return CreatedAtAction(nameof(GetById), new { id = profile.Id }, agentDto);
    }

    // PUT /api/admin/collection-agents/{id}
    [HttpPut("{id:guid}")]
    public async Task<IActionResult> Update(Guid id, [FromBody] UpdateCollectionAgentDto dto)
    {
        if (string.IsNullOrWhiteSpace(dto.Phone))
            return BadRequest(new { error = "Phone number is required." });

        var cleanPhone = Regex.Replace(dto.Phone.Trim(), @"[\s\-()]", "");
        if (cleanPhone.StartsWith("+94"))
        {
            cleanPhone = "0" + cleanPhone.Substring(3);
        }
        if (!Regex.IsMatch(cleanPhone, @"^[0-9]{10}$"))
            return BadRequest(new { error = "Phone number must be exactly 10 digits (e.g. 0771234567)." });

        if (string.IsNullOrWhiteSpace(dto.ServiceArea))
            return BadRequest(new { error = "Service Territory / District is required." });

        if (string.IsNullOrWhiteSpace(dto.TownArea))
            return BadRequest(new { error = "Town Area / Vicinity is required." });

        var profile = await _context.CollectionAgentProfiles.FindAsync(id);
        if (profile == null) return NotFound(new { error = "Collection agent profile not found." });

        var inProgressStatuses = new[] { CollectionStatus.Scheduled, CollectionStatus.Collected };
        var hasActiveJobs = await _context.CollectionRequests
            .AnyAsync(c => c.AssignedCollectionAgentId == profile.UserId && inProgressStatuses.Contains(c.Status));

        profile.Phone = cleanPhone;
        profile.ServiceArea = dto.ServiceArea.Trim();
        profile.TownArea = dto.TownArea.Trim();
        // Automated availability based on active collection jobs: Busy when on active pickup, Available when idle
        profile.IsAvailable = !hasActiveJobs;
        profile.IsActive = dto.IsActive;
        profile.UpdatedAt = DateTime.UtcNow;

        await _context.SaveChangesAsync();

        var user = await _userManager.FindByIdAsync(profile.UserId);

        return Ok(new CollectionAgentDto
        {
            ProfileId = profile.Id,
            UserId = profile.UserId,
            Name = user?.Name ?? string.Empty,
            Email = user?.Email ?? string.Empty,
            Phone = profile.Phone,
            ServiceArea = profile.ServiceArea,
            TownArea = profile.TownArea,
            IsAvailable = profile.IsAvailable,
            IsActive = profile.IsActive
        });
    }

    // DELETE /api/admin/collection-agents/{id}
    [HttpDelete("{id:guid}")]
    public async Task<IActionResult> Delete(Guid id)
    {
        var profile = await _context.CollectionAgentProfiles.FindAsync(id);
        if (profile == null) return NotFound(new { error = "Collection agent profile not found." });

        var inProgressStatuses = new[] { CollectionStatus.Scheduled, CollectionStatus.Collected };
        var hasActiveJobs = await _context.CollectionRequests
            .AnyAsync(c => c.AssignedCollectionAgentId == profile.UserId && inProgressStatuses.Contains(c.Status));

        if (hasActiveJobs)
        {
            return BadRequest(new { error = "Cannot delete agent while they have active collection jobs in progress (Scheduled or Collected). Please complete or reassign those jobs first." });
        }

        // Unassign any pending unaccepted assignments
        var pendingAssignedRequests = await _context.CollectionRequests
            .Where(c => c.AssignedCollectionAgentId == profile.UserId && c.Status == CollectionStatus.AgentAssigned)
            .ToListAsync();

        foreach (var req in pendingAssignedRequests)
        {
            req.Status = CollectionStatus.Requested;
            req.AssignedCollectionAgentId = null;
            req.UpdatedAt = DateTime.UtcNow;
        }

        var userId = profile.UserId;

        // Remove profile
        _context.CollectionAgentProfiles.Remove(profile);
        await _context.SaveChangesAsync();

        // Delete user account
        var user = await _userManager.FindByIdAsync(userId);
        if (user != null)
        {
            await _userManager.DeleteAsync(user);
        }

        return Ok(new { message = "Collection agent deleted successfully." });
    }
}
