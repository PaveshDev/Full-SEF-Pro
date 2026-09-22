namespace LoopWorth.Domain.Entities;

public class ApprovalDecision
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid RecoveryRequestId { get; set; }
    public string AdminId { get; set; } = string.Empty;
    public string Decision { get; set; } = string.Empty; // Approved, Rejected, RevisionRequested
    public string? Reason { get; set; }
    public DateTime DecidedAt { get; set; } = DateTime.UtcNow;

    public RecoveryRequest RecoveryRequest { get; set; } = null!;
}
