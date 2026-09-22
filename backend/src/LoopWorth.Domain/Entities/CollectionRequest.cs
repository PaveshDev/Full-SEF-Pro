using LoopWorth.Domain.Enums;

namespace LoopWorth.Domain.Entities;

public class CollectionRequest
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid RecoveryRequestId { get; set; }
    public Guid PartnerId { get; set; }
    public string CustomerId { get; set; } = string.Empty;

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

    public CollectionStatus Status { get; set; } = CollectionStatus.Requested;

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    public string? PartnerPhotoUrl { get; set; }
    public string? PartnerFeedback { get; set; }
    public DateTime? PartnerConfirmedAt { get; set; }
    public bool? PartnerReceivedConditionOk { get; set; }

    public RecoveryRequest RecoveryRequest { get; set; } = null!;
    public Partner Partner { get; set; } = null!;
    public ICollection<CollectionStatusHistory> StatusHistory { get; set; } = new List<CollectionStatusHistory>();
}
