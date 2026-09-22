using LoopWorth.Domain.Entities;
using LoopWorth.Domain.Enums;
using Xunit;

namespace LoopWorth.UnitTests;

public class CollectionPlanningTests
{
    [Fact]
    public void CollectionRequest_ProgressesThroughLifecycle()
    {
        var col = new CollectionRequest
        {
            RecoveryRequestId = Guid.NewGuid(),
            PartnerId = Guid.NewGuid(),
            CustomerId = "cust-1",
            Status = CollectionStatus.Requested
        };

        Assert.Equal(CollectionStatus.Requested, col.Status);

        // Transition: AgentAssigned
        col.Status = CollectionStatus.AgentAssigned;
        col.AssignedCollectionAgentId = "agent-1";
        col.StatusHistory.Add(new CollectionStatusHistory
        {
            CollectionRequestId = col.Id,
            Status = CollectionStatus.AgentAssigned,
            Note = "Assigned to driver."
        });

        // Transition: Collected
        col.Status = CollectionStatus.Collected;
        col.StatusHistory.Add(new CollectionStatusHistory
        {
            CollectionRequestId = col.Id,
            Status = CollectionStatus.Collected,
            Note = "Picked up from customer residence."
        });

        // Transition: DeliveredToPartner
        col.Status = CollectionStatus.DeliveredToPartner;
        col.StatusHistory.Add(new CollectionStatusHistory
        {
            CollectionRequestId = col.Id,
            Status = CollectionStatus.DeliveredToPartner,
            Note = "Delivered to recycling facility."
        });

        // Transition: Completed
        col.Status = CollectionStatus.Completed;
        col.StatusHistory.Add(new CollectionStatusHistory
        {
            CollectionRequestId = col.Id,
            Status = CollectionStatus.Completed,
            Note = "Partner verified delivery."
        });

        Assert.Equal(CollectionStatus.Completed, col.Status);
        Assert.Equal(4, col.StatusHistory.Count);
    }
}
