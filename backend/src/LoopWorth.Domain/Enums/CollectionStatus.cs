namespace LoopWorth.Domain.Enums;

public enum CollectionStatus
{
    Requested,
    Scheduled,
    AgentAssigned,
    Collected,
    DeliveredToPartner,
    PartnerReceived,
    Completed,
    Cancelled
}
