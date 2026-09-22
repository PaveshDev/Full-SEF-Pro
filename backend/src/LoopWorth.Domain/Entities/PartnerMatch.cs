namespace LoopWorth.Domain.Entities;

public class PartnerMatch
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid RecoveryRequestId { get; set; }
    public Guid PartnerId { get; set; }
    public int Rank { get; set; }
    public string Reason { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    public RecoveryRequest RecoveryRequest { get; set; } = null!;
    public Partner Partner { get; set; } = null!;
}
