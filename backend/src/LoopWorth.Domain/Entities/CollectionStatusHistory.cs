using LoopWorth.Domain.Enums;

namespace LoopWorth.Domain.Entities;

public class CollectionStatusHistory
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid CollectionRequestId { get; set; }
    public CollectionStatus Status { get; set; }
    public string? ChangedByUserId { get; set; }
    public string? Note { get; set; }
    public DateTime ChangedAt { get; set; } = DateTime.UtcNow;

    public CollectionRequest CollectionRequest { get; set; } = null!;
}
