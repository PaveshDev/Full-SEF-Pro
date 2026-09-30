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
public class CollectionsController : ControllerBase
{
    private readonly AppDbContext _context;
    private readonly ICollectionPlanningAgent _planAgent;
    private readonly UserManager<ApplicationUser> _userManager;
    private readonly IFileStorageService _fileStorage;
    private readonly IEmailService _emailService;
    private readonly IDeliveryNotificationAgent _deliveryAgent;
    private readonly ILogger<CollectionsController> _logger;

    public CollectionsController(
        AppDbContext context,
        ICollectionPlanningAgent planAgent,
        UserManager<ApplicationUser> userManager,
        IFileStorageService fileStorage,
        IEmailService emailService,
        IDeliveryNotificationAgent deliveryAgent,
        ILogger<CollectionsController> logger)
    {
        _context = context;
        _planAgent = planAgent;
        _userManager = userManager;
        _fileStorage = fileStorage;
        _emailService = emailService;
        _deliveryAgent = deliveryAgent;
        _logger = logger;
    }

    private string GetUserId() => User.FindFirstValue(ClaimTypes.NameIdentifier)!;
    private bool IsAdmin() => User.IsInRole("Admin");
    private bool IsAgent() => User.IsInRole("CollectionAgent");

    // POST /api/recovery/{id}/collections - Customer creates collection preference
    [HttpPost("api/recovery/{id:guid}/collections")]
    public async Task<IActionResult> CreatePreference(Guid id, [FromBody] CreateCollectionDto dto, CancellationToken ct)
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
            return BadRequest(new { error = "Recovery request must be approved first." });
        }

        var partnerSelection = await _context.PartnerSelections
            .Include(s => s.Partner)
            .FirstOrDefaultAsync(s => s.RecoveryRequestId == id, ct);

        if (partnerSelection == null)
        {
            return BadRequest(new { error = "A recovery partner must be selected before requesting collection." });
        }

        // Check if collection already exists
        var existing = await _context.CollectionRequests
            .FirstOrDefaultAsync(c => c.RecoveryRequestId == id && c.Status != CollectionStatus.Cancelled, ct);

        CollectionRequest collection;
        if (existing != null)
        {
            collection = existing;
            collection.PreferredPickupDate = DateTime.SpecifyKind(dto.PreferredPickupDate, DateTimeKind.Utc);
            collection.PreferredStartTime = dto.PreferredStartTime;
            collection.PreferredEndTime = dto.PreferredEndTime;
            collection.Status = CollectionStatus.Requested;
            collection.UpdatedAt = DateTime.UtcNow;

            collection.StatusHistory.Add(new CollectionStatusHistory
            {
                Status = CollectionStatus.Requested,
                ChangedByUserId = userId,
                Note = "Pickup preference updated by customer. Awaiting Admin dispatch."
            });
        }
        else
        {
            collection = new CollectionRequest
            {
                RecoveryRequestId = id,
                PartnerId = partnerSelection.PartnerId,
                CustomerId = userId,
                PreferredPickupDate = DateTime.SpecifyKind(dto.PreferredPickupDate, DateTimeKind.Utc),
                PreferredStartTime = dto.PreferredStartTime,
                PreferredEndTime = dto.PreferredEndTime,
                Status = CollectionStatus.Requested
            };

            collection.StatusHistory.Add(new CollectionStatusHistory
            {
                Status = CollectionStatus.Requested,
                ChangedByUserId = userId,
                Note = "Pickup preference submitted by customer. Awaiting Admin dispatch."
            });

            _context.CollectionRequests.Add(collection);
        }

        await _context.SaveChangesAsync(ct);

        return CreatedAtAction(nameof(GetById), new { id = collection.Id }, await MapToDtoAsync(collection));
    }

    // POST /api/collections/{id}/plan - Generate / re-generate AI plan (Agent 4)
    [HttpPost("api/collections/{id:guid}/plan")]
    public async Task<IActionResult> GeneratePlan(Guid id, CancellationToken ct)
    {
        var collection = await _context.CollectionRequests
            .FirstOrDefaultAsync(c => c.Id == id, ct);

        if (collection == null) return NotFound(new { error = "Collection request not found." });
        if (collection.CustomerId != GetUserId() && !IsAdmin()) return Forbid();

        var updated = await DispatchWithAiInternalAsync(id, excludedAgentUserId: null, ct);
        return Ok(await MapToDtoAsync(updated ?? collection));
    }

    private async Task SyncAgentAvailabilityAsync(string? agentUserId, CancellationToken ct = default)
    {
        if (string.IsNullOrEmpty(agentUserId)) return;

        var profile = await _context.CollectionAgentProfiles
            .FirstOrDefaultAsync(p => p.UserId == agentUserId, ct);
        if (profile == null) return;

        // In-progress active collection jobs (Scheduled = accepted by agent, Collected = on route)
        var inProgressStatuses = new[] { CollectionStatus.Scheduled, CollectionStatus.Collected };
        var hasActiveJobs = await _context.CollectionRequests
            .AnyAsync(c => c.AssignedCollectionAgentId == agentUserId && inProgressStatuses.Contains(c.Status), ct);

        // If the agent has in-progress jobs, they are marked Busy (IsAvailable = false).
        // If all jobs are delivered / completed / cancelled, they are Available (IsAvailable = true).
        var shouldBeAvailable = !hasActiveJobs;
        if (profile.IsAvailable != shouldBeAvailable)
        {
            profile.IsAvailable = shouldBeAvailable;
            profile.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync(ct);
        }
    }

    private Task<CollectionRequest?> DispatchWithAiInternalAsync(
        Guid collectionId,
        string? excludedAgentUserId,
        CancellationToken ct)
    {
        return DispatchWithAiInternalAsync(
            collectionId,
            string.IsNullOrEmpty(excludedAgentUserId) ? null : new[] { excludedAgentUserId },
            ct);
    }

    private async Task<CollectionRequest?> DispatchWithAiInternalAsync(
        Guid collectionId,
        IEnumerable<string>? excludedAgentUserIds,
        CancellationToken ct)
    {
        var collection = await _context.CollectionRequests
            .Include(c => c.RecoveryRequest)
            .ThenInclude(r => r.Item)
            .ThenInclude(i => i.Category)
            .Include(c => c.Partner)
            .Include(c => c.StatusHistory)
            .FirstOrDefaultAsync(c => c.Id == collectionId, ct);

        if (collection == null) return null;

        var partner = collection.Partner;
        var recovery = collection.RecoveryRequest;

        // Determine target service area based on customer location (falling back to partner service area)
        var customer = await _userManager.FindByIdAsync(collection.CustomerId);
        var customerDistrict = customer?.District;
        var customerTown = customer?.Town;
        var targetArea = !string.IsNullOrWhiteSpace(customerDistrict) ? customerDistrict : (partner?.ServiceArea ?? "Colombo");

        // Requested pickup date and time window
        var requestedDate = (collection.PreferredPickupDate ?? collection.ScheduledPickupDate ?? DateTime.UtcNow.AddDays(1)).Date;
        var requestedStartTime = collection.PreferredStartTime ?? collection.ScheduledStartTime ?? new TimeSpan(9, 0, 0);
        var requestedEndTime = collection.PreferredEndTime ?? collection.ScheduledEndTime ?? new TimeSpan(12, 0, 0);

        // Query active collection agent profiles who are currently AVAILABLE (not busy on another active job)
        var agentProfiles = await _context.CollectionAgentProfiles
            .Where(p => p.IsActive && p.IsAvailable)
            .ToListAsync(ct);

        // Gather all agents who previously declined this specific collection request
        var historyDeclined = (collection.StatusHistory ?? new List<CollectionStatusHistory>())
            .Where(h => !string.IsNullOrEmpty(h.Note) && h.Note.Contains("declined", StringComparison.OrdinalIgnoreCase))
            .Select(h => h.ChangedByUserId)
            .OfType<string>()
            .ToHashSet();

        var exclusions = new HashSet<string>(historyDeclined);
        if (excludedAgentUserIds != null)
        {
            foreach (var ex in excludedAgentUserIds)
            {
                if (!string.IsNullOrEmpty(ex)) exclusions.Add(ex);
            }
        }

        if (exclusions.Count > 0)
        {
            agentProfiles = agentProfiles.Where(p => !exclusions.Contains(p.UserId)).ToList();
        }

        var agentUsers = new Dictionary<string, string>();
        foreach (var p in agentProfiles)
        {
            var u = await _userManager.FindByIdAsync(p.UserId);
            if (u != null)
            {
                agentUsers[p.UserId] = u.Name;
            }
        }

        // Active collection jobs across all agents to detect time conflicts
        var activeStatuses = new[] { CollectionStatus.AgentAssigned, CollectionStatus.Scheduled, CollectionStatus.Collected };
        var otherActiveCollections = await _context.CollectionRequests
            .Where(c => c.AssignedCollectionAgentId != null && activeStatuses.Contains(c.Status) && c.Id != collection.Id)
            .ToListAsync(ct);

        var agentConflicts = new Dictionary<string, (bool isBusy, string reason)>();
        var agentActiveJobCounts = new Dictionary<string, int>();

        foreach (var p in agentProfiles)
        {
            var agentJobs = otherActiveCollections.Where(c => c.AssignedCollectionAgentId == p.UserId).ToList();
            agentActiveJobCounts[p.UserId] = agentJobs.Count;

            // Check if any job overlaps on requestedDate during the requested window
            var conflictingJob = agentJobs.FirstOrDefault(c =>
            {
                var jobDate = (c.ScheduledPickupDate ?? c.PreferredPickupDate)?.Date;
                if (jobDate == null || jobDate.Value != requestedDate) return false;

                var jobStart = c.ScheduledStartTime ?? c.PreferredStartTime ?? new TimeSpan(9, 0, 0);
                var jobEnd = c.ScheduledEndTime ?? c.PreferredEndTime ?? new TimeSpan(12, 0, 0);

                return jobStart < requestedEndTime && requestedStartTime < jobEnd;
            });

            if (conflictingJob != null)
            {
                var cStart = conflictingJob.ScheduledStartTime ?? conflictingJob.PreferredStartTime ?? new TimeSpan(9, 0, 0);
                var cEnd = conflictingJob.ScheduledEndTime ?? conflictingJob.PreferredEndTime ?? new TimeSpan(12, 0, 0);
                agentConflicts[p.UserId] = (true, $"Busy on {requestedDate:yyyy-MM-dd} from {cStart:hh\\:mm} to {cEnd:hh\\:mm}");
            }
            else
            {
                agentConflicts[p.UserId] = (false, "Free on requested date and time");
            }
        }

        var candidateDtos = agentProfiles
            .Where(p => agentUsers.ContainsKey(p.UserId))
            .Select(p =>
            {
                var (isBusy, reason) = agentConflicts.GetValueOrDefault(p.UserId, (false, "Free on requested date and time"));
                return new CollectionAgentCandidate
                {
                    UserId = p.UserId,
                    Name = agentUsers[p.UserId],
                    ServiceArea = p.ServiceArea,
                    TownArea = p.TownArea,
                    IsAvailable = p.IsAvailable,
                    HasActiveJob = agentActiveJobCounts.GetValueOrDefault(p.UserId, 0) > 0,
                    ActiveJobsCount = agentActiveJobCounts.GetValueOrDefault(p.UserId, 0),
                    IsBusyAtRequestedTime = isBusy,
                    BusyReason = reason
                };
            }).ToList();

        // Track workflow step
        var workflow = recovery != null
            ? await _context.AgentWorkflows.FirstOrDefaultAsync(w => w.ItemId == recovery.ItemId, ct)
            : null;

        var step = new AgentWorkflowStep
        {
            WorkflowId = workflow?.Id ?? Guid.Empty,
            AgentName = "CollectionPlanningAgent",
            StepName = "CollectionAgentDispatch",
            ExecutionStatus = AgentExecutionStatus.Running,
            InputSummary = $"Dispatching collection agent for customer location: {targetArea} ({customerTown ?? "all areas"}) on {requestedDate:yyyy-MM-dd} {requestedStartTime:hh\\:mm}-{requestedEndTime:hh\\:mm}. Candidates: {candidateDtos.Count} (Free at time: {candidateDtos.Count(c => !c.IsBusyAtRequestedTime)})",
            StartedAt = DateTime.UtcNow
        };

        if (workflow != null)
        {
            workflow.CurrentStage = "CollectionPlanning";
            workflow.UpdatedAt = DateTime.UtcNow;
            _context.AgentWorkflowSteps.Add(step);
            await _context.SaveChangesAsync(ct);
        }

        if (candidateDtos.Count > 0)
        {
            CollectionPlanResult? planResult = null;
            try
            {
                planResult = await _planAgent.PlanCollectionAsync(
                    collection.Id,
                    collection.PreferredPickupDate ?? DateTime.UtcNow.AddDays(1),
                    collection.PreferredStartTime ?? new TimeSpan(9, 0, 0),
                    collection.PreferredEndTime ?? new TimeSpan(12, 0, 0),
                    partner?.Name ?? "Partner Facility",
                    partner?.OperatingHours ?? "09:00 - 17:00",
                    recovery?.Item?.Category?.Name ?? "General",
                    candidateDtos,
                    customerDistrict: targetArea,
                    customerTown: customerTown,
                    cancellationToken: ct);

                collection.SuggestedPickupDate = DateTime.SpecifyKind(planResult.SuggestedDate, DateTimeKind.Utc);
                collection.SuggestedStartTime = planResult.SuggestedStartTime;
                collection.SuggestedEndTime = planResult.SuggestedEndTime;
                collection.SuggestedCollectionAgentId = planResult.SuggestedCollectionAgentId;
                collection.UpdatedAt = DateTime.UtcNow;

                step.ExecutionStatus = AgentExecutionStatus.Succeeded;
                step.OutputSummary = $"AI selected agent {planResult.SuggestedCollectionAgentId} in {targetArea} ({planResult.Reason})";
                step.CompletedAt = DateTime.UtcNow;
            }
            catch (Exception ex)
            {
                step.ExecutionStatus = AgentExecutionStatus.Failed;
                step.ErrorMessage = ex.Message;
                step.CompletedAt = DateTime.UtcNow;

                // Deterministic fallback:
                // 1. Prioritize candidates in customer's service area
                var inArea = candidateDtos
                    .Where(c => string.Equals(c.ServiceArea, targetArea, StringComparison.OrdinalIgnoreCase))
                    .ToList();
                var searchPool = inArea.Count > 0 ? inArea : candidateDtos;

                // 2. Pick agent who is free on requested date & time, matching town, lowest active jobs
                var bestCandidate = searchPool
                    .OrderBy(c => c.IsBusyAtRequestedTime ? 1 : 0)
                    .ThenBy(c => (!string.IsNullOrEmpty(customerTown) && !string.IsNullOrEmpty(c.TownArea) && c.TownArea.Contains(customerTown, StringComparison.OrdinalIgnoreCase)) ? 0 : 1)
                    .ThenBy(c => c.ActiveJobsCount)
                    .FirstOrDefault();

                if (bestCandidate != null)
                {
                    collection.SuggestedPickupDate = DateTime.SpecifyKind(collection.PreferredPickupDate ?? DateTime.UtcNow.AddDays(1), DateTimeKind.Utc);
                    collection.SuggestedStartTime = collection.PreferredStartTime ?? new TimeSpan(9, 0, 0);
                    collection.SuggestedEndTime = collection.PreferredEndTime ?? new TimeSpan(12, 0, 0);
                    collection.SuggestedCollectionAgentId = bestCandidate.UserId;
                    collection.UpdatedAt = DateTime.UtcNow;
                }
            }

            var inAreaPool = candidateDtos
                .Where(c => string.Equals(c.ServiceArea, targetArea, StringComparison.OrdinalIgnoreCase))
                .ToList();
            var finalPool = inAreaPool.Count > 0 ? inAreaPool : candidateDtos;

            var chosenAgentId = collection.SuggestedCollectionAgentId
                ?? finalPool.FirstOrDefault(c => !c.IsBusyAtRequestedTime)?.UserId
                ?? finalPool.FirstOrDefault()?.UserId;

            if (!string.IsNullOrEmpty(chosenAgentId))
            {
                collection.AssignedCollectionAgentId = chosenAgentId;
                collection.ScheduledPickupDate = collection.SuggestedPickupDate ?? collection.PreferredPickupDate ?? DateTime.SpecifyKind(DateTime.UtcNow.AddDays(1), DateTimeKind.Utc);
                collection.ScheduledStartTime = collection.SuggestedStartTime ?? collection.PreferredStartTime ?? new TimeSpan(9, 0, 0);
                collection.ScheduledEndTime = collection.SuggestedEndTime ?? collection.PreferredEndTime ?? new TimeSpan(12, 0, 0);
                collection.Status = CollectionStatus.AgentAssigned;
                collection.UpdatedAt = DateTime.UtcNow;

                var chosenAgent = candidateDtos.FirstOrDefault(c => c.UserId == chosenAgentId);
                var agentName = agentUsers.GetValueOrDefault(chosenAgentId, "Collection Agent");
                var isReassignment = exclusions.Count > 0;
                var busyNote = (chosenAgent != null && chosenAgent.IsBusyAtRequestedTime)
                    ? " (Note: Agent has other task during this window; assigned with lowest load)"
                    : $" - verified free on {requestedDate:yyyy-MM-dd} at {requestedStartTime:hh\\:mm}-{requestedEndTime:hh\\:mm}";

                var history = new CollectionStatusHistory
                {
                    Id = Guid.NewGuid(),
                    CollectionRequestId = collection.Id,
                    Status = CollectionStatus.AgentAssigned,
                    ChangedByUserId = GetUserId(),
                    Note = isReassignment
                        ? $"Reassigned to collection agent {agentName} via Agentic AI for customer area ({targetArea}){busyNote}."
                        : $"Assigned to collection agent {agentName} via Agentic AI for customer area ({targetArea}){busyNote}.",
                    ChangedAt = DateTime.UtcNow
                };
                await _context.CollectionStatusHistories.AddAsync(history, ct);
            }
            else
            {
                collection.Status = CollectionStatus.Requested;
                collection.AssignedCollectionAgentId = null;
                collection.UpdatedAt = DateTime.UtcNow;
            }
        }
        else
        {
            step.ExecutionStatus = AgentExecutionStatus.Failed;
            step.ErrorMessage = $"No available collection agents found in {targetArea}.";
            step.CompletedAt = DateTime.UtcNow;

            collection.Status = CollectionStatus.Requested;
            collection.AssignedCollectionAgentId = null;
            collection.UpdatedAt = DateTime.UtcNow;

            var history = new CollectionStatusHistory
            {
                Id = Guid.NewGuid(),
                CollectionRequestId = collection.Id,
                Status = CollectionStatus.Requested,
                ChangedByUserId = GetUserId(),
                Note = $"Agentic AI dispatch found no available agents in {targetArea}. Request remains pending.",
                ChangedAt = DateTime.UtcNow
            };
            await _context.CollectionStatusHistories.AddAsync(history, ct);
        }

        await _context.SaveChangesAsync(ct);
        return collection;
    }

    // GET /api/collections - Customer list
    [HttpGet("api/collections")]
    public async Task<IActionResult> GetCustomerCollections()
    {
        var userId = GetUserId();
        var collections = await _context.CollectionRequests
            .Include(c => c.Partner)
            .Include(c => c.RecoveryRequest)
            .ThenInclude(r => r.Item)
            .ThenInclude(i => i.Category)
            .Include(c => c.StatusHistory)
            .Where(c => c.CustomerId == userId)
            .OrderByDescending(c => c.CreatedAt)
            .ToListAsync();

        var dtos = new List<CollectionRequestDto>();
        foreach (var c in collections)
        {
            dtos.Add(await MapToDtoAsync(c));
        }
        return Ok(dtos);
    }

    // GET /api/collections/{id}
    [HttpGet("api/collections/{id:guid}")]
    public async Task<IActionResult> GetById(Guid id)
    {
        var userId = GetUserId();
        var collection = await _context.CollectionRequests
            .Include(c => c.Partner)
            .Include(c => c.RecoveryRequest)
            .ThenInclude(r => r.Item)
            .ThenInclude(i => i.Category)
            .Include(c => c.StatusHistory)
            .FirstOrDefaultAsync(c => c.Id == id);

        if (collection == null) return NotFound(new { error = "Collection request not found." });

        if (collection.CustomerId != userId && collection.AssignedCollectionAgentId != userId && !IsAdmin())
        {
            return Forbid();
        }

        return Ok(await MapToDtoAsync(collection));
    }

    // GET /api/admin/collections - Admin list
    [HttpGet("api/admin/collections")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> GetAdminCollections([FromQuery] string? status)
    {
        var query = _context.CollectionRequests
            .Include(c => c.Partner)
            .Include(c => c.RecoveryRequest)
            .ThenInclude(r => r.Item)
            .ThenInclude(i => i.Category)
            .Include(c => c.StatusHistory)
            .AsQueryable();

        if (!string.IsNullOrWhiteSpace(status) && Enum.TryParse<CollectionStatus>(status, true, out var cStatus))
        {
            query = query.Where(c => c.Status == cStatus);
        }

        var collections = await query.OrderByDescending(c => c.CreatedAt).ToListAsync();

        var dtos = new List<CollectionRequestDto>();
        foreach (var c in collections)
        {
            dtos.Add(await MapToDtoAsync(c));
        }
        return Ok(dtos);
    }

    // POST /api/admin/collections/{id}/assign-agent - Admin triggers AI agent assignment or re-assignment
    [HttpPost("api/admin/collections/{id:guid}/assign-agent")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> AdminAssignAgentWithAi(Guid id, CancellationToken ct)
    {
        var collection = await _context.CollectionRequests
            .Include(c => c.Partner)
            .Include(c => c.StatusHistory)
            .FirstOrDefaultAsync(c => c.Id == id, ct);

        if (collection == null) return NotFound(new { error = "Collection request not found." });

        if (collection.Status != CollectionStatus.Requested && collection.Status != CollectionStatus.AgentAssigned)
        {
            return BadRequest(new { error = "Cannot reassign agent after the collection has been confirmed by the agent." });
        }

        // Exclude currently assigned agent (if reassigning)
        var currentAgentId = collection.AssignedCollectionAgentId;
        var excluded = new List<string>();
        if (!string.IsNullOrEmpty(currentAgentId))
        {
            excluded.Add(currentAgentId);
        }

        var updated = await DispatchWithAiInternalAsync(id, excludedAgentUserIds: excluded, ct);

        if (updated?.AssignedCollectionAgentId == null)
        {
            return BadRequest(new { error = "No available collection agents found in customer location for AI dispatch." });
        }

        return Ok(await MapToDtoAsync(updated));
    }

    // POST /api/admin/collections/{id}/assign - Admin assigns collection agent
    [HttpPost("api/admin/collections/{id:guid}/assign")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> AssignAgent(Guid id, [FromBody] AdminAssignCollectionDto dto)
    {
        var collection = await _context.CollectionRequests
            .FirstOrDefaultAsync(c => c.Id == id);

        if (collection == null) return NotFound(new { error = "Collection request not found." });

        if (collection.Status != CollectionStatus.Requested && collection.Status != CollectionStatus.AgentAssigned)
        {
            return BadRequest(new { error = "Cannot reassign agent after the collection has been confirmed by the agent." });
        }

        var agentUser = await _userManager.FindByIdAsync(dto.AssignedCollectionAgentId);
        if (agentUser == null) return BadRequest(new { error = "Specified collection agent does not exist." });

        var oldAgentId = collection.AssignedCollectionAgentId;
        collection.AssignedCollectionAgentId = dto.AssignedCollectionAgentId;
        collection.ScheduledPickupDate = DateTime.SpecifyKind(dto.ScheduledPickupDate, DateTimeKind.Utc);
        collection.ScheduledStartTime = dto.ScheduledStartTime;
        collection.ScheduledEndTime = dto.ScheduledEndTime;
        collection.Status = CollectionStatus.AgentAssigned;
        collection.UpdatedAt = DateTime.UtcNow;

        var history = new CollectionStatusHistory
        {
            Id = Guid.NewGuid(),
            CollectionRequestId = collection.Id,
            Status = CollectionStatus.AgentAssigned,
            ChangedByUserId = GetUserId(),
            Note = $"Assigned to agent {agentUser.Name}. Scheduled for {dto.ScheduledPickupDate:yyyy-MM-dd} {dto.ScheduledStartTime:hh\\:mm}-{dto.ScheduledEndTime:hh\\:mm}.",
            ChangedAt = DateTime.UtcNow
        };
        await _context.CollectionStatusHistories.AddAsync(history);

        await _context.SaveChangesAsync();

        if (!string.IsNullOrEmpty(oldAgentId) && oldAgentId != dto.AssignedCollectionAgentId)
        {
            await SyncAgentAvailabilityAsync(oldAgentId);
        }

        return Ok(await MapToDtoAsync(collection));
    }

    // GET /api/agent/collections - Agent assigned jobs
    [HttpGet("api/agent/collections")]
    [Authorize(Roles = "CollectionAgent")]
    public async Task<IActionResult> GetAgentJobs()
    {
        var userId = GetUserId();
        var collections = await _context.CollectionRequests
            .Include(c => c.Partner)
            .Include(c => c.RecoveryRequest)
            .ThenInclude(r => r.Item)
            .ThenInclude(i => i.Category)
            .Include(c => c.StatusHistory)
            .Where(c => c.AssignedCollectionAgentId == userId)
            .OrderBy(c => c.ScheduledPickupDate)
            .ToListAsync();

        var dtos = new List<CollectionRequestDto>();
        foreach (var c in collections)
        {
            dtos.Add(await MapToDtoAsync(c));
        }
        return Ok(dtos);
    }

    // POST /api/agent/collections/{id}/accept - Assigned agent confirms and accepts the job
    [HttpPost("api/agent/collections/{id:guid}/accept")]
    [Authorize(Roles = "CollectionAgent")]
    public async Task<IActionResult> AcceptJob(Guid id, CancellationToken ct)
    {
        var userId = GetUserId();
        var collection = await _context.CollectionRequests
            .Include(c => c.Partner)
            .Include(c => c.RecoveryRequest)
            .ThenInclude(r => r.Item)
            .ThenInclude(i => i.Category)
            .FirstOrDefaultAsync(c => c.Id == id, ct);

        if (collection == null) return NotFound(new { error = "Collection request not found." });

        if (collection.AssignedCollectionAgentId != userId)
        {
            return Forbid();
        }

        if (collection.Status != CollectionStatus.AgentAssigned)
        {
            return BadRequest(new { error = $"Order cannot be accepted in current status: {collection.Status}" });
        }

        // Validate agent does not already have an active pickup in progress (Scheduled or Collected)
        var inProgressStatuses = new[] { CollectionStatus.Scheduled, CollectionStatus.Collected };
        var hasActiveJob = await _context.CollectionRequests
            .AnyAsync(c => c.AssignedCollectionAgentId == userId && inProgressStatuses.Contains(c.Status) && c.Id != id, ct);

        if (hasActiveJob)
        {
            return BadRequest(new { error = "You already have an active pickup in progress. You cannot accept another job until you complete and hand over your current accepted pickup." });
        }

        var agentUser = await _userManager.FindByIdAsync(userId);
        var agentName = agentUser?.Name ?? "Collection Agent";

        collection.Status = CollectionStatus.Scheduled;
        collection.UpdatedAt = DateTime.UtcNow;

        var history = new CollectionStatusHistory
        {
            Id = Guid.NewGuid(),
            CollectionRequestId = collection.Id,
            Status = CollectionStatus.Scheduled,
            ChangedByUserId = userId,
            Note = $"Collection agent {agentName} confirmed and accepted the order. Pickup scheduled. Agent duty status: Busy.",
            ChangedAt = DateTime.UtcNow
        };
        await _context.CollectionStatusHistories.AddAsync(history, ct);
        await _context.SaveChangesAsync(ct);

        // Update agent availability: Agent is now Busy
        await SyncAgentAvailabilityAsync(userId, ct);

        return Ok(await MapToDtoAsync(collection));
    }

    // POST /api/agent/collections/{id}/reject - Assigned agent rejects the job with reason
    [HttpPost("api/agent/collections/{id:guid}/reject")]
    [Authorize(Roles = "CollectionAgent")]
    public async Task<IActionResult> RejectJob(Guid id, [FromBody] RejectCollectionJobDto? dto, CancellationToken ct)
    {
        var userId = GetUserId();
        var collection = await _context.CollectionRequests
            .Include(c => c.Partner)
            .Include(c => c.RecoveryRequest)
            .ThenInclude(r => r.Item)
            .ThenInclude(i => i.Category)
            .FirstOrDefaultAsync(c => c.Id == id, ct);

        if (collection == null) return NotFound(new { error = "Collection request not found." });

        if (collection.AssignedCollectionAgentId != userId)
        {
            return Forbid();
        }

        if (collection.Status != CollectionStatus.AgentAssigned)
        {
            return BadRequest(new { error = $"Order cannot be rejected in current status: {collection.Status}" });
        }

        var agentUser = await _userManager.FindByIdAsync(userId);
        var agentName = agentUser?.Name ?? "Collection Agent";
        var reason = string.IsNullOrWhiteSpace(dto?.Reason) ? "Unavailable for schedule" : dto.Reason.Trim();

        var history = new CollectionStatusHistory
        {
            Id = Guid.NewGuid(),
            CollectionRequestId = collection.Id,
            Status = CollectionStatus.Requested,
            ChangedByUserId = userId,
            Note = $"Agent {agentName} declined the order ({reason}). Returned to Admin queue for AI re-dispatch.",
            ChangedAt = DateTime.UtcNow
        };
        await _context.CollectionStatusHistories.AddAsync(history, ct);

        collection.AssignedCollectionAgentId = null;
        collection.Status = CollectionStatus.Requested;
        collection.UpdatedAt = DateTime.UtcNow;
        await _context.SaveChangesAsync(ct);

        // Update agent availability
        await SyncAgentAvailabilityAsync(userId, ct);

        return Ok(await MapToDtoAsync(collection));
    }

    // POST /api/agent/collections/{id}/status - Agent updates status (Collected, DeliveredToPartner, Completed)
    [HttpPost("api/agent/collections/{id:guid}/status")]
    [Authorize(Roles = "CollectionAgent,Admin")]
    public async Task<IActionResult> UpdateStatus(Guid id, [FromBody] UpdateCollectionStatusDto dto)
    {
        var userId = GetUserId();
        var collection = await _context.CollectionRequests
            .Include(c => c.Partner)
            .Include(c => c.RecoveryRequest)
            .ThenInclude(r => r.Item)
            .ThenInclude(i => i.Category)
            .FirstOrDefaultAsync(c => c.Id == id);

        if (collection == null) return NotFound(new { error = "Collection request not found." });

        if (collection.AssignedCollectionAgentId != userId && !IsAdmin())
        {
            return Forbid();
        }

        if (!Enum.TryParse<CollectionStatus>(dto.Status, true, out var newStatus))
        {
            return BadRequest(new { error = $"Invalid collection status: {dto.Status}" });
        }

        // Allowed transitions for agent:
        // AgentAssigned -> Scheduled (via accept endpoint or status update)
        // Scheduled -> Collected
        // Collected -> DeliveredToPartner (which auto-completes)
        // or direct Completed
        if (!IsAdmin())
        {
            if (newStatus != CollectionStatus.Scheduled &&
                newStatus != CollectionStatus.Collected && 
                newStatus != CollectionStatus.DeliveredToPartner && 
                newStatus != CollectionStatus.Completed)
            {
                return BadRequest(new { error = "Collection agents can only mark items as Scheduled, Collected, DeliveredToPartner, or Completed." });
            }
        }

        if (newStatus == CollectionStatus.Collected)
        {
            collection.Status = CollectionStatus.Collected;
            collection.UpdatedAt = DateTime.UtcNow;

            var history = new CollectionStatusHistory
            {
                Id = Guid.NewGuid(),
                CollectionRequestId = collection.Id,
                Status = CollectionStatus.Collected,
                ChangedByUserId = userId,
                Note = dto.Note ?? "Item has been picked up by our collection agent.",
                ChangedAt = DateTime.UtcNow
            };
            await _context.CollectionStatusHistories.AddAsync(history);
        }
        else if (newStatus == CollectionStatus.DeliveredToPartner)
        {
            var partnerName = collection.Partner?.Name ?? "the respective partner";

            collection.Status = CollectionStatus.DeliveredToPartner;
            collection.UpdatedAt = DateTime.UtcNow;

            var handoverHistory = new CollectionStatusHistory
            {
                Id = Guid.NewGuid(),
                CollectionRequestId = collection.Id,
                Status = CollectionStatus.DeliveredToPartner,
                ChangedByUserId = userId,
                Note = dto.Note ?? $"Item has been delivered and handed over to {partnerName}. Awaiting partner facility intake verification.",
                ChangedAt = DateTime.UtcNow
            };
            await _context.CollectionStatusHistories.AddAsync(handoverHistory);
        }
        else if (newStatus == CollectionStatus.Completed)
        {
            collection.Status = CollectionStatus.Completed;
            collection.UpdatedAt = DateTime.UtcNow;

            var history = new CollectionStatusHistory
            {
                Id = Guid.NewGuid(),
                CollectionRequestId = collection.Id,
                Status = CollectionStatus.Completed,
                ChangedByUserId = userId,
                Note = dto.Note ?? "Confirmed received by partner. Collection completed.",
                ChangedAt = DateTime.UtcNow
            };
            await _context.CollectionStatusHistories.AddAsync(history);

            if (collection.RecoveryRequest != null)
            {
                var workflow = await _context.AgentWorkflows
                    .FirstOrDefaultAsync(w => w.ItemId == collection.RecoveryRequest.ItemId);

                if (workflow != null)
                {
                    workflow.CurrentStage = "Completed";
                    workflow.Status = "Completed";
                    workflow.CompletedAt = DateTime.UtcNow;
                }
            }

            await TriggerDeliveryCompletionEmailAsync(collection);
        }

        await _context.SaveChangesAsync();
        await SyncAgentAvailabilityAsync(collection.AssignedCollectionAgentId ?? userId);

        return Ok(await MapToDtoAsync(collection));
    }

    // POST /api/admin/collections/{id}/complete - Admin marks PartnerReceived / Completed
    [HttpPost("api/admin/collections/{id:guid}/complete")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> CompleteCollection(Guid id, [FromBody] UpdateCollectionStatusDto? dto)
    {
        var collection = await _context.CollectionRequests
            .Include(c => c.Partner)
            .Include(c => c.RecoveryRequest)
            .ThenInclude(r => r.Item)
            .ThenInclude(i => i.Category)
            .FirstOrDefaultAsync(c => c.Id == id);

        if (collection == null) return NotFound(new { error = "Collection request not found." });

        collection.Status = CollectionStatus.Completed;
        collection.UpdatedAt = DateTime.UtcNow;

        var history = new CollectionStatusHistory
        {
            Id = Guid.NewGuid(),
            CollectionRequestId = collection.Id,
            Status = CollectionStatus.Completed,
            ChangedByUserId = GetUserId(),
            Note = dto?.Note ?? "Confirmed received by partner. Collection completed by administrator.",
            ChangedAt = DateTime.UtcNow
        };
        await _context.CollectionStatusHistories.AddAsync(history);

        // Mark agent workflow completed if active
        if (collection.RecoveryRequest != null)
        {
            var workflow = await _context.AgentWorkflows
                .FirstOrDefaultAsync(w => w.ItemId == collection.RecoveryRequest.ItemId);

            if (workflow != null)
            {
                workflow.CurrentStage = "Completed";
                workflow.Status = "Completed";
                workflow.CompletedAt = DateTime.UtcNow;
            }
        }

        await _context.SaveChangesAsync();
        await SyncAgentAvailabilityAsync(collection.AssignedCollectionAgentId);
        await TriggerDeliveryCompletionEmailAsync(collection);

        return Ok(await MapToDtoAsync(collection));
    }

    // GET /api/partner/collections - Partner views incoming handovers & processed items
    [HttpGet("api/partner/collections")]
    [Authorize(Roles = "Partner")]
    public async Task<IActionResult> GetPartnerCollections()
    {
        var userId = GetUserId();
        var user = await _userManager.FindByIdAsync(userId);
        var userEmail = user?.Email;

        var partner = await _context.Partners
            .FirstOrDefaultAsync(p => p.UserId == userId || (userEmail != null && p.Email == userEmail));

        if (partner == null)
            return NotFound(new { error = "Partner organization not linked to this user account." });

        var collections = await _context.CollectionRequests
            .Include(c => c.Partner)
            .Include(c => c.RecoveryRequest).ThenInclude(r => r.Item).ThenInclude(i => i.Category)
            .Include(c => c.RecoveryRequest).ThenInclude(r => r.Item).ThenInclude(i => i.Images)
            .Include(c => c.StatusHistory)
            .Where(c => c.PartnerId == partner.Id)
            .OrderByDescending(c => c.CreatedAt)
            .ToListAsync();

        var dtos = new List<CollectionRequestDto>();
        foreach (var col in collections)
        {
            dtos.Add(await MapToDtoAsync(col));
        }

        return Ok(dtos);
    }

    // POST /api/partner/collections/{id}/receive - Partner confirms receipt, uploads photo & defect/damage feedback
    [HttpPost("api/partner/collections/{id:guid}/receive")]
    [Authorize(Roles = "Partner")]
    public async Task<IActionResult> PartnerConfirmReceipt(
        Guid id,
        [FromForm] PartnerConfirmReceiptDto dto)
    {
        var photo = dto.Photo;
        var feedback = dto.Feedback;
        var conditionOk = dto.ConditionOk;

        var userId = GetUserId();
        var user = await _userManager.FindByIdAsync(userId);
        var userEmail = user?.Email;

        var partner = await _context.Partners
            .FirstOrDefaultAsync(p => p.UserId == userId || (userEmail != null && p.Email == userEmail));

        if (partner == null)
            return NotFound(new { error = "Partner organization not linked to this user account." });

        var collection = await _context.CollectionRequests
            .Include(c => c.Partner)
            .Include(c => c.RecoveryRequest).ThenInclude(r => r.Item).ThenInclude(i => i.Category)
            .Include(c => c.RecoveryRequest).ThenInclude(r => r.Item).ThenInclude(i => i.Images)
            .Include(c => c.StatusHistory)
            .FirstOrDefaultAsync(c => c.Id == id);

        if (collection == null) return NotFound(new { error = "Collection request not found." });
        if (collection.PartnerId != partner.Id) return Forbid();

        string? photoUrl = null;
        if (photo != null && photo.Length > 0)
        {
            if (photo.Length > 10 * 1024 * 1024)
                return BadRequest(new { error = "File size must be less than 10MB." });

            var allowedExts = new[] { ".jpg", ".jpeg", ".png", ".webp" };
            var ext = Path.GetExtension(photo.FileName).ToLowerInvariant();
            if (!allowedExts.Contains(ext))
                return BadRequest(new { error = "Only JPG, PNG, and WebP images are allowed." });

            using var stream = photo.OpenReadStream();
            photoUrl = await _fileStorage.SaveFileAsync(stream, photo.FileName, "partner-receipts");
        }

        collection.Status = CollectionStatus.Completed;
        collection.UpdatedAt = DateTime.UtcNow;
        if (!string.IsNullOrEmpty(photoUrl)) collection.PartnerPhotoUrl = photoUrl;
        collection.PartnerFeedback = feedback;
        collection.PartnerConfirmedAt = DateTime.UtcNow;
        collection.PartnerReceivedConditionOk = conditionOk;

        var statusNote = $"Partner confirmed item receipt at facility. {(conditionOk ? "Condition verified." : "Damages or defects detected upon intake.")}" +
                         (string.IsNullOrWhiteSpace(feedback) ? "" : $" Remarks: {feedback}");

        var history = new CollectionStatusHistory
        {
            Id = Guid.NewGuid(),
            CollectionRequestId = collection.Id,
            Status = CollectionStatus.Completed,
            ChangedByUserId = userId,
            Note = statusNote,
            ChangedAt = DateTime.UtcNow
        };
        await _context.CollectionStatusHistories.AddAsync(history);

        // Mark agent workflow completed if active
        if (collection.RecoveryRequest != null)
        {
            var workflow = await _context.AgentWorkflows
                .FirstOrDefaultAsync(w => w.ItemId == collection.RecoveryRequest.ItemId);

            if (workflow != null)
            {
                workflow.CurrentStage = "Completed";
                workflow.Status = "Completed";
                workflow.CompletedAt = DateTime.UtcNow;
            }
        }

        await _context.SaveChangesAsync();
        await SyncAgentAvailabilityAsync(collection.AssignedCollectionAgentId);
        await TriggerDeliveryCompletionEmailAsync(collection);

        return Ok(await MapToDtoAsync(collection));
    }

    // POST /api/admin/collections/{id}/send-delivery-email - Manually trigger or resend delivery email
    [HttpPost("api/admin/collections/{id:guid}/send-delivery-email")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> SendDeliveryEmail(Guid id, CancellationToken ct)
    {
        var collection = await _context.CollectionRequests
            .Include(c => c.Partner)
            .Include(c => c.RecoveryRequest)
            .ThenInclude(r => r.Item)
            .ThenInclude(i => i.Category)
            .FirstOrDefaultAsync(c => c.Id == id, ct);

        if (collection == null) return NotFound(new { error = "Collection request not found." });

        collection.DeliveryEmailSent = false; // Reset to allow explicit send/resend
        await TriggerDeliveryCompletionEmailAsync(collection, ct);

        if (!collection.DeliveryEmailSent)
        {
            return BadRequest(new { error = "Failed to dispatch email via Brevo. Please check server logs and Brevo API key configuration." });
        }

        return Ok(new
        {
            success = collection.DeliveryEmailSent,
            sentAt = collection.DeliveryEmailSentAt,
            subject = collection.DeliveryEmailSubject
        });
    }

    private async Task TriggerDeliveryCompletionEmailAsync(CollectionRequest collection, CancellationToken ct = default)
    {
        if (collection.DeliveryEmailSent) return;

        try
        {
            if (collection.Partner == null)
            {
                await _context.Entry(collection).Reference(c => c.Partner).LoadAsync(ct);
            }
            if (collection.RecoveryRequest == null)
            {
                await _context.Entry(collection).Reference(c => c.RecoveryRequest).LoadAsync(ct);
            }
            if (collection.RecoveryRequest?.Item == null && collection.RecoveryRequest != null)
            {
                await _context.Entry(collection.RecoveryRequest).Reference(r => r.Item).LoadAsync(ct);
            }
            if (collection.RecoveryRequest?.Item?.Category == null && collection.RecoveryRequest?.Item != null)
            {
                await _context.Entry(collection.RecoveryRequest.Item).Reference(i => i.Category).LoadAsync(ct);
            }

            var item = collection.RecoveryRequest?.Item;
            var partner = collection.Partner;
            if (item == null || partner == null)
            {
                _logger.LogWarning("Cannot send delivery email: item or partner is missing for collection {CollectionId}", collection.Id);
                return;
            }

            // Lookup customer: try collection.CustomerId, then recovery.CustomerId, then item.CustomerId
            LoopWorth.Infrastructure.Identity.ApplicationUser? customer = null;
            if (!string.IsNullOrWhiteSpace(collection.CustomerId))
            {
                customer = await _userManager.FindByIdAsync(collection.CustomerId);
            }
            if (customer == null && collection.RecoveryRequest != null && !string.IsNullOrWhiteSpace(collection.RecoveryRequest.CustomerId))
            {
                customer = await _userManager.FindByIdAsync(collection.RecoveryRequest.CustomerId);
            }
            if (customer == null && item != null && !string.IsNullOrWhiteSpace(item.CustomerId))
            {
                customer = await _userManager.FindByIdAsync(item.CustomerId);
            }

            if (customer == null || string.IsNullOrWhiteSpace(customer.Email))
            {
                _logger.LogWarning("Cannot send delivery email: customer not found or email is empty for collection {CollectionId} (CustomerId: {CustomerId}).", collection.Id, collection.CustomerId);
                return;
            }

            var customerName = customer.FullName ?? customer.UserName ?? "Valued Customer";
            var emailContent = await _deliveryAgent.GenerateDeliveryEmailAsync(
                customerName,
                customer.Email,
                item,
                partner,
                collection.PartnerFeedback,
                collection.PartnerReceivedConditionOk,
                ct);

            var sent = await _emailService.SendEmailAsync(
                customer.Email,
                customerName,
                emailContent.Subject,
                emailContent.HtmlBody,
                ct);

            if (sent)
            {
                collection.DeliveryEmailSent = true;
                collection.DeliveryEmailSentAt = DateTime.UtcNow;
                collection.DeliveryEmailSubject = emailContent.Subject;
                await _context.SaveChangesAsync(ct);
                _logger.LogInformation("Delivery completion email successfully dispatched via Brevo for collection {CollectionId} to {Email}", collection.Id, customer.Email);
            }
            else
            {
                _logger.LogWarning("Brevo transactional email dispatch returned false for collection {CollectionId} to {Email}", collection.Id, customer.Email);
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to trigger delivery completion email for collection {CollectionId}", collection.Id);
        }
    }

    private async Task<CollectionRequestDto> MapToDtoAsync(CollectionRequest c)
    {
        string? agentName = null;
        if (!string.IsNullOrEmpty(c.AssignedCollectionAgentId))
        {
            var agent = await _userManager.FindByIdAsync(c.AssignedCollectionAgentId);
            agentName = agent?.Name;
        }

        string? customerName = null;
        string? customerPhone = null;
        string? customerAddress = null;
        string? customerDistrict = null;
        string? customerTown = null;
        if (!string.IsNullOrEmpty(c.CustomerId))
        {
            var customer = await _userManager.FindByIdAsync(c.CustomerId);
            if (customer != null)
            {
                customerName = customer.FullName;
                customerPhone = customer.PhoneNumber;
                customerAddress = customer.Address;
                customerDistrict = customer.District;
                customerTown = customer.Town;
            }
        }

        var historyItems = (c.StatusHistory != null && c.StatusHistory.Count > 0)
            ? c.StatusHistory
            : await _context.CollectionStatusHistories
                .Where(h => h.CollectionRequestId == c.Id)
                .ToListAsync();

        return new CollectionRequestDto
        {
            Id = c.Id,
            RecoveryRequestId = c.RecoveryRequestId,
            PartnerId = c.PartnerId,
            PartnerName = c.Partner?.Name ?? string.Empty,
            CustomerId = c.CustomerId,
            CustomerName = customerName,
            CustomerPhone = customerPhone,
            CustomerAddress = customerAddress,
            CustomerDistrict = customerDistrict,
            CustomerTown = customerTown,
            PreferredPickupDate = c.PreferredPickupDate,
            PreferredStartTime = c.PreferredStartTime,
            PreferredEndTime = c.PreferredEndTime,
            SuggestedPickupDate = c.SuggestedPickupDate,
            SuggestedStartTime = c.SuggestedStartTime,
            SuggestedEndTime = c.SuggestedEndTime,
            SuggestedCollectionAgentId = c.SuggestedCollectionAgentId,
            ScheduledPickupDate = c.ScheduledPickupDate,
            ScheduledStartTime = c.ScheduledStartTime,
            ScheduledEndTime = c.ScheduledEndTime,
            AssignedCollectionAgentId = c.AssignedCollectionAgentId,
            AssignedAgentName = agentName,
            Status = c.Status.ToString(),
            PartnerPhotoUrl = c.PartnerPhotoUrl,
            PartnerFeedback = c.PartnerFeedback,
            PartnerConfirmedAt = c.PartnerConfirmedAt,
            PartnerReceivedConditionOk = c.PartnerReceivedConditionOk,
            DeliveryEmailSent = c.DeliveryEmailSent,
            DeliveryEmailSentAt = c.DeliveryEmailSentAt,
            DeliveryEmailSubject = c.DeliveryEmailSubject,
            Item = c.RecoveryRequest?.Item != null ? new ItemDto
            {
                Id = c.RecoveryRequest.Item.Id,
                Name = c.RecoveryRequest.Item.Name,
                CategoryId = c.RecoveryRequest.Item.CategoryId,
                Brand = c.RecoveryRequest.Item.Brand,
                Model = c.RecoveryRequest.Item.Model,
                ConditionDescription = c.RecoveryRequest.Item.ConditionDescription,
                Status = c.RecoveryRequest.Item.Status.ToString(),
                SelectedRecoveryRoute = c.RecoveryRequest.Item.SelectedRecoveryRoute?.ToString(),
                Images = c.RecoveryRequest.Item.Images?.OrderBy(i => i.SortOrder).Select(i => new ItemImageDto
                {
                    Id = i.Id,
                    ImageUrl = i.ImageUrl,
                    SortOrder = i.SortOrder,
                    IsPrimary = i.IsPrimary
                }).ToList() ?? new()
            } : null,
            StatusHistory = historyItems.OrderBy(h => h.ChangedAt).Select(h => new CollectionStatusHistoryDto
            {
                Status = h.Status.ToString(),
                Note = h.Note,
                ChangedAt = h.ChangedAt
            }).ToList(),
            CreatedAt = c.CreatedAt
        };
    }
}

public class PartnerConfirmReceiptDto
{
    public IFormFile? Photo { get; set; }
    public string? Feedback { get; set; }
    public bool ConditionOk { get; set; } = true;
}
