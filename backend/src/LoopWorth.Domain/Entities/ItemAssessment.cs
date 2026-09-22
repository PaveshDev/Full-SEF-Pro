using LoopWorth.Domain.Enums;

namespace LoopWorth.Domain.Entities;

public class ItemAssessment
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid ItemId { get; set; }
    public ConditionLevel ConditionLevel { get; set; }
    public RecoveryRoute RecommendedRoute { get; set; }
    public RecoveryRoute? AlternativeRoute { get; set; }
    public ConfidenceLevel ConfidenceLevel { get; set; }
    public string Explanation { get; set; } = string.Empty;
    public AgentExecutionStatus ExecutionStatus { get; set; } = AgentExecutionStatus.Pending;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    public Item Item { get; set; } = null!;
}
