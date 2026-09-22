using LoopWorth.Application.DTOs;
using LoopWorth.Domain.Entities;
using LoopWorth.Infrastructure.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace LoopWorth.Api.Controllers;

[ApiController]
[Route("api/admin/workflows")]
[Authorize(Roles = "Admin")]
public class WorkflowsController : ControllerBase
{
    private readonly AppDbContext _context;

    public WorkflowsController(AppDbContext context)
    {
        _context = context;
    }

    // GET /api/admin/workflows
    [HttpGet]
    public async Task<IActionResult> GetAll()
    {
        var workflows = await _context.AgentWorkflows
            .Include(w => w.Item)
            .Include(w => w.Steps)
            .OrderByDescending(w => w.CreatedAt)
            .ToListAsync();

        return Ok(workflows.Select(MapToDto));
    }

    // GET /api/admin/workflows/{id}
    [HttpGet("{id:guid}")]
    public async Task<IActionResult> GetById(Guid id)
    {
        var workflow = await _context.AgentWorkflows
            .Include(w => w.Item)
            .Include(w => w.Steps)
            .FirstOrDefaultAsync(w => w.Id == id);

        if (workflow == null) return NotFound(new { error = "Workflow not found." });

        return Ok(MapToDto(workflow));
    }

    // GET /api/admin/workflows/item/{itemId}
    [HttpGet("item/{itemId:guid}")]
    public async Task<IActionResult> GetByItemId(Guid itemId)
    {
        var workflow = await _context.AgentWorkflows
            .Include(w => w.Item)
            .Include(w => w.Steps)
            .FirstOrDefaultAsync(w => w.ItemId == itemId);

        if (workflow == null) return NotFound(new { error = "Workflow not found for this item." });

        return Ok(MapToDto(workflow));
    }

    private static AgentWorkflowDto MapToDto(AgentWorkflow w) => new()
    {
        Id = w.Id,
        CustomerId = w.CustomerId,
        ItemId = w.ItemId,
        ItemName = w.Item?.Name,
        Objective = w.Objective,
        CurrentStage = w.CurrentStage,
        Status = w.Status,
        CreatedAt = w.CreatedAt,
        CompletedAt = w.CompletedAt,
        Steps = w.Steps.OrderBy(s => s.StartedAt).Select(s => new AgentWorkflowStepDto
        {
            Id = s.Id,
            AgentName = s.AgentName,
            StepName = s.StepName,
            ExecutionStatus = s.ExecutionStatus.ToString(),
            InputSummary = s.InputSummary,
            OutputSummary = s.OutputSummary,
            ErrorMessage = s.ErrorMessage,
            StartedAt = s.StartedAt,
            CompletedAt = s.CompletedAt
        }).ToList()
    };
}
