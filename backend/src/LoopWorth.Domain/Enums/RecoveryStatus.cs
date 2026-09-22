namespace LoopWorth.Domain.Enums;

public enum RecoveryStatus
{
    Draft,
    PlanGenerated,
    PendingAdminApproval,
    Approved,
    Rejected,
    RevisionRequested
}
