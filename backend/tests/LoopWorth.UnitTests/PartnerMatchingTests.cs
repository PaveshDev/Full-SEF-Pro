using LoopWorth.Domain.Entities;
using LoopWorth.Domain.Enums;
using Xunit;

namespace LoopWorth.UnitTests;

public class PartnerMatchingTests
{
    [Fact]
    public void Partner_CanConfigureSupportedServices()
    {
        var partner = new Partner
        {
            Name = "Colombo Green Recyclers",
            ContactName = "Sunil",
            Email = "sunil@greenrecyclers.lk",
            ServiceArea = "Colombo",
            AverageProcessingDays = 4,
            IsActive = true
        };

        var catId = Guid.NewGuid();
        partner.Services.Add(new PartnerService
        {
            PartnerId = partner.Id,
            RecoveryRoute = RecoveryRoute.Recycle,
            CategoryId = catId
        });

        Assert.Single(partner.Services);
        Assert.Equal(RecoveryRoute.Recycle, partner.Services.First().RecoveryRoute);
        Assert.Equal(catId, partner.Services.First().CategoryId);
    }

    [Fact]
    public void PartnerMatch_MaintainsRankAndReason()
    {
        var match = new PartnerMatch
        {
            RecoveryRequestId = Guid.NewGuid(),
            PartnerId = Guid.NewGuid(),
            Rank = 1,
            Reason = "Lowest turnaround time and closest facility in Colombo."
        };

        Assert.Equal(1, match.Rank);
        Assert.Contains("Colombo", match.Reason);
    }
}
