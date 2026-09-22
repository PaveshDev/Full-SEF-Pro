using LoopWorth.Domain.Enums;

namespace LoopWorth.Domain.Entities;

public class AgentWorkflowStep
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid WorkflowId { get; set; }
    public string AgentName { get; set; } = string.Empty;
    public string StepName { get; set; } = string.Empty;
    public AgentExecutionStatus ExecutionStatus { get; set; } = AgentExecutionStatus.Pending;
    public string? InputSummary { get; set; }
    public string? OutputSummary { get; set; }
    public string? ValidationStatus { get; set; }
    public string? ErrorMessage { get; set; }
    public DateTime StartedAt { get; set; } = DateTime.UtcNow;
    public DateTime? CompletedAt { get; set; }

    public AgentWorkflow Workflow { get; set; } = null!;
}
