using LoopWorth.Domain.Enums;

namespace LoopWorth.Domain.Entities;

public class RecoveryRequest
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid ItemId { get; set; }
    public string CustomerId { get; set; } = string.Empty;
    public RecoveryRoute SelectedRoute { get; set; }
    public RecoveryStatus Status { get; set; } = RecoveryStatus.Draft;
    public DateTime? SubmittedAt { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    public Item Item { get; set; } = null!;
    public RecoveryPlan? Plan { get; set; }
    public ICollection<ApprovalDecision> ApprovalDecisions { get; set; } = new List<ApprovalDecision>();
    public ICollection<PartnerMatch> PartnerMatches { get; set; } = new List<PartnerMatch>();
    public PartnerSelection? PartnerSelection { get; set; }
    public CollectionRequest? CollectionRequest { get; set; }
}
