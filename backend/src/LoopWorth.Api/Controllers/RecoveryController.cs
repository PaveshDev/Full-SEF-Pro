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
public class RecoveryController : ControllerBase
{
    private readonly AppDbContext _context;
    private readonly IRecoveryPlanningAgent _planAgent;
    private readonly UserManager<ApplicationUser> _userManager;

    public RecoveryController(
        AppDbContext context,
        IRecoveryPlanningAgent planAgent,
        UserManager<ApplicationUser> userManager)
    {
        _context = context;
        _planAgent = planAgent;
        _userManager = userManager;
    }

    private string GetUserId() => User.FindFirstValue(ClaimTypes.NameIdentifier)!;

    [HttpPost("api/recovery")]
    public async Task<IActionResult> Create([FromBody] CreateRecoveryDto dto)
    {
        var userId = GetUserId();
        var item = await _context.Items.Include(i => i.Category).FirstOrDefaultAsync(i => i.Id == dto.ItemId);
        if (item == null) return NotFound(new { error = "Item not found." });
        if (item.CustomerId != userId) return Forbid();
        if (item.Status != ItemStatus.Assessed)
            return BadRequest(new { error = "Item must be assessed first." });
        if (!item.SelectedRecoveryRoute.HasValue)
            return BadRequest(new { error = "Recovery route must be selected first." });

        // Check for existing active recovery
        var existing = await _context.RecoveryRequests
            .AnyAsync(r => r.ItemId == dto.ItemId && r.Status != RecoveryStatus.Rejected);
        if (existing)
            return Conflict(new { error = "An active recovery request already exists for this item." });

        var recovery = new RecoveryRequest
        {
            ItemId = dto.ItemId,
            CustomerId = userId,
            SelectedRoute = item.SelectedRecoveryRoute.Value,
            Status = RecoveryStatus.Draft
        };
        _context.RecoveryRequests.Add(recovery);
        await _context.SaveChangesAsync();

        return CreatedAtAction(nameof(GetById), new { id = recovery.Id }, MapToDto(recovery, item));
    }

    [HttpGet("api/recovery")]
    public async Task<IActionResult> GetAll([FromQuery] string? status)
    {
        var userId = GetUserId();
        var query = _context.RecoveryRequests
            .Include(r => r.Item).ThenInclude(i => i.Category)
            .Include(r => r.Item).ThenInclude(i => i.Images)
            .Include(r => r.Plan).ThenInclude(p => p!.Steps)
            .Include(r => r.Plan).ThenInclude(p => p!.SafetyNotes)
            .Where(r => r.CustomerId == userId);

        if (!string.IsNullOrWhiteSpace(status) && Enum.TryParse<RecoveryStatus>(status, true, out var s))
            query = query.Where(r => r.Status == s);

        var results = await query.OrderByDescending(r => r.CreatedAt).ToListAsync();
        return Ok(results.Select(r => MapToDto(r, r.Item)));
    }

    [HttpGet("api/recovery/{id}")]
    public async Task<IActionResult> GetById(Guid id)
    {
        var userId = GetUserId();
        var recovery = await GetRecoveryWithIncludes(id);
        if (recovery == null) return NotFound();
        if (recovery.CustomerId != userId && !User.IsInRole("Admin")) return Forbid();
        return Ok(MapToDto(recovery, recovery.Item));
    }

    // GET /api/recovery/{id}/handover-pass
    [HttpGet("api/recovery/{id:guid}/handover-pass")]
    [AllowAnonymous]
    public async Task<IActionResult> GetHandoverPass(Guid id, CancellationToken ct)
    {
        var recovery = await _context.RecoveryRequests
            .Include(r => r.Item).ThenInclude(i => i.Category)
            .Include(r => r.Item).ThenInclude(i => i.Images)
            .Include(r => r.Plan).ThenInclude(p => p!.Steps)
            .Include(r => r.Plan).ThenInclude(p => p!.SafetyNotes)
            .Include(r => r.ApprovalDecisions)
            .FirstOrDefaultAsync(r => r.Id == id, ct);

        if (recovery == null) return NotFound(new { error = "Recovery request not found." });

        var customer = await _userManager.FindByIdAsync(recovery.CustomerId);

        // Fetch associated collection request if one exists
        var collection = await _context.CollectionRequests
            .Include(c => c.Partner)
            .FirstOrDefaultAsync(c => c.RecoveryRequestId == id, ct);

        string? assignedAgentName = null;
        if (!string.IsNullOrEmpty(collection?.AssignedCollectionAgentId))
        {
            var agentUser = await _userManager.FindByIdAsync(collection.AssignedCollectionAgentId);
            assignedAgentName = agentUser?.Name ?? agentUser?.FullName;
        }

        var latestDecision = recovery.ApprovalDecisions
            .OrderByDescending(d => d.DecidedAt)
            .FirstOrDefault();

        var primaryImage = recovery.Item.Images.OrderBy(img => img.SortOrder).FirstOrDefault()?.ImageUrl;

        var pass = new HandoverPassDto
        {
            RecoveryRequestId = recovery.Id,
            PassReferenceCode = $"LPW-PASS-{recovery.Id.ToString()[..8].ToUpper()}",
            ItemId = recovery.ItemId,
            ItemName = recovery.Item.Name,
            CategoryName = recovery.Item.Category?.Name ?? "General E-Waste",
            Brand = recovery.Item.Brand,
            Model = recovery.Item.Model,
            ConditionDescription = recovery.Item.ConditionDescription,
            PrimaryImageUrl = primaryImage,
            SelectedRoute = recovery.SelectedRoute.ToString(),
            Status = recovery.Status.ToString(),

            CustomerName = customer?.FullName ?? customer?.Name ?? "Customer",
            CustomerPhone = customer?.PhoneNumber,
            CustomerAddress = customer?.Address,
            CustomerDistrict = customer?.District,
            CustomerTown = customer?.Town,

            PlanSummary = recovery.Plan?.Summary,
            RequiredPartnerType = recovery.Plan?.RequiredPartnerType,
            PreparationSteps = recovery.Plan?.Steps.OrderBy(s => s.SortOrder).Select(s => s.StepText).ToList() ?? new List<string>(),
            SafetyNotes = recovery.Plan?.SafetyNotes.OrderBy(s => s.SortOrder).Select(s => s.NoteText).ToList() ?? new List<string>(),

            IsApproved = recovery.Status == RecoveryStatus.Approved,
            ApprovedAt = latestDecision?.DecidedAt,
            AdminNote = latestDecision?.Reason,

            CollectionRequestId = collection?.Id,
            CollectionStatus = collection?.Status.ToString(),
            AssignedAgentId = collection?.AssignedCollectionAgentId,
            AssignedAgentName = assignedAgentName,
            PartnerName = collection?.Partner?.Name,
            ScheduledPickupDate = collection?.ScheduledPickupDate,
            ScheduledStartTime = collection?.ScheduledStartTime,
            ScheduledEndTime = collection?.ScheduledEndTime
        };

        return Ok(pass);
    }

    [HttpPost("api/recovery/{id}/plan")]
    [HttpPost("api/recovery/{id}/generate-plan")]
    public async Task<IActionResult> GeneratePlan(Guid id)
    {
        var userId = GetUserId();
        var recovery = await _context.RecoveryRequests
            .Include(r => r.Item).ThenInclude(i => i.Category)
            .Include(r => r.Item).ThenInclude(i => i.Images)
            .FirstOrDefaultAsync(r => r.Id == id);
        if (recovery == null) return NotFound();
        if (recovery.CustomerId != userId && !User.IsInRole("Admin")) return Forbid();
        if (recovery.Status != RecoveryStatus.Draft && recovery.Status != RecoveryStatus.PlanGenerated && recovery.Status != RecoveryStatus.RevisionRequested)
            return BadRequest(new { error = "Plan can only be generated for draft, revision, or pending plans." });

        var assessment = await _context.ItemAssessments
            .Where(a => a.ItemId == recovery.ItemId && a.ExecutionStatus == AgentExecutionStatus.Succeeded)
            .OrderByDescending(a => a.CreatedAt)
            .FirstOrDefaultAsync()
            ?? await _context.ItemAssessments
                .Where(a => a.ItemId == recovery.ItemId)
                .OrderByDescending(a => a.CreatedAt)
                .FirstOrDefaultAsync();

        if (assessment == null)
        {
            assessment = new ItemAssessment
            {
                ItemId = recovery.ItemId,
                ConditionLevel = ConditionLevel.Fair,
                RecommendedRoute = recovery.SelectedRoute,
                ConfidenceLevel = ConfidenceLevel.High,
                Explanation = "Initial evaluation based on item profile.",
                ExecutionStatus = AgentExecutionStatus.Succeeded
            };
            _context.ItemAssessments.Add(assessment);
            await _context.SaveChangesAsync();
        }

        // Update workflow
        var workflow = await _context.AgentWorkflows.FirstOrDefaultAsync(w => w.ItemId == recovery.ItemId && w.Status != "Failed");
        if (workflow != null)
        {
            workflow.CurrentStage = "RecoveryPlanning";
            workflow.Status = "Running";
            workflow.UpdatedAt = DateTime.UtcNow;
        }

        var step = new AgentWorkflowStep
        {
            WorkflowId = workflow?.Id ?? Guid.Empty,
            AgentName = "RecoveryPlanningAgent",
            StepName = "GeneratePlan",
            ExecutionStatus = AgentExecutionStatus.Running,
            InputSummary = $"Item: {recovery.Item.Name}, Route: {recovery.SelectedRoute}",
            StartedAt = DateTime.UtcNow
        };
        if (workflow != null) _context.AgentWorkflowSteps.Add(step);
        await _context.SaveChangesAsync();

        try
        {
            var result = await _planAgent.GeneratePlanAsync(recovery.Item, assessment, recovery.SelectedRoute);

            // Remove old plan if exists
            var oldPlan = await _context.RecoveryPlans
                .Include(p => p.Steps).Include(p => p.SafetyNotes)
                .FirstOrDefaultAsync(p => p.RecoveryRequestId == recovery.Id);
            if (oldPlan != null) _context.RecoveryPlans.Remove(oldPlan);

            var plan = new RecoveryPlan
            {
                RecoveryRequestId = recovery.Id,
                Suitability = result.Suitability,
                Summary = result.Summary,
                RequiredPartnerType = result.RequiredPartnerType,
                Steps = result.PreparationSteps.Select((s, i) => new RecoveryPlanStep
                {
                    StepText = s, SortOrder = i
                }).ToList(),
                SafetyNotes = result.SafetyNotes.Select((n, i) => new RecoverySafetyNote
                {
                    NoteText = n, SortOrder = i
                }).ToList()
            };
            _context.RecoveryPlans.Add(plan);

            recovery.Status = RecoveryStatus.PlanGenerated;
            recovery.UpdatedAt = DateTime.UtcNow;

            if (workflow != null)
            {
                step.ExecutionStatus = AgentExecutionStatus.Succeeded;
                step.OutputSummary = $"Plan generated: {result.PreparationSteps.Count} steps, {result.SafetyNotes.Count} safety notes";
                step.CompletedAt = DateTime.UtcNow;
                workflow.CurrentStage = "PlanGenerated";
                workflow.UpdatedAt = DateTime.UtcNow;
            }

            await _context.SaveChangesAsync();

            var updated = await GetRecoveryWithIncludes(id);
            return Ok(MapToDto(updated!, updated!.Item));
        }
        catch (Exception ex)
        {
            if (workflow != null)
            {
                step.ExecutionStatus = AgentExecutionStatus.Failed;
                step.ErrorMessage = ex.Message;
                step.CompletedAt = DateTime.UtcNow;
                workflow.Status = "Failed";
                workflow.UpdatedAt = DateTime.UtcNow;
                await _context.SaveChangesAsync();
            }
            return StatusCode(500, new { error = "Recovery plan could not be generated. Please try again." });
        }
    }

    [HttpPost("api/recovery/{id}/submit")]
    public async Task<IActionResult> Submit(Guid id)
    {
        var userId = GetUserId();
        var recovery = await _context.RecoveryRequests.FindAsync(id);
        if (recovery == null) return NotFound();
        if (recovery.CustomerId != userId) return Forbid();
        if (recovery.Status != RecoveryStatus.PlanGenerated && recovery.Status != RecoveryStatus.RevisionRequested)
            return BadRequest(new { error = "Recovery must have a plan before submission." });

        recovery.Status = RecoveryStatus.PendingAdminApproval;
        recovery.SubmittedAt = DateTime.UtcNow;
        recovery.UpdatedAt = DateTime.UtcNow;
        await _context.SaveChangesAsync();
        return NoContent();
    }

    // ─── Admin endpoints ───

    [HttpGet("api/admin/recovery")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> AdminGetAll([FromQuery] string? status)
    {
        var query = _context.RecoveryRequests
            .Include(r => r.Item).ThenInclude(i => i.Category)
            .Include(r => r.Item).ThenInclude(i => i.Images)
            .Include(r => r.Plan).ThenInclude(p => p!.Steps)
            .Include(r => r.Plan).ThenInclude(p => p!.SafetyNotes)
            .Include(r => r.ApprovalDecisions)
            .AsQueryable();

        if (!string.IsNullOrWhiteSpace(status) && Enum.TryParse<RecoveryStatus>(status, true, out var s))
            query = query.Where(r => r.Status == s);

        var results = await query.OrderByDescending(r => r.CreatedAt).ToListAsync();
        return Ok(results.Select(r => MapToDto(r, r.Item)));
    }

    [HttpGet("api/admin/recovery/{id}")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> AdminGetById(Guid id)
    {
        var recovery = await GetRecoveryWithIncludes(id);
        if (recovery == null) return NotFound();
        return Ok(MapToDto(recovery, recovery.Item));
    }

    [HttpPost("api/admin/recovery/{id}/decision")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> Decision(Guid id, [FromBody] ApprovalDto? dto)
    {
        var decision = dto?.Decision?.Trim();
        if (string.IsNullOrWhiteSpace(decision))
            return BadRequest(new { error = "Decision is required (Approved, Rejected, or RevisionRequested)." });

        if (decision.Equals("Approved", StringComparison.OrdinalIgnoreCase))
            return await MakeDecision(id, "Approved", dto?.Reason);

        if (decision.Equals("Rejected", StringComparison.OrdinalIgnoreCase))
        {
            if (string.IsNullOrWhiteSpace(dto?.Reason))
                return BadRequest(new { error = "Reason is required for rejection." });
            return await MakeDecision(id, "Rejected", dto.Reason);
        }

        if (decision.Equals("RevisionRequested", StringComparison.OrdinalIgnoreCase))
        {
            if (string.IsNullOrWhiteSpace(dto?.Reason))
                return BadRequest(new { error = "Reason is required for revision request." });
            return await MakeDecision(id, "RevisionRequested", dto.Reason);
        }

        return BadRequest(new { error = "Invalid decision. Must be Approved, Rejected, or RevisionRequested." });
    }

    [HttpPost("api/admin/recovery/{id}/approve")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> Approve(Guid id, [FromBody] ApprovalDto? dto = null)
    {
        return await MakeDecision(id, "Approved", dto?.Reason);
    }

    [HttpPost("api/admin/recovery/{id}/reject")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> Reject(Guid id, [FromBody] ApprovalDto? dto = null)
    {
        if (string.IsNullOrWhiteSpace(dto?.Reason))
            return BadRequest(new { error = "Reason is required for rejection." });
        return await MakeDecision(id, "Rejected", dto.Reason);
    }

    [HttpPost("api/admin/recovery/{id}/request-revision")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> RequestRevision(Guid id, [FromBody] ApprovalDto? dto = null)
    {
        if (string.IsNullOrWhiteSpace(dto?.Reason))
            return BadRequest(new { error = "Reason is required for revision request." });
        return await MakeDecision(id, "RevisionRequested", dto.Reason);
    }

    private async Task<IActionResult> MakeDecision(Guid recoveryId, string decision, string? reason)
    {
        var adminId = GetUserId();
        var recovery = await _context.RecoveryRequests.FindAsync(recoveryId);
        if (recovery == null) return NotFound();
        if (recovery.Status != RecoveryStatus.PendingAdminApproval)
            return BadRequest(new { error = "Recovery must be pending admin approval." });

        var approvalDecision = new ApprovalDecision
        {
            RecoveryRequestId = recoveryId,
            AdminId = adminId,
            Decision = decision,
            Reason = reason
        };
        _context.ApprovalDecisions.Add(approvalDecision);

        recovery.Status = decision switch
        {
            "Approved" => RecoveryStatus.Approved,
            "Rejected" => RecoveryStatus.Rejected,
            "RevisionRequested" => RecoveryStatus.RevisionRequested,
            _ => recovery.Status
        };
        recovery.UpdatedAt = DateTime.UtcNow;

        // Update workflow
        var workflow = await _context.AgentWorkflows.FirstOrDefaultAsync(w => w.ItemId == recovery.ItemId && w.Status != "Failed");
        if (workflow != null)
        {
            workflow.CurrentStage = decision == "Approved" ? "AdminApproved" : decision;
            workflow.UpdatedAt = DateTime.UtcNow;
        }

        await _context.SaveChangesAsync();
        return Ok(new ApprovalDecisionDto
        {
            Id = approvalDecision.Id,
            AdminId = adminId,
            Decision = decision,
            Reason = reason,
            DecidedAt = approvalDecision.DecidedAt
        });
    }

    private async Task<RecoveryRequest?> GetRecoveryWithIncludes(Guid id)
    {
        return await _context.RecoveryRequests
            .Include(r => r.Item).ThenInclude(i => i.Category)
            .Include(r => r.Item).ThenInclude(i => i.Images)
            .Include(r => r.Plan).ThenInclude(p => p!.Steps)
            .Include(r => r.Plan).ThenInclude(p => p!.SafetyNotes)
            .Include(r => r.ApprovalDecisions)
            .FirstOrDefaultAsync(r => r.Id == id);
    }

    private static RecoveryRequestDto MapToDto(RecoveryRequest r, Item item) => new()
    {
        Id = r.Id,
        ItemId = r.ItemId,
        Item = new ItemDto
        {
            Id = item.Id, Name = item.Name, CategoryId = item.CategoryId,
            Category = item.Category != null ? new CategoryDto { Id = item.Category.Id, Code = item.Category.Code, Name = item.Category.Name } : null,
            Brand = item.Brand, Model = item.Model, ConditionDescription = item.ConditionDescription,
            Status = item.Status.ToString(), SelectedRecoveryRoute = item.SelectedRecoveryRoute?.ToString(),
            Images = item.Images.OrderBy(i => i.SortOrder).Select(i => new ItemImageDto { Id = i.Id, ImageUrl = i.ImageUrl, SortOrder = i.SortOrder, IsPrimary = i.IsPrimary }).ToList()
        },
        SelectedRoute = r.SelectedRoute.ToString(),
        Status = r.Status.ToString(),
        SubmittedAt = r.SubmittedAt,
        Plan = r.Plan != null ? new RecoveryPlanDto
        {
            Id = r.Plan.Id,
            Suitability = r.Plan.Suitability,
            Summary = r.Plan.Summary,
            RequiredPartnerType = r.Plan.RequiredPartnerType,
            Steps = r.Plan.Steps.OrderBy(s => s.SortOrder).Select(s => new RecoveryPlanStepDto { StepText = s.StepText, SortOrder = s.SortOrder }).ToList(),
            SafetyNotes = r.Plan.SafetyNotes.OrderBy(n => n.SortOrder).Select(n => new RecoverySafetyNoteDto { NoteText = n.NoteText, SortOrder = n.SortOrder }).ToList()
        } : null,
        ApprovalDecisions = r.ApprovalDecisions
            .OrderByDescending(d => d.DecidedAt)
            .Select(d => new ApprovalDecisionDto
            {
                Id = d.Id,
                AdminId = d.AdminId,
                Decision = d.Decision,
                Reason = d.Reason,
                DecidedAt = d.DecidedAt
            }).ToList(),
        CreatedAt = r.CreatedAt,
        UpdatedAt = r.UpdatedAt
    };
}
