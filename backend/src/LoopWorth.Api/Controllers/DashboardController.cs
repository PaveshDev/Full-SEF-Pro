using System.Security.Claims;
using LoopWorth.Application.DTOs;
using LoopWorth.Domain.Enums;
using LoopWorth.Infrastructure.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace LoopWorth.Api.Controllers;

[ApiController]
[Route("api/dashboard")]
[Authorize]
public class DashboardController : ControllerBase
{
    private readonly AppDbContext _context;

    public DashboardController(AppDbContext context)
    {
        _context = context;
    }

    private string GetUserId() => User.FindFirstValue(ClaimTypes.NameIdentifier)!;

    // GET /api/dashboard/customer
    [HttpGet("customer")]
    public async Task<IActionResult> GetCustomerDashboard()
    {
        var userId = GetUserId();

        var totalItems = await _context.Items.CountAsync(i => i.CustomerId == userId);
        var pendingRecovery = await _context.RecoveryRequests
            .CountAsync(r => r.CustomerId == userId && (r.Status == RecoveryStatus.Draft || r.Status == RecoveryStatus.PlanGenerated || r.Status == RecoveryStatus.PendingAdminApproval));

        // Partner selection pending: approved recovery request without a partner selection
        var approvedRecoveries = await _context.RecoveryRequests
            .Where(r => r.CustomerId == userId && r.Status == RecoveryStatus.Approved)
            .Select(r => r.Id)
            .ToListAsync();

        var selectedRecoveryIds = await _context.PartnerSelections
            .Where(s => s.CustomerId == userId)
            .Select(s => s.RecoveryRequestId)
            .ToListAsync();

        var partnerSelectionPending = approvedRecoveries.Count(id => !selectedRecoveryIds.Contains(id));

        var activeCollections = await _context.CollectionRequests
            .CountAsync(c => c.CustomerId == userId &&
                c.Status != CollectionStatus.Completed &&
                c.Status != CollectionStatus.Cancelled);

        var completedItems = await _context.CollectionRequests
            .CountAsync(c => c.CustomerId == userId && c.Status == CollectionStatus.Completed);

        return Ok(new CustomerDashboardDto
        {
            TotalItems = totalItems,
            PendingRecovery = pendingRecovery,
            PartnerSelectionPending = partnerSelectionPending,
            ActiveCollections = activeCollections,
            CompletedItems = completedItems
        });
    }

    // GET /api/dashboard/admin
    [HttpGet("admin")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> GetAdminDashboard()
    {
        var submittedItems = await _context.Items
            .CountAsync(i => i.Status == ItemStatus.Submitted || i.Status == ItemStatus.Assessed);

        var pendingApprovals = await _context.RecoveryRequests
            .CountAsync(r => r.Status == RecoveryStatus.PendingAdminApproval);

        var activePartners = await _context.Partners
            .CountAsync(p => p.IsActive);

        var collectionsAwaitingAssignment = await _context.CollectionRequests
            .CountAsync(c => c.Status == CollectionStatus.Requested && string.IsNullOrEmpty(c.AssignedCollectionAgentId));

        var activeCollections = await _context.CollectionRequests
            .CountAsync(c => c.Status == CollectionStatus.AgentAssigned ||
                             c.Status == CollectionStatus.Scheduled ||
                             c.Status == CollectionStatus.Collected ||
                             c.Status == CollectionStatus.DeliveredToPartner);

        var completedRecoveries = await _context.CollectionRequests
            .CountAsync(c => c.Status == CollectionStatus.Completed);

        return Ok(new AdminDashboardDto
        {
            SubmittedItems = submittedItems,
            PendingRecoveryApprovals = pendingApprovals,
            ActivePartners = activePartners,
            CollectionsAwaitingAssignment = collectionsAwaitingAssignment,
            ActiveCollections = activeCollections,
            CompletedRecoveries = completedRecoveries
        });
    }

    // GET /api/dashboard/agent
    [HttpGet("agent")]
    [Authorize(Roles = "CollectionAgent")]
    public async Task<IActionResult> GetAgentDashboard()
    {
        var userId = GetUserId();
        var today = DateTime.UtcNow.Date;

        var assignedJobs = await _context.CollectionRequests
            .CountAsync(c => c.AssignedCollectionAgentId == userId &&
                c.Status != CollectionStatus.Completed &&
                c.Status != CollectionStatus.Cancelled);

        var todaysJobs = await _context.CollectionRequests
            .CountAsync(c => c.AssignedCollectionAgentId == userId &&
                c.ScheduledPickupDate.HasValue &&
                c.ScheduledPickupDate.Value.Date == today &&
                c.Status != CollectionStatus.Completed &&
                c.Status != CollectionStatus.Cancelled);

        var completedJobs = await _context.CollectionRequests
            .CountAsync(c => c.AssignedCollectionAgentId == userId && c.Status == CollectionStatus.Completed);

        return Ok(new AgentDashboardDto
        {
            AssignedJobs = assignedJobs,
            TodaysJobs = todaysJobs,
            CompletedJobs = completedJobs
        });
    }
}
