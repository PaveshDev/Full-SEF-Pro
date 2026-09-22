using LoopWorth.Domain.Enums;

namespace LoopWorth.Domain.Entities;

public class AgentWorkflow
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string CustomerId { get; set; } = string.Empty;
    public Guid ItemId { get; set; }
    public string Objective { get; set; } = string.Empty;
    public string CurrentStage { get; set; } = string.Empty;
    public string Status { get; set; } = "Pending";
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? CompletedAt { get; set; }

    public Item Item { get; set; } = null!;
    public ICollection<AgentWorkflowStep> Steps { get; set; } = new List<AgentWorkflowStep>();
}
