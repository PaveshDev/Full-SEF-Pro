using System.Security.Claims;
using LoopWorth.Application.DTOs;
using LoopWorth.Application.Interfaces;
using LoopWorth.Domain.Entities;
using LoopWorth.Domain.Enums;
using LoopWorth.Infrastructure.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace LoopWorth.Api.Controllers;

[ApiController]
[Route("api/items")]
[Authorize]
public class ItemsController : ControllerBase
{
    private readonly AppDbContext _context;
    private readonly IFileStorageService _fileStorage;
    private readonly IItemAssessmentAgent _agent;
    private readonly IEcoImpactAgent _ecoAgent;

    public ItemsController(AppDbContext context, IFileStorageService fileStorage, IItemAssessmentAgent agent, IEcoImpactAgent ecoAgent)
    {
        _context = context;
        _fileStorage = fileStorage;
        _agent = agent;
        _ecoAgent = ecoAgent;
    }

    private string GetUserId() => User.FindFirstValue(ClaimTypes.NameIdentifier)!;

    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CreateItemDto dto)
    {
        if (string.IsNullOrWhiteSpace(dto.Name))
            return BadRequest(new { error = "Item name is required." });
        if (string.IsNullOrWhiteSpace(dto.Brand))
            return BadRequest(new { error = "Brand is required." });
        if (string.IsNullOrWhiteSpace(dto.Model))
            return BadRequest(new { error = "Model is required." });
        if (string.IsNullOrWhiteSpace(dto.ConditionDescription))
            return BadRequest(new { error = "Condition description is required." });
        if (!await _context.Categories.AnyAsync(c => c.Id == dto.CategoryId))
            return BadRequest(new { error = "Invalid category." });

        var item = new Item
        {
            CustomerId = GetUserId(),
            CategoryId = dto.CategoryId,
            Name = dto.Name,
            Brand = dto.Brand,
            Model = dto.Model,
            ConditionDescription = dto.ConditionDescription,
            Status = ItemStatus.Draft
        };

        _context.Items.Add(item);
        await _context.SaveChangesAsync();

        // Run EcoImpact assessment immediately upon item creation
        try
        {
            await _context.Entry(item).Reference(i => i.Category).LoadAsync();
            var ecoResult = await _ecoAgent.AssessEcoImpactAsync(item);
            item.EcoHazardReportJson = System.Text.Json.JsonSerializer.Serialize(ecoResult);
            item.EcoHazardLevel = ecoResult.HazardLevel;
            item.EcoHazardAcknowledged = !ecoResult.IsHarmfulToEnvironment;
            await _context.SaveChangesAsync();
        }
        catch { }

        var result = await GetItemDto(item.Id);
        return CreatedAtAction(nameof(GetById), new { id = item.Id }, result);
    }

    [HttpGet]
    public async Task<IActionResult> GetAll([FromQuery] string? search, [FromQuery] Guid? categoryId, [FromQuery] string? status, [FromQuery] int page = 1, [FromQuery] int pageSize = 20)
    {
        var userId = GetUserId();
        var isAdmin = User.IsInRole("Admin");

        var query = _context.Items.Include(i => i.Category).Include(i => i.Images).AsQueryable();

        if (!isAdmin)
            query = query.Where(i => i.CustomerId == userId);

        if (!string.IsNullOrWhiteSpace(search))
            query = query.Where(i => i.Name.Contains(search));
        if (categoryId.HasValue)
            query = query.Where(i => i.CategoryId == categoryId.Value);
        if (!string.IsNullOrWhiteSpace(status) && Enum.TryParse<ItemStatus>(status, true, out var s))
            query = query.Where(i => i.Status == s);

        var total = await query.CountAsync();
        var items = await query.OrderByDescending(i => i.CreatedAt)
            .Skip((page - 1) * pageSize).Take(pageSize)
            .ToListAsync();

        return Ok(new { items = items.Select(MapToDto), total, page, pageSize });
    }

    [HttpGet("{id}")]
    public async Task<IActionResult> GetById(Guid id)
    {
        var dto = await GetItemDto(id);
        if (dto == null) return NotFound();

        var userId = GetUserId();
        if (!User.IsInRole("Admin"))
        {
            var item = await _context.Items.FindAsync(id);
            if (item?.CustomerId != userId) return Forbid();
        }
        return Ok(dto);
    }

    [HttpPut("{id}")]
    public async Task<IActionResult> Update(Guid id, [FromBody] UpdateItemDto dto)
    {
        var userId = GetUserId();
        var item = await _context.Items.FindAsync(id);
        if (item == null) return NotFound();
        if (item.CustomerId != userId) return Forbid();

        // Prevent editing if item is already locked into an active/approved recovery request
        var hasActiveRecovery = await _context.RecoveryRequests
            .AnyAsync(r => r.ItemId == id && r.Status != RecoveryStatus.Rejected && r.Status != RecoveryStatus.Draft);
        if (hasActiveRecovery)
            return BadRequest(new { error = "Cannot edit item details after recovery processing has begun." });

        if (string.IsNullOrWhiteSpace(dto.Name))
            return BadRequest(new { error = "Item name is required." });
        if (string.IsNullOrWhiteSpace(dto.Brand))
            return BadRequest(new { error = "Brand is required." });
        if (string.IsNullOrWhiteSpace(dto.Model))
            return BadRequest(new { error = "Model is required." });
        if (string.IsNullOrWhiteSpace(dto.ConditionDescription))
            return BadRequest(new { error = "Condition description is required." });
        if (!await _context.Categories.AnyAsync(c => c.Id == dto.CategoryId))
            return BadRequest(new { error = "Invalid category." });

        item.Name = dto.Name;
        item.CategoryId = dto.CategoryId;
        item.Brand = dto.Brand;
        item.Model = dto.Model;
        item.ConditionDescription = dto.ConditionDescription;
        item.Status = ItemStatus.Draft; // Reset to Draft so customer can re-run assessment
        item.SelectedRecoveryRoute = null;
        item.UpdatedAt = DateTime.UtcNow;

        // Clear any previous incomplete/outdated assessments for this item
        var priorAssessments = await _context.ItemAssessments.Where(a => a.ItemId == id).ToListAsync();
        if (priorAssessments.Any())
        {
            _context.ItemAssessments.RemoveRange(priorAssessments);
        }

        // Re-evaluate eco-impact with updated condition description
        try
        {
            await _context.Entry(item).Reference(i => i.Category).LoadAsync();
            var ecoResult = await _ecoAgent.AssessEcoImpactAsync(item);
            item.EcoHazardReportJson = System.Text.Json.JsonSerializer.Serialize(ecoResult);
            item.EcoHazardLevel = ecoResult.HazardLevel;
            item.EcoHazardAcknowledged = !ecoResult.IsHarmfulToEnvironment;
        }
        catch { }

        await _context.SaveChangesAsync();
        var updatedDto = await GetItemDto(item.Id);
        return Ok(updatedDto);
    }

    [HttpDelete("{id}")]
    public async Task<IActionResult> Delete(Guid id)
    {
        var userId = GetUserId();
        var item = await _context.Items.Include(i => i.Images).FirstOrDefaultAsync(i => i.Id == id);
        if (item == null) return NotFound();
        if (item.CustomerId != userId) return Forbid();
        if (item.Status != ItemStatus.Draft) return BadRequest(new { error = "Only draft items can be deleted." });

        foreach (var img in item.Images)
            await _fileStorage.DeleteFileAsync(img.ImageUrl);

        _context.Items.Remove(item);
        await _context.SaveChangesAsync();
        return NoContent();
    }

    [HttpPost("{id}/photos")]
    [HttpPost("{id}/photos/upload")]
    public async Task<IActionResult> UploadPhoto(Guid id, IFormFile file)
    {
        if (file == null || file.Length == 0)
            return BadRequest(new { error = "No file provided." });
        if (file.Length > 5 * 1024 * 1024)
            return BadRequest(new { error = "File size must be less than 5MB." });

        var allowedTypes = new[] { ".jpg", ".jpeg", ".png", ".webp" };
        var ext = Path.GetExtension(file.FileName).ToLowerInvariant();
        if (!allowedTypes.Contains(ext))
            return BadRequest(new { error = "Only JPG, PNG, and WebP images are allowed." });

        var userId = GetUserId();
        var item = await _context.Items.Include(i => i.Images).FirstOrDefaultAsync(i => i.Id == id);
        if (item == null) return NotFound();
        if (item.CustomerId != userId) return Forbid();
        if (item.Status != ItemStatus.Draft) return BadRequest(new { error = "Cannot add photos unless item is in Draft status." });

        using var stream = file.OpenReadStream();
        var url = await _fileStorage.SaveFileAsync(stream, file.FileName, "items");

        var image = new ItemImage
        {
            ItemId = item.Id,
            ImageUrl = url,
            SortOrder = item.Images.Count,
            IsPrimary = !item.Images.Any()
        };
        _context.ItemImages.Add(image);
        await _context.SaveChangesAsync();

        return Ok(new ItemImageDto { Id = image.Id, ImageUrl = image.ImageUrl, SortOrder = image.SortOrder, IsPrimary = image.IsPrimary });
    }

    [HttpDelete("{id}/photos/{photoId}")]
    public async Task<IActionResult> DeletePhoto(Guid id, Guid photoId)
    {
        var userId = GetUserId();
        var item = await _context.Items.Include(i => i.Images).FirstOrDefaultAsync(i => i.Id == id);
        if (item == null) return NotFound();
        if (item.CustomerId != userId) return Forbid();

        var photo = item.Images.FirstOrDefault(p => p.Id == photoId);
        if (photo == null) return NotFound();

        await _fileStorage.DeleteFileAsync(photo.ImageUrl);
        _context.ItemImages.Remove(photo);
        await _context.SaveChangesAsync();
        return NoContent();
    }

    [HttpPost("{id}/submit")]
    public async Task<IActionResult> Submit(Guid id)
    {
        var userId = GetUserId();
        var item = await _context.Items.Include(i => i.Images).FirstOrDefaultAsync(i => i.Id == id);
        if (item == null) return NotFound();
        if (item.CustomerId != userId) return Forbid();
        if (item.Status != ItemStatus.Draft) return BadRequest(new { error = "Only drafts can be submitted." });
        if (string.IsNullOrWhiteSpace(item.ConditionDescription))
            return BadRequest(new { error = "Condition description is required." });

        item.Status = ItemStatus.Submitted;
        item.UpdatedAt = DateTime.UtcNow;
        await _context.SaveChangesAsync();
        return NoContent();
    }

    [HttpPost("{id}/assess")]
    public async Task<IActionResult> Assess(Guid id)
    {
        var userId = GetUserId();
        var item = await _context.Items
            .Include(i => i.Category)
            .Include(i => i.Images)
            .FirstOrDefaultAsync(i => i.Id == id);

        if (item == null) return NotFound();
        if (item.CustomerId != userId && !User.IsInRole("Admin")) return Forbid();
        if (item.Status != ItemStatus.Submitted && item.Status != ItemStatus.AssessmentPending && item.Status != ItemStatus.Draft)
            return BadRequest(new { error = "Item must be submitted before assessment." });

        // Environmental Hazard Gate: If harmful, require customer to switch from Donate to Recycle and acknowledge precautions
        if (!string.IsNullOrEmpty(item.EcoHazardReportJson))
        {
            try
            {
                var eco = System.Text.Json.JsonSerializer.Deserialize<EcoImpactResult>(item.EcoHazardReportJson, new System.Text.Json.JsonSerializerOptions { PropertyNameCaseInsensitive = true });
                if (eco != null && eco.IsHarmfulToEnvironment)
                {
                    if (item.SelectedRecoveryRoute == RecoveryRoute.Donate)
                    {
                        return BadRequest(new { 
                            error = "Hazardous Item: Based on the reported condition defects and hazard report, this device cannot be donated. Please switch your route to Recycle before running assessment.",
                            requiresRecycleSwitch = true,
                            canBeDonated = false
                        });
                    }

                    if (!item.EcoHazardAcknowledged)
                    {
                        return BadRequest(new { 
                            error = "Environmental Hazard Alert: This item contains hazardous materials. Please review and acknowledge the environmental precautions before running advisory assessment.",
                            requiresEcoAcknowledgment = true
                        });
                    }
                }
            }
            catch { }
        }

        item.Status = ItemStatus.AssessmentPending;
        await _context.SaveChangesAsync();

        // Create or get workflow
        var workflow = await _context.AgentWorkflows
            .FirstOrDefaultAsync(w => w.ItemId == item.Id && w.Status != "Failed");

        if (workflow == null)
        {
            workflow = new AgentWorkflow
            {
                CustomerId = userId,
                ItemId = item.Id,
                Objective = $"Complete recovery workflow for Item {item.Id}",
                CurrentStage = "Assessment",
                Status = "Running"
            };
            _context.AgentWorkflows.Add(workflow);
            await _context.SaveChangesAsync();
        }
        else
        {
            workflow.CurrentStage = "Assessment";
            workflow.Status = "Running";
            workflow.UpdatedAt = DateTime.UtcNow;
        }

        var step = new AgentWorkflowStep
        {
            WorkflowId = workflow.Id,
            AgentName = "ItemAssessmentAgent",
            StepName = "AssessItem",
            ExecutionStatus = AgentExecutionStatus.Running,
            InputSummary = $"Item: {item.Name}, Category: {item.Category?.Name}, Condition: {item.ConditionDescription}",
            StartedAt = DateTime.UtcNow
        };
        _context.AgentWorkflowSteps.Add(step);
        await _context.SaveChangesAsync();

        try
        {
            var result = await _agent.AssessItemAsync(item);

            if (!result.IsCategoryMatch)
            {
                step.ExecutionStatus = AgentExecutionStatus.Failed;
                step.ErrorMessage = result.MismatchReason ?? "Category mismatch detected by Agent 1.";
                step.CompletedAt = DateTime.UtcNow;

                item.Status = ItemStatus.Draft; // Set to Draft so user can immediately edit mistaken category
                item.UpdatedAt = DateTime.UtcNow;

                workflow.CurrentStage = "CategoryCorrectionRequired";
                workflow.Status = "ActionRequired";
                workflow.UpdatedAt = DateTime.UtcNow;

                await _context.SaveChangesAsync();

                return UnprocessableEntity(new
                {
                    isCategoryMismatch = true,
                    inconsistencyType = result.InconsistencyType ?? (result.MismatchReason?.Contains("Description Inconsistency", StringComparison.OrdinalIgnoreCase) == true ? "DescriptionMismatch" : "CategoryMismatch"),
                    error = result.MismatchReason ?? "The selected category does not match the item details.",
                    detectedCategory = result.DetectedCategory,
                    mismatchReason = result.MismatchReason
                });
            }

            var assessment = new ItemAssessment
            {
                ItemId = item.Id,
                ConditionLevel = result.ConditionLevel,
                RecommendedRoute = result.RecommendedRoute,
                AlternativeRoute = result.AlternativeRoute,
                ConfidenceLevel = result.ConfidenceLevel,
                Explanation = result.Explanation,
                ExecutionStatus = AgentExecutionStatus.Succeeded
            };
            _context.ItemAssessments.Add(assessment);

            item.Status = ItemStatus.Assessed;
            item.UpdatedAt = DateTime.UtcNow;

            step.ExecutionStatus = AgentExecutionStatus.Succeeded;
            step.OutputSummary = $"Recommended: {result.RecommendedRoute}, Condition: {result.ConditionLevel}";
            step.CompletedAt = DateTime.UtcNow;

            workflow.CurrentStage = "AssessmentComplete";
            workflow.UpdatedAt = DateTime.UtcNow;

            await _context.SaveChangesAsync();
            return Ok(new ItemAssessmentDto
            {
                Id = assessment.Id,
                ConditionLevel = assessment.ConditionLevel.ToString(),
                RecommendedRoute = assessment.RecommendedRoute.ToString(),
                AlternativeRoute = assessment.AlternativeRoute?.ToString(),
                ConfidenceLevel = assessment.ConfidenceLevel.ToString(),
                Explanation = assessment.Explanation,
                CreatedAt = assessment.CreatedAt
            });
        }
        catch (Exception ex)
        {
            step.ExecutionStatus = AgentExecutionStatus.Failed;
            step.ErrorMessage = ex.Message;
            step.CompletedAt = DateTime.UtcNow;
            item.Status = ItemStatus.Submitted;
            workflow.Status = "Failed";
            workflow.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync();
            return StatusCode(500, new { error = "Assessment could not be completed. Please try again." });
        }
    }

    [HttpGet("{id}/assessment")]
    public async Task<IActionResult> GetAssessment(Guid id)
    {
        var userId = GetUserId();
        var item = await _context.Items.FindAsync(id);
        if (item == null) return NotFound();
        if (item.CustomerId != userId && !User.IsInRole("Admin")) return Forbid();

        var assessment = await _context.ItemAssessments
            .Where(a => a.ItemId == id && a.ExecutionStatus == AgentExecutionStatus.Succeeded)
            .OrderByDescending(a => a.CreatedAt)
            .FirstOrDefaultAsync();
        if (assessment == null) return NotFound(new { error = "No assessment found." });

        return Ok(new ItemAssessmentDto
        {
            Id = assessment.Id,
            ConditionLevel = assessment.ConditionLevel.ToString(),
            RecommendedRoute = assessment.RecommendedRoute.ToString(),
            AlternativeRoute = assessment.AlternativeRoute?.ToString(),
            ConfidenceLevel = assessment.ConfidenceLevel.ToString(),
            Explanation = assessment.Explanation,
            CreatedAt = assessment.CreatedAt
        });
    }

    [HttpPost("{id}/select-route")]
    public async Task<IActionResult> SelectRoute(Guid id, [FromBody] SelectRouteDto dto)
    {
        var userId = GetUserId();
        var item = await _context.Items.FindAsync(id);
        if (item == null) return NotFound();
        if (item.CustomerId != userId) return Forbid();

        if (!Enum.TryParse<RecoveryRoute>(dto.SelectedRoute, true, out var route))
            return BadRequest(new { error = "Invalid recovery route. Must be Donate or Recycle." });

        if (route == RecoveryRoute.Donate)
        {
            if (item.Status != ItemStatus.Assessed)
                return BadRequest(new { error = "Item must be assessed before selecting donation." });

            var hasHazard = item.EcoHazardLevel is "High" or "Critical" or "Moderate" ||
                            (item.EcoHazardReportJson != null && item.EcoHazardReportJson.Contains("\"IsHarmfulToEnvironment\":true"));
            if (hasHazard)
            {
                return BadRequest(new { error = "This item has hazardous damage/defects reported in its condition description and cannot be accepted for Donation. It must be processed under Recycle." });
            }
        }

        item.SelectedRecoveryRoute = route;
        item.UpdatedAt = DateTime.UtcNow;
        await _context.SaveChangesAsync();
        return NoContent();
    }

    [HttpPost("{id}/switch-to-recycle")]
    public async Task<IActionResult> SwitchToRecycle(Guid id)
    {
        var userId = GetUserId();
        var item = await _context.Items
            .Include(i => i.Category)
            .Include(i => i.Images)
            .FirstOrDefaultAsync(i => i.Id == id);
        if (item == null) return NotFound();
        if (item.CustomerId != userId && !User.IsInRole("Admin")) return Forbid();

        item.SelectedRecoveryRoute = RecoveryRoute.Recycle;
        item.EcoHazardAcknowledged = true;
        item.UpdatedAt = DateTime.UtcNow;
        await _context.SaveChangesAsync();

        return Ok(MapToDto(item));
    }

    [HttpPost("{id}/eco-assessment")]
    public async Task<IActionResult> RunEcoAssessment(Guid id)
    {
        var userId = GetUserId();
        var item = await _context.Items
            .Include(i => i.Category)
            .Include(i => i.Images)
            .FirstOrDefaultAsync(i => i.Id == id);

        if (item == null) return NotFound();
        if (item.CustomerId != userId && !User.IsInRole("Admin")) return Forbid();

        var ecoResult = await _ecoAgent.AssessEcoImpactAsync(item);
        item.EcoHazardReportJson = System.Text.Json.JsonSerializer.Serialize(ecoResult);
        item.EcoHazardLevel = ecoResult.HazardLevel;
        item.EcoHazardAcknowledged = !ecoResult.IsHarmfulToEnvironment;
        item.UpdatedAt = DateTime.UtcNow;
        await _context.SaveChangesAsync();

        return Ok(ecoResult);
    }

    [HttpPost("{id}/eco-acknowledge")]
    public async Task<IActionResult> AcknowledgeEcoHazard(Guid id)
    {
        var userId = GetUserId();
        var item = await _context.Items.FirstOrDefaultAsync(i => i.Id == id);
        if (item == null) return NotFound();
        if (item.CustomerId != userId && !User.IsInRole("Admin")) return Forbid();

        item.EcoHazardAcknowledged = true;
        item.UpdatedAt = DateTime.UtcNow;
        await _context.SaveChangesAsync();

        return Ok(new { success = true, ecoHazardAcknowledged = true });
    }

    private async Task<ItemDto?> GetItemDto(Guid id)
    {
        var item = await _context.Items
            .Include(i => i.Category)
            .Include(i => i.Images)
            .FirstOrDefaultAsync(i => i.Id == id);
        return item == null ? null : MapToDto(item);
    }

    private static ItemDto MapToDto(Item item)
    {
        EcoImpactDto? ecoDto = null;
        if (!string.IsNullOrEmpty(item.EcoHazardReportJson))
        {
            try
            {
                ecoDto = System.Text.Json.JsonSerializer.Deserialize<EcoImpactDto>(
                    item.EcoHazardReportJson,
                    new System.Text.Json.JsonSerializerOptions { PropertyNameCaseInsensitive = true });
            }
            catch { }
        }

        return new ItemDto
        {
            Id = item.Id,
            Name = item.Name,
            CategoryId = item.CategoryId,
            Category = item.Category != null ? new CategoryDto { Id = item.Category.Id, Code = item.Category.Code, Name = item.Category.Name } : null,
            Brand = item.Brand,
            Model = item.Model,
            ConditionDescription = item.ConditionDescription,
            Status = item.Status.ToString(),
            SelectedRecoveryRoute = item.SelectedRecoveryRoute?.ToString(),
            EcoHazardReportJson = item.EcoHazardReportJson,
            EcoHazardAcknowledged = item.EcoHazardAcknowledged,
            EcoHazardLevel = item.EcoHazardLevel,
            EcoAssessment = ecoDto,
            Images = item.Images.OrderBy(i => i.SortOrder).Select(img => new ItemImageDto { Id = img.Id, ImageUrl = img.ImageUrl, SortOrder = img.SortOrder, IsPrimary = img.IsPrimary }).ToList(),
            CreatedAt = item.CreatedAt,
            UpdatedAt = item.UpdatedAt
        };
    }
}
