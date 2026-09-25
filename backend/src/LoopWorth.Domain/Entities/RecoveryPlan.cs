namespace LoopWorth.Domain.Entities;

public class RecoveryPlan
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid RecoveryRequestId { get; set; }
    public string Suitability { get; set; } = string.Empty;
    public string Summary { get; set; } = string.Empty;
    public string RequiredPartnerType { get; set; } = string.Empty;
    public string? ChecklistJson { get; set; }
    public bool IsPreparationVerified { get; set; } = false;
    public string? AdminHandlingInstructions { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    public RecoveryRequest RecoveryRequest { get; set; } = null!;
    public ICollection<RecoveryPlanStep> Steps { get; set; } = new List<RecoveryPlanStep>();
    public ICollection<RecoverySafetyNote> SafetyNotes { get; set; } = new List<RecoverySafetyNote>();
}
