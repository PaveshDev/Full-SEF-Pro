using LoopWorth.Domain.Enums;

namespace LoopWorth.Domain.Entities;

public class Item
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string CustomerId { get; set; } = string.Empty;
    public Guid CategoryId { get; set; }
    public string Name { get; set; } = string.Empty;
    public string? Brand { get; set; }
    public string? Model { get; set; }
    public string ConditionDescription { get; set; } = string.Empty;
    public RecoveryRoute? SelectedRecoveryRoute { get; set; }
    public ItemStatus Status { get; set; } = ItemStatus.Draft;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    public Category Category { get; set; } = null!;
    public ICollection<ItemImage> Images { get; set; } = new List<ItemImage>();
    public ICollection<ItemAssessment> Assessments { get; set; } = new List<ItemAssessment>();
}
