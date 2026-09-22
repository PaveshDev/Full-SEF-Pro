using LoopWorth.Domain.Enums;

namespace LoopWorth.Application.DTOs;

// ─── Auth ───

public class RegisterDto
{
    public string Name { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;
    public string? Phone { get; set; }
    public string? Address { get; set; }
    public string? District { get; set; }
    public string? Town { get; set; }
}

public class LoginDto
{
    public string Email { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;
}

public class AuthResponseDto
{
    public string Token { get; set; } = string.Empty;
    public string UserId { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string Role { get; set; } = string.Empty;
    public string? Phone { get; set; }
    public string? Address { get; set; }
    public string? District { get; set; }
    public string? Town { get; set; }
}

public class UserProfileDto
{
    public string UserId { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string Role { get; set; } = string.Empty;
    public string? Phone { get; set; }
    public string? Address { get; set; }
    public string? District { get; set; }
    public string? Town { get; set; }
}

public class UpdateUserProfileDto
{
    public string? Name { get; set; }
    public string? Phone { get; set; }
    public string? Address { get; set; }
    public string? District { get; set; }
    public string? Town { get; set; }
}

// ─── Category ───

public class CategoryDto
{
    public Guid Id { get; set; }
    public string Code { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
}

// ─── Item ───

public class CreateItemDto
{
    public string Name { get; set; } = string.Empty;
    public Guid CategoryId { get; set; }
    public string? Brand { get; set; }
    public string? Model { get; set; }
    public string ConditionDescription { get; set; } = string.Empty;
}

public class UpdateItemDto
{
    public string Name { get; set; } = string.Empty;
    public Guid CategoryId { get; set; }
    public string? Brand { get; set; }
    public string? Model { get; set; }
    public string ConditionDescription { get; set; } = string.Empty;
}

public class SelectRouteDto
{
    public string SelectedRoute { get; set; } = string.Empty;
}

public class ItemDto
{
    public Guid Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public Guid CategoryId { get; set; }
    public CategoryDto? Category { get; set; }
    public string? Brand { get; set; }
    public string? Model { get; set; }
    public string ConditionDescription { get; set; } = string.Empty;
    public string Status { get; set; } = string.Empty;
    public string? SelectedRecoveryRoute { get; set; }
    public List<ItemImageDto> Images { get; set; } = new();
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
}

public class ItemImageDto
{
    public Guid Id { get; set; }
    public string ImageUrl { get; set; } = string.Empty;
    public int SortOrder { get; set; }
    public bool IsPrimary { get; set; }
}

public class ItemAssessmentDto
{
    public Guid Id { get; set; }
    public string ConditionLevel { get; set; } = string.Empty;
    public string RecommendedRoute { get; set; } = string.Empty;
    public string? AlternativeRoute { get; set; }
    public string ConfidenceLevel { get; set; } = string.Empty;
    public string Explanation { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; }
}

// ─── Recovery ───

public class CreateRecoveryDto
{
    public Guid ItemId { get; set; }
}

public class RecoveryRequestDto
{
    public Guid Id { get; set; }
    public Guid ItemId { get; set; }
    public ItemDto? Item { get; set; }
    public string SelectedRoute { get; set; } = string.Empty;
    public string Status { get; set; } = string.Empty;
    public DateTime? SubmittedAt { get; set; }
    public RecoveryPlanDto? Plan { get; set; }
    public List<ApprovalDecisionDto> ApprovalDecisions { get; set; } = new();
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
}

public class RecoveryPlanDto
{
    public Guid Id { get; set; }
    public string Suitability { get; set; } = string.Empty;
    public string Summary { get; set; } = string.Empty;
    public string RequiredPartnerType { get; set; } = string.Empty;
    public List<RecoveryPlanStepDto> Steps { get; set; } = new();
    public List<RecoverySafetyNoteDto> SafetyNotes { get; set; } = new();
}

public class RecoveryPlanStepDto
{
    public string StepText { get; set; } = string.Empty;
    public int SortOrder { get; set; }
}

public class RecoverySafetyNoteDto
{
    public string NoteText { get; set; } = string.Empty;
    public int SortOrder { get; set; }
}

public class ApprovalDto
{
    public string Decision { get; set; } = string.Empty; // Approved, Rejected, RevisionRequested
    public string? Reason { get; set; }
}

public class ApprovalDecisionDto
{
    public Guid Id { get; set; }
    public string AdminId { get; set; } = string.Empty;
    public string Decision { get; set; } = string.Empty;
    public string? Reason { get; set; }
    public DateTime DecidedAt { get; set; }
}

public class HandoverPassDto
{
    public Guid RecoveryRequestId { get; set; }
    public string PassReferenceCode { get; set; } = string.Empty;
    public Guid ItemId { get; set; }
    public string ItemName { get; set; } = string.Empty;
    public string CategoryName { get; set; } = string.Empty;
    public string? Brand { get; set; }
    public string? Model { get; set; }
    public string? ConditionDescription { get; set; }
    public string? PrimaryImageUrl { get; set; }
    public string SelectedRoute { get; set; } = string.Empty;
    public string Status { get; set; } = string.Empty;

    // Customer
    public string CustomerName { get; set; } = string.Empty;
    public string? CustomerPhone { get; set; }
    public string? CustomerAddress { get; set; }
    public string? CustomerDistrict { get; set; }
    public string? CustomerTown { get; set; }

    // Preparation Plan & Checklist
    public string? PlanSummary { get; set; }
    public string? RequiredPartnerType { get; set; }
    public List<string> PreparationSteps { get; set; } = new();
    public List<string> SafetyNotes { get; set; } = new();

    // Admin Approval
    public bool IsApproved { get; set; }
    public DateTime? ApprovedAt { get; set; }
    public string? AdminNote { get; set; }

    // Collection Details (if initiated)
    public Guid? CollectionRequestId { get; set; }
    public string? CollectionStatus { get; set; }
    public string? AssignedAgentId { get; set; }
    public string? AssignedAgentName { get; set; }
    public string? PartnerName { get; set; }
    public DateTime? ScheduledPickupDate { get; set; }
    public TimeSpan? ScheduledStartTime { get; set; }
    public TimeSpan? ScheduledEndTime { get; set; }
}

// ─── Partner ───

public class CreatePartnerDto
{
    public string Name { get; set; } = string.Empty;
    public string ContactName { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;
    public string? Phone { get; set; }
    public string ServiceArea { get; set; } = string.Empty;
    public string? OperatingHours { get; set; }
    public int AverageProcessingDays { get; set; } = 1;
    public List<PartnerServiceDto> Services { get; set; } = new();
}

public class UpdatePartnerDto
{
    public string Name { get; set; } = string.Empty;
    public string ContactName { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string? Phone { get; set; }
    public string ServiceArea { get; set; } = string.Empty;
    public string? OperatingHours { get; set; }
    public int AverageProcessingDays { get; set; } = 1;
    public bool IsActive { get; set; }
    public List<PartnerServiceDto> Services { get; set; } = new();
}

public class PartnerDto
{
    public Guid Id { get; set; }
    public string? UserId { get; set; }
    public string Name { get; set; } = string.Empty;
    public string ContactName { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string? Phone { get; set; }
    public string ServiceArea { get; set; } = string.Empty;
    public string? OperatingHours { get; set; }
    public int AverageProcessingDays { get; set; }
    public bool IsActive { get; set; }
    public List<PartnerServiceDto> Services { get; set; } = new();
    public DateTime CreatedAt { get; set; }
}

public class PartnerServiceDto
{
    public string RecoveryRoute { get; set; } = string.Empty;
    public Guid CategoryId { get; set; }
}

public class PartnerMatchDto
{
    public Guid Id { get; set; }
    public Guid PartnerId { get; set; }
    public string PartnerName { get; set; } = string.Empty;
    public int Rank { get; set; }
    public string Reason { get; set; } = string.Empty;
    public string ServiceArea { get; set; } = string.Empty;
    public int AverageProcessingDays { get; set; }
}

// ─── Collection ───

public class CreateCollectionDto
{
    public Guid RecoveryRequestId { get; set; }
    public DateTime PreferredPickupDate { get; set; }
    public TimeSpan PreferredStartTime { get; set; }
    public TimeSpan PreferredEndTime { get; set; }
}

public class AdminAssignCollectionDto
{
    public string AssignedCollectionAgentId { get; set; } = string.Empty;
    public DateTime ScheduledPickupDate { get; set; }
    public TimeSpan ScheduledStartTime { get; set; }
    public TimeSpan ScheduledEndTime { get; set; }
}

public class UpdateCollectionStatusDto
{
    public string Status { get; set; } = string.Empty;
    public string? Note { get; set; }
}

public class RejectCollectionJobDto
{
    public string? Reason { get; set; }
}

public class CollectionRequestDto
{
    public Guid Id { get; set; }
    public Guid RecoveryRequestId { get; set; }
    public Guid PartnerId { get; set; }
    public string PartnerName { get; set; } = string.Empty;
    public string CustomerId { get; set; } = string.Empty;
    public string? CustomerName { get; set; }
    public string? CustomerPhone { get; set; }
    public string? CustomerAddress { get; set; }
    public string? CustomerDistrict { get; set; }
    public string? CustomerTown { get; set; }
    public DateTime? PreferredPickupDate { get; set; }
    public TimeSpan? PreferredStartTime { get; set; }
    public TimeSpan? PreferredEndTime { get; set; }
    public DateTime? SuggestedPickupDate { get; set; }
    public TimeSpan? SuggestedStartTime { get; set; }
    public TimeSpan? SuggestedEndTime { get; set; }
    public string? SuggestedCollectionAgentId { get; set; }
    public DateTime? ScheduledPickupDate { get; set; }
    public TimeSpan? ScheduledStartTime { get; set; }
    public TimeSpan? ScheduledEndTime { get; set; }
    public string? AssignedCollectionAgentId { get; set; }
    public string? AssignedAgentName { get; set; }
    public string Status { get; set; } = string.Empty;
    public string? PartnerPhotoUrl { get; set; }
    public string? PartnerFeedback { get; set; }
    public DateTime? PartnerConfirmedAt { get; set; }
    public bool? PartnerReceivedConditionOk { get; set; }
    public ItemDto? Item { get; set; }
    public List<CollectionStatusHistoryDto> StatusHistory { get; set; } = new();
    public DateTime CreatedAt { get; set; }
}

public class PartnerReceiveDto
{
    public string? Feedback { get; set; }
    public bool ConditionOk { get; set; } = true;
}

public class CollectionStatusHistoryDto
{
    public string Status { get; set; } = string.Empty;
    public string? Note { get; set; }
    public DateTime ChangedAt { get; set; }
}

// ─── Collection Agent ───

public class CreateCollectionAgentDto
{
    public string Name { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;
    public string? Phone { get; set; }
    public string ServiceArea { get; set; } = string.Empty;
    public string? TownArea { get; set; }
}

public class UpdateCollectionAgentDto
{
    public string? Phone { get; set; }
    public string ServiceArea { get; set; } = string.Empty;
    public string? TownArea { get; set; }
    public bool IsAvailable { get; set; }
    public bool IsActive { get; set; }
}

public class CollectionAgentDto
{
    public Guid ProfileId { get; set; }
    public string UserId { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string? Phone { get; set; }
    public string ServiceArea { get; set; } = string.Empty;
    public string? TownArea { get; set; }
    public bool IsAvailable { get; set; }
    public bool IsActive { get; set; }
}

// ─── Workflow ───

public class AgentWorkflowDto
{
    public Guid Id { get; set; }
    public string CustomerId { get; set; } = string.Empty;
    public Guid ItemId { get; set; }
    public string? ItemName { get; set; }
    public string Objective { get; set; } = string.Empty;
    public string CurrentStage { get; set; } = string.Empty;
    public string Status { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; }
    public DateTime? CompletedAt { get; set; }
    public List<AgentWorkflowStepDto> Steps { get; set; } = new();
}

public class AgentWorkflowStepDto
{
    public Guid Id { get; set; }
    public string AgentName { get; set; } = string.Empty;
    public string StepName { get; set; } = string.Empty;
    public string ExecutionStatus { get; set; } = string.Empty;
    public string? InputSummary { get; set; }
    public string? OutputSummary { get; set; }
    public string? ErrorMessage { get; set; }
    public DateTime StartedAt { get; set; }
    public DateTime? CompletedAt { get; set; }
}

// ─── Dashboard ───

public class CustomerDashboardDto
{
    public int TotalItems { get; set; }
    public int PendingRecovery { get; set; }
    public int PartnerSelectionPending { get; set; }
    public int ActiveCollections { get; set; }
    public int CompletedItems { get; set; }
}

public class AdminDashboardDto
{
    public int SubmittedItems { get; set; }
    public int PendingRecoveryApprovals { get; set; }
    public int ActivePartners { get; set; }
    public int CollectionsAwaitingAssignment { get; set; }
    public int ActiveCollections { get; set; }
    public int CompletedRecoveries { get; set; }
}

public class AgentDashboardDto
{
    public int AssignedJobs { get; set; }
    public int TodaysJobs { get; set; }
    public int CompletedJobs { get; set; }
}
