using LoopWorth.Domain.Enums;

namespace LoopWorth.Domain.Entities;

public class PartnerService
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid PartnerId { get; set; }
    public RecoveryRoute RecoveryRoute { get; set; }
    public Guid CategoryId { get; set; }

    public Partner Partner { get; set; } = null!;
    public Category Category { get; set; } = null!;
}
