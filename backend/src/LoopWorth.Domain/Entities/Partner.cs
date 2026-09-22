namespace LoopWorth.Domain.Entities;

public class Partner
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string Name { get; set; } = string.Empty;
    public string ContactName { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string? Phone { get; set; }
    public string ServiceArea { get; set; } = string.Empty;
    public string? OperatingHours { get; set; }
    public int AverageProcessingDays { get; set; }
    public bool IsActive { get; set; } = true;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
    public string? UserId { get; set; }

    public ICollection<PartnerService> Services { get; set; } = new List<PartnerService>();
    public ICollection<PartnerMatch> Matches { get; set; } = new List<PartnerMatch>();
}
