using LoopWorth.Domain.Entities;
using LoopWorth.Domain.Enums;
using Xunit;

namespace LoopWorth.UnitTests;

public class ItemTests
{
    [Fact]
    public void NewItem_ShouldHaveDefaultDraftStatus()
    {
        var item = new Item
        {
            Name = "Samsung Galaxy S20",
            CategoryId = Guid.NewGuid(),
            CustomerId = "user-123",
            ConditionDescription = "Broken glass screen, powers on"
        };

        Assert.Equal(ItemStatus.Draft, item.Status);
        Assert.Null(item.SelectedRecoveryRoute);
        Assert.NotEqual(Guid.Empty, item.Id);
    }

    [Fact]
    public void Item_CanSelectRecoveryRoute()
    {
        var item = new Item
        {
            Name = "Dell XPS 13",
            CategoryId = Guid.NewGuid(),
            CustomerId = "user-123",
            Status = ItemStatus.Assessed,
            SelectedRecoveryRoute = RecoveryRoute.Recycle
        };

        Assert.Equal(RecoveryRoute.Recycle, item.SelectedRecoveryRoute);
    }

    [Fact]
    public void ItemAssessment_AssociatesCorrectly()
    {
        var itemId = Guid.NewGuid();
        var assessment = new ItemAssessment
        {
            ItemId = itemId,
            ConditionLevel = ConditionLevel.Fair,
            RecommendedRoute = RecoveryRoute.Donate,
            AlternativeRoute = RecoveryRoute.Recycle,
            ConfidenceLevel = ConfidenceLevel.High,
            Explanation = "Device is operational with minor cosmetic wear."
        };

        Assert.Equal(itemId, assessment.ItemId);
        Assert.Equal(ConditionLevel.Fair, assessment.ConditionLevel);
        Assert.Equal(RecoveryRoute.Donate, assessment.RecommendedRoute);
    }

    [Fact]
    public async Task ItemAssessmentAgent_FlagsCategoryMismatch_WhenPhoneRegisteredAsLaptop()
    {
        var configuration = new Microsoft.Extensions.Configuration.ConfigurationBuilder().Build();
        var logger = Microsoft.Extensions.Logging.Abstractions.NullLogger<LoopWorth.Infrastructure.Agents.ItemAssessmentAgent>.Instance;
        var agent = new LoopWorth.Infrastructure.Agents.ItemAssessmentAgent(new HttpClient(), configuration, logger);

        var item = new Item
        {
            Name = "Iphone 13 pro max",
            Brand = "Apple",
            Model = "Iphone 13 pro max",
            Category = new Category { Name = "Laptop" },
            ConditionDescription = "Rear glass shattered, MagSafe coil exposed"
        };

        var result = await agent.AssessItemAsync(item);

        Assert.False(result.IsCategoryMatch);
        Assert.Equal("Phone", result.DetectedCategory);
        Assert.Contains("phone", result.MismatchReason, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task ItemAssessmentAgent_PassesCategoryConsistency_WhenPhoneRegisteredAsPhone()
    {
        var configuration = new Microsoft.Extensions.Configuration.ConfigurationBuilder().Build();
        var logger = Microsoft.Extensions.Logging.Abstractions.NullLogger<LoopWorth.Infrastructure.Agents.ItemAssessmentAgent>.Instance;
        var agent = new LoopWorth.Infrastructure.Agents.ItemAssessmentAgent(new HttpClient(), configuration, logger);

        var item = new Item
        {
            Name = "Iphone 13 pro max",
            Brand = "Apple",
            Model = "Iphone 13 pro max",
            Category = new Category { Name = "Phone" },
            ConditionDescription = "Rear glass shattered, MagSafe coil exposed"
        };

        var result = await agent.AssessItemAsync(item);

        Assert.True(result.IsCategoryMatch);
        Assert.Null(result.MismatchReason);
    }
}
