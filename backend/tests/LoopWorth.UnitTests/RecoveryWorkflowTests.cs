using LoopWorth.Domain.Entities;
using LoopWorth.Domain.Enums;
using Xunit;

namespace LoopWorth.UnitTests;

public class RecoveryWorkflowTests
{
    [Fact]
    public void RecoveryRequest_DefaultStatusIsDraft()
    {
        var recovery = new RecoveryRequest
        {
            ItemId = Guid.NewGuid(),
            CustomerId = "user-123",
            SelectedRoute = RecoveryRoute.Recycle
        };

        Assert.Equal(RecoveryStatus.Draft, recovery.Status);
        Assert.Equal(RecoveryRoute.Recycle, recovery.SelectedRoute);
    }

    [Fact]
    public void ApprovalDecision_RecordsAdminAction()
    {
        var recoveryId = Guid.NewGuid();
        var adminId = "admin-user";

        var decision = new ApprovalDecision
        {
            RecoveryRequestId = recoveryId,
            AdminId = adminId,
            Decision = "Approved",
            Reason = "All preparation guidelines satisfied."
        };

        Assert.Equal(recoveryId, decision.RecoveryRequestId);
        Assert.Equal(adminId, decision.AdminId);
        Assert.Equal("Approved", decision.Decision);
        Assert.NotNull(decision.Reason);
    }

    [Fact]
    public void RecoveryPlan_SupportsStepsAndSafetyNotes()
    {
        var plan = new RecoveryPlan
        {
            RecoveryRequestId = Guid.NewGuid(),
            Suitability = "High",
            Summary = "Prepare phone for material separation.",
            RequiredPartnerType = "Certified E-Waste Recycler"
        };

        plan.Steps.Add(new RecoveryPlanStep
        {
            RecoveryPlanId = plan.Id,
            StepText = "Remove SIM tray and any micro-SD cards.",
            SortOrder = 1
        });

        plan.SafetyNotes.Add(new RecoverySafetyNote
        {
            RecoveryPlanId = plan.Id,
            NoteText = "Check battery for swelling before transit.",
            SortOrder = 1
        });

        Assert.Single(plan.Steps);
        Assert.Single(plan.SafetyNotes);
        Assert.Equal("Remove SIM tray and any micro-SD cards.", plan.Steps.First().StepText);
    }

    [Fact]
    public async Task RecoveryPlanningAgent_GeneratesTailoredPlan_ForLaptop()
    {
        var config = new Microsoft.Extensions.Configuration.ConfigurationBuilder().Build();
        var logger = Microsoft.Extensions.Logging.Abstractions.NullLogger<LoopWorth.Infrastructure.Agents.RecoveryPlanningAgent>.Instance;
        var agent = new LoopWorth.Infrastructure.Agents.RecoveryPlanningAgent(new HttpClient(), config, logger);

        var item = new Item
        {
            Name = "Asus zenbook q420",
            Brand = "ASUS",
            Model = "Q420",
            Category = new Category { Name = "Laptop" },
            ConditionDescription = "Swollen battery causing trackpad to lift, cracked hinge, shuts down after 2 minutes"
        };

        var assessment = new ItemAssessment
        {
            ItemId = item.Id,
            ConditionLevel = ConditionLevel.Poor,
            RecommendedRoute = RecoveryRoute.Recycle,
            Explanation = "Severe battery and hinge damage makes repair unfeasible."
        };

        var plan = await agent.GeneratePlanAsync(item, assessment, RecoveryRoute.Recycle);

        Assert.NotNull(plan);
        Assert.Contains("laptop", plan.Summary, StringComparison.OrdinalIgnoreCase);
        // Ensure laptop plan does NOT contain mobile-specific SIM instructions
        Assert.DoesNotContain(plan.PreparationSteps, s => s.Contains("SIM card", StringComparison.OrdinalIgnoreCase));
        // Ensure laptop plan contains peripheral or adapter instructions
        Assert.Contains(plan.PreparationSteps, s => s.Contains("peripheral", StringComparison.OrdinalIgnoreCase) || s.Contains("adapter", StringComparison.OrdinalIgnoreCase) || s.Contains("dongle", StringComparison.OrdinalIgnoreCase) || s.Contains("lid", StringComparison.OrdinalIgnoreCase));
        // Ensure safety notes address battery swelling hazard
        Assert.Contains(plan.SafetyNotes, s => s.Contains("battery", StringComparison.OrdinalIgnoreCase));

        // Ensure checklist is tailored specifically for Laptop
        Assert.NotNull(plan.Checklist);
        Assert.NotEmpty(plan.Checklist);
        Assert.DoesNotContain(plan.Checklist, c => c.Description.Contains("Google FRP", StringComparison.OrdinalIgnoreCase));
        Assert.DoesNotContain(plan.Checklist, c => c.Description.Contains("physical SIM", StringComparison.OrdinalIgnoreCase));
        Assert.Contains(plan.Checklist, c => c.Title.Contains("Drive Wipe", StringComparison.OrdinalIgnoreCase) || c.Description.Contains("BitLocker", StringComparison.OrdinalIgnoreCase));
        Assert.Contains(plan.Checklist, c => c.Description.Contains("dongle", StringComparison.OrdinalIgnoreCase) || c.Title.Contains("Storage & Dongles", StringComparison.OrdinalIgnoreCase));
        Assert.Contains(plan.Checklist, c => c.Title.Contains("Laptop Packaging", StringComparison.OrdinalIgnoreCase));
    }

    [Fact]
    public async Task RecoveryPlanningAgent_GeneratesTailoredPlan_ForPhone()
    {
        var config = new Microsoft.Extensions.Configuration.ConfigurationBuilder().Build();
        var logger = Microsoft.Extensions.Logging.Abstractions.NullLogger<LoopWorth.Infrastructure.Agents.RecoveryPlanningAgent>.Instance;
        var agent = new LoopWorth.Infrastructure.Agents.RecoveryPlanningAgent(new HttpClient(), config, logger);

        var item = new Item
        {
            Name = "iPhone 13 Pro Max",
            Brand = "Apple",
            Model = "iPhone 13 Pro Max",
            Category = new Category { Name = "Phone" },
            ConditionDescription = "Shattered rear glass, screen working"
        };

        var assessment = new ItemAssessment
        {
            ItemId = item.Id,
            ConditionLevel = ConditionLevel.Poor,
            RecommendedRoute = RecoveryRoute.Recycle,
            Explanation = "Rear chassis severely shattered."
        };

        var plan = await agent.GeneratePlanAsync(item, assessment, RecoveryRoute.Recycle);

        Assert.NotNull(plan);
        Assert.Contains(plan.PreparationSteps, s => s.Contains("SIM", StringComparison.OrdinalIgnoreCase));
        Assert.Contains(plan.SafetyNotes, s => s.Contains("glass", StringComparison.OrdinalIgnoreCase));

        // Ensure checklist is tailored specifically for Phone
        Assert.NotNull(plan.Checklist);
        Assert.NotEmpty(plan.Checklist);
        Assert.Contains(plan.Checklist, c => c.Description.Contains("SIM", StringComparison.OrdinalIgnoreCase));
        Assert.Contains(plan.Checklist, c => c.Description.Contains("Google FRP", StringComparison.OrdinalIgnoreCase) || c.Description.Contains("iCloud", StringComparison.OrdinalIgnoreCase));
    }
}
