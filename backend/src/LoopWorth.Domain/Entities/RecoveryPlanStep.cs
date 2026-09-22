namespace LoopWorth.Domain.Entities;

public class RecoveryPlanStep
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid RecoveryPlanId { get; set; }
    public string StepText { get; set; } = string.Empty;
    public int SortOrder { get; set; }

    public RecoveryPlan RecoveryPlan { get; set; } = null!;
}
