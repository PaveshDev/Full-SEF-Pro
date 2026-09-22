using System.Security.Claims;
using LoopWorth.Application.DTOs;
using LoopWorth.Application.Interfaces;
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
[Authorize]
public class PartnersController : ControllerBase
{
    private readonly AppDbContext _context;
    private readonly IPartnerMatchingAgent _partnerAgent;
    private readonly UserManager<ApplicationUser> _userManager;

    public PartnersController(
        AppDbContext context,
        IPartnerMatchingAgent partnerAgent,
        UserManager<ApplicationUser> userManager)
    {
        _context = context;
        _partnerAgent = partnerAgent;
        _userManager = userManager;
    }

    private string GetUserId() => User.FindFirstValue(ClaimTypes.NameIdentifier)!;
    private bool IsAdmin() => User.IsInRole("Admin");

    // GET /api/partners
    [HttpGet("api/partners")]
    public async Task<IActionResult> GetAll(
        [FromQuery] string? route,
        [FromQuery] Guid? categoryId,
        [FromQuery] bool? activeOnly)
    {
        var query = _context.Partners
            .Include(p => p.Services)
            .ThenInclude(s => s.Category)
            .AsQueryable();

        // Default to active only unless admin specifically requests all
        if (!IsAdmin() || (activeOnly.HasValue && activeOnly.Value))
        {
            query = query.Where(p => p.IsActive);
        }

        if (!string.IsNullOrWhiteSpace(route) && Enum.TryParse<RecoveryRoute>(route, true, out var rRoute))
        {
            query = query.Where(p => p.Services.Any(s => s.RecoveryRoute == rRoute));
        }

        if (categoryId.HasValue)
        {
            query = query.Where(p => p.Services.Any(s => s.CategoryId == categoryId.Value));
        }

        var partners = await query.OrderBy(p => p.Name).ToListAsync();
        return Ok(partners.Select(MapToDto));
    }

    // GET /api/partners/{id}
    [HttpGet("api/partners/{id:guid}")]
    public async Task<IActionResult> GetById(Guid id)
    {
        var partner = await _context.Partners
            .Include(p => p.Services)
            .FirstOrDefaultAsync(p => p.Id == id);

        if (partner == null) return NotFound(new { error = "Partner not found." });
        return Ok(MapToDto(partner));
    }

    // POST /api/partners (Admin)
    [HttpPost("api/partners")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> Create([FromBody] CreatePartnerDto dto)
    {
        if (string.IsNullOrWhiteSpace(dto.Name) || string.IsNullOrWhiteSpace(dto.Email))
            return BadRequest(new { error = "Organization Name and Email are required." });

        if (string.IsNullOrWhiteSpace(dto.Password) || dto.Password.Length < 8 ||
            !dto.Password.Any(char.IsUpper) || !dto.Password.Any(char.IsDigit))
        {
            return BadRequest(new { error = "Password must be at least 8 characters long, containing at least one uppercase letter and numbers." });
        }

        if (dto.Services == null || dto.Services.Count == 0)
            return BadRequest(new { error = "Partner organization must support at least one accepted route and category." });

        var existingUser = await _userManager.FindByEmailAsync(dto.Email);
        if (existingUser != null)
        {
            return Conflict(new { error = "A user account with this email already exists." });
        }

        // Create partner user account
        var user = new ApplicationUser
        {
            UserName = dto.Email,
            Email = dto.Email,
            FullName = dto.ContactName,
            PhoneNumber = dto.Phone,
            EmailConfirmed = true
        };

        var userResult = await _userManager.CreateAsync(user, dto.Password);
        if (!userResult.Succeeded)
        {
            return BadRequest(new { errors = userResult.Errors.Select(e => e.Description) });
        }

        await _userManager.AddToRoleAsync(user, "Partner");

        var partner = new Partner
        {
            UserId = user.Id,
            Name = dto.Name,
            ContactName = dto.ContactName,
            Email = dto.Email,
            Phone = dto.Phone,
            ServiceArea = dto.ServiceArea,
            OperatingHours = dto.OperatingHours,
            AverageProcessingDays = 1,
            IsActive = true
        };

        foreach (var s in dto.Services)
        {
            if (Enum.TryParse<RecoveryRoute>(s.RecoveryRoute, true, out var routeVal))
            {
                partner.Services.Add(new PartnerService
                {
                    RecoveryRoute = routeVal,
                    CategoryId = s.CategoryId
                });
            }
        }

        if (partner.Services.Count == 0)
            return BadRequest(new { error = "Partner organization must support at least one accepted route (Donate or Recycle) and category." });

        _context.Partners.Add(partner);
        await _context.SaveChangesAsync();

        return CreatedAtAction(nameof(GetById), new { id = partner.Id }, MapToDto(partner));
    }

    // PUT /api/partners/{id} (Admin)
    [HttpPut("api/partners/{id:guid}")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> Update(Guid id, [FromBody] UpdatePartnerDto dto)
    {
        if (dto.Services == null || dto.Services.Count == 0)
            return BadRequest(new { error = "Partner organization must support at least one accepted route and category. Cannot save without services." });

        var partner = await _context.Partners
            .FirstOrDefaultAsync(p => p.Id == id);

        if (partner == null) return NotFound(new { error = "Partner not found." });

        var newServices = new List<PartnerService>();
        foreach (var s in dto.Services)
        {
            if (Enum.TryParse<RecoveryRoute>(s.RecoveryRoute, true, out var routeVal))
            {
                newServices.Add(new PartnerService
                {
                    Id = Guid.NewGuid(),
                    PartnerId = partner.Id,
                    RecoveryRoute = routeVal,
                    CategoryId = s.CategoryId
                });
            }
        }

        if (newServices.Count == 0)
            return BadRequest(new { error = "Partner organization must support at least one accepted route (Donate or Recycle) and category." });

        partner.Name = dto.Name;
        partner.ContactName = dto.ContactName;
        partner.Email = dto.Email;
        partner.Phone = dto.Phone;
        partner.ServiceArea = dto.ServiceArea;
        partner.OperatingHours = dto.OperatingHours;
        partner.AverageProcessingDays = dto.AverageProcessingDays;
        partner.IsActive = dto.IsActive;
        partner.UpdatedAt = DateTime.UtcNow;

        // Cleanly delete old services directly in DB to prevent EF concurrency tracking conflicts
        await _context.PartnerServices.Where(s => s.PartnerId == partner.Id).ExecuteDeleteAsync();
        await _context.PartnerServices.AddRangeAsync(newServices);
        await _context.SaveChangesAsync();

        var updated = await _context.Partners
            .Include(p => p.Services)
            .FirstOrDefaultAsync(p => p.Id == id);

        return Ok(MapToDto(updated!));
    }

    // DELETE /api/partners/{id} (Admin)
    [HttpDelete("api/partners/{id:guid}")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> Delete(Guid id)
    {
        var partner = await _context.Partners.FindAsync(id);
        if (partner == null) return NotFound(new { error = "Partner not found." });

        var hasReferences = await _context.PartnerMatches.AnyAsync(m => m.PartnerId == id)
            || await _context.PartnerSelections.AnyAsync(s => s.PartnerId == id)
            || await _context.CollectionRequests.AnyAsync(c => c.PartnerId == id);

        if (!hasReferences)
        {
            await _context.PartnerServices.Where(s => s.PartnerId == id).ExecuteDeleteAsync();
            _context.Partners.Remove(partner);
            await _context.SaveChangesAsync();
            return Ok(new { message = "Partner deleted permanently." });
        }

        partner.IsActive = false;
        partner.UpdatedAt = DateTime.UtcNow;
        await _context.SaveChangesAsync();

        return Ok(new { message = "Partner deactivated because historical recovery records reference it." });
    }

    // POST /api/partners/{id}/reactivate (Admin)
    [HttpPost("api/partners/{id:guid}/reactivate")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> Reactivate(Guid id)
    {
        var partner = await _context.Partners.FindAsync(id);
        if (partner == null) return NotFound(new { error = "Partner not found." });

        partner.IsActive = true;
        partner.UpdatedAt = DateTime.UtcNow;
        await _context.SaveChangesAsync();

        return Ok(new { message = "Partner reactivated." });
    }

    // POST /api/recovery/{id}/partners/match (Agent 3)
    [HttpPost("api/recovery/{id:guid}/partners/match")]
    public async Task<IActionResult> MatchPartners(Guid id, CancellationToken ct)
    {
        var userId = GetUserId();
        var recovery = await _context.RecoveryRequests
            .Include(r => r.Item)
            .ThenInclude(i => i.Category)
            .FirstOrDefaultAsync(r => r.Id == id, ct);

        if (recovery == null) return NotFound(new { error = "Recovery request not found." });
        if (recovery.CustomerId != userId && !IsAdmin()) return Forbid();

        if (recovery.Status != RecoveryStatus.Approved)
        {
            return BadRequest(new { error = "Recovery request must be approved by admin before matching partners." });
        }

        // Pre-filter candidate partners deterministically
        var candidatePartners = await _context.Partners
            .Include(p => p.Services)
            .Where(p => p.IsActive && p.Services.Any(s => s.RecoveryRoute == recovery.SelectedRoute && s.CategoryId == recovery.Item.CategoryId))
            .ToListAsync(ct);

        if (candidatePartners.Count == 0)
        {
            // Fallback: active partners that support the selected route
            candidatePartners = await _context.Partners
                .Include(p => p.Services)
                .Where(p => p.IsActive && p.Services.Any(s => s.RecoveryRoute == recovery.SelectedRoute))
                .ToListAsync(ct);
        }

        if (candidatePartners.Count == 0)
        {
            return BadRequest(new { error = "No active partners found for this recovery route and category." });
        }

        var candidateDtos = candidatePartners.Select(p => new PartnerCandidate
        {
            PartnerId = p.Id,
            Name = p.Name,
            SupportedRoute = recovery.SelectedRoute.ToString(),
            Category = recovery.Item.Category.Name,
            ServiceArea = p.ServiceArea,
            AverageProcessingDays = p.AverageProcessingDays
        }).ToList();

        // Track workflow step
        var workflow = await _context.AgentWorkflows
            .FirstOrDefaultAsync(w => w.ItemId == recovery.ItemId, ct);

        var step = new AgentWorkflowStep
        {
            WorkflowId = workflow?.Id ?? Guid.Empty,
            AgentName = "PartnerMatchingAgent",
            StepName = "PartnerRecommendation",
            ExecutionStatus = AgentExecutionStatus.Running,
            InputSummary = $"Matching {candidateDtos.Count} candidates for {recovery.SelectedRoute} ({recovery.Item.Category.Name})",
            StartedAt = DateTime.UtcNow
        };

        if (workflow != null)
        {
            workflow.CurrentStage = "PartnerMatching";
            workflow.UpdatedAt = DateTime.UtcNow;
            _context.AgentWorkflowSteps.Add(step);
            await _context.SaveChangesAsync(ct);
        }

        List<PartnerMatchResult> matchResults;
        try
        {
            matchResults = await _partnerAgent.MatchPartnersAsync(
                recovery.Id,
                recovery.SelectedRoute,
                recovery.Item.Category.Name,
                candidateDtos,
                ct);

            step.ExecutionStatus = AgentExecutionStatus.Succeeded;
            step.OutputSummary = $"Ranked {matchResults.Count} partners successfully.";
            step.CompletedAt = DateTime.UtcNow;
        }
        catch (Exception ex)
        {
            step.ExecutionStatus = AgentExecutionStatus.Failed;
            step.ErrorMessage = ex.Message;
            step.CompletedAt = DateTime.UtcNow;

            // Fallback deterministic ranking if AI fails
            matchResults = candidatePartners
                .OrderBy(p => p.AverageProcessingDays)
                .Select((p, index) => new PartnerMatchResult
                {
                    PartnerId = p.Id,
                    Rank = index + 1,
                    Reason = $"Matched based on service area ({p.ServiceArea}) and turnaround time ({p.AverageProcessingDays} days)."
                }).ToList();
        }

        // Remove old matches for this recovery request
        var existingMatches = await _context.PartnerMatches
            .Where(m => m.RecoveryRequestId == recovery.Id)
            .ToListAsync(ct);
        _context.PartnerMatches.RemoveRange(existingMatches);

        var matchesToSave = matchResults.Select(r => new PartnerMatch
        {
            RecoveryRequestId = recovery.Id,
            PartnerId = r.PartnerId,
            Rank = r.Rank,
            Reason = r.Reason,
            CreatedAt = DateTime.UtcNow
        }).ToList();

        _context.PartnerMatches.AddRange(matchesToSave);
        await _context.SaveChangesAsync(ct);

        // Fetch saved matches with Partner entity details
        var savedDtos = await _context.PartnerMatches
            .Include(m => m.Partner)
            .Where(m => m.RecoveryRequestId == recovery.Id)
            .OrderBy(m => m.Rank)
            .Select(m => new PartnerMatchDto
            {
                Id = m.Id,
                PartnerId = m.PartnerId,
                PartnerName = m.Partner.Name,
                Rank = m.Rank,
                Reason = m.Reason,
                ServiceArea = m.Partner.ServiceArea,
                AverageProcessingDays = m.Partner.AverageProcessingDays
            })
            .ToListAsync(ct);

        return Ok(savedDtos);
    }

    // GET /api/recovery/{id}/partners/matches
    [HttpGet("api/recovery/{id:guid}/partners/matches")]
    public async Task<IActionResult> GetMatches(Guid id)
    {
        var userId = GetUserId();
        var recovery = await _context.RecoveryRequests.FindAsync(id);
        if (recovery == null) return NotFound(new { error = "Recovery request not found." });
        if (recovery.CustomerId != userId && !IsAdmin()) return Forbid();

        var matches = await _context.PartnerMatches
            .Include(m => m.Partner)
            .Where(m => m.RecoveryRequestId == id)
            .OrderBy(m => m.Rank)
            .Select(m => new PartnerMatchDto
            {
                Id = m.Id,
                PartnerId = m.PartnerId,
                PartnerName = m.Partner.Name,
                Rank = m.Rank,
                Reason = m.Reason,
                ServiceArea = m.Partner.ServiceArea,
                AverageProcessingDays = m.Partner.AverageProcessingDays
            })
            .ToListAsync();

        return Ok(matches);
    }

    // POST /api/recovery/{id}/partners/{partnerId}/select
    [HttpPost("api/recovery/{id:guid}/partners/{partnerId:guid}/select")]
    public async Task<IActionResult> SelectPartner(Guid id, Guid partnerId)
    {
        var userId = GetUserId();
        var recovery = await _context.RecoveryRequests.FindAsync(id);
        if (recovery == null) return NotFound(new { error = "Recovery request not found." });
        if (recovery.CustomerId != userId && !IsAdmin()) return Forbid();

        if (recovery.Status != RecoveryStatus.Approved)
        {
            return BadRequest(new { error = "Recovery request must be approved to select a partner." });
        }

        var partner = await _context.Partners.FirstOrDefaultAsync(p => p.Id == partnerId && p.IsActive);
        if (partner == null) return BadRequest(new { error = "Selected partner does not exist or is inactive." });

        var existingSelection = await _context.PartnerSelections
            .FirstOrDefaultAsync(s => s.RecoveryRequestId == id);

        if (existingSelection != null)
        {
            existingSelection.PartnerId = partnerId;
            existingSelection.SelectedAt = DateTime.UtcNow;
        }
        else
        {
            _context.PartnerSelections.Add(new PartnerSelection
            {
                RecoveryRequestId = id,
                PartnerId = partnerId,
                CustomerId = userId,
                SelectedAt = DateTime.UtcNow
            });
        }

        await _context.SaveChangesAsync();

        return Ok(new
        {
            message = "Partner selected successfully.",
            recoveryRequestId = id,
            partnerId = partnerId,
            partnerName = partner.Name
        });
    }

    private static PartnerDto MapToDto(Partner partner) => new()
    {
        Id = partner.Id,
        UserId = partner.UserId,
        Name = partner.Name,
        ContactName = partner.ContactName,
        Email = partner.Email,
        Phone = partner.Phone,
        ServiceArea = partner.ServiceArea,
        OperatingHours = partner.OperatingHours,
        AverageProcessingDays = partner.AverageProcessingDays,
        IsActive = partner.IsActive,
        CreatedAt = partner.CreatedAt,
        Services = partner.Services.Select(s => new PartnerServiceDto
        {
            RecoveryRoute = s.RecoveryRoute.ToString(),
            CategoryId = s.CategoryId
        }).ToList()
    };
}
