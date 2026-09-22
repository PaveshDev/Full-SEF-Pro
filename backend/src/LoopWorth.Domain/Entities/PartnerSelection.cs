namespace LoopWorth.Domain.Entities;

public class PartnerSelection
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid RecoveryRequestId { get; set; }
    public Guid PartnerId { get; set; }
    public string CustomerId { get; set; } = string.Empty;
    public DateTime SelectedAt { get; set; } = DateTime.UtcNow;

    public RecoveryRequest RecoveryRequest { get; set; } = null!;
    public Partner Partner { get; set; } = null!;
}
