using LoopWorth.Domain.Entities;
using LoopWorth.Domain.Enums;
using LoopWorth.Infrastructure.Identity;
using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage.ValueConversion;

namespace LoopWorth.Infrastructure.Data;

public class AppDbContext : IdentityDbContext<ApplicationUser>
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }

    public DbSet<Category> Categories => Set<Category>();
    public DbSet<Item> Items => Set<Item>();
    public DbSet<ItemImage> ItemImages => Set<ItemImage>();
    public DbSet<ItemAssessment> ItemAssessments => Set<ItemAssessment>();
    public DbSet<RecoveryRequest> RecoveryRequests => Set<RecoveryRequest>();
    public DbSet<RecoveryPlan> RecoveryPlans => Set<RecoveryPlan>();
    public DbSet<RecoveryPlanStep> RecoveryPlanSteps => Set<RecoveryPlanStep>();
    public DbSet<RecoverySafetyNote> RecoverySafetyNotes => Set<RecoverySafetyNote>();
    public DbSet<ApprovalDecision> ApprovalDecisions => Set<ApprovalDecision>();
    public DbSet<Partner> Partners => Set<Partner>();
    public DbSet<PartnerService> PartnerServices => Set<PartnerService>();
    public DbSet<PartnerMatch> PartnerMatches => Set<PartnerMatch>();
    public DbSet<PartnerSelection> PartnerSelections => Set<PartnerSelection>();
    public DbSet<CollectionAgentProfile> CollectionAgentProfiles => Set<CollectionAgentProfile>();
    public DbSet<CollectionRequest> CollectionRequests => Set<CollectionRequest>();
    public DbSet<CollectionStatusHistory> CollectionStatusHistories => Set<CollectionStatusHistory>();
    public DbSet<AgentWorkflow> AgentWorkflows => Set<AgentWorkflow>();
    public DbSet<AgentWorkflowStep> AgentWorkflowSteps => Set<AgentWorkflowStep>();

    protected override void OnModelCreating(ModelBuilder builder)
    {
        base.OnModelCreating(builder);

        // Safe Enum conversions that gracefully handle historical/legacy values (e.g. 'Reuse') without crashing
        var routeConverter = new ValueConverter<RecoveryRoute, string>(
            v => v.ToString(),
            v => ParseRoute(v)
        );

        var nullableRouteConverter = new ValueConverter<RecoveryRoute?, string?>(
            v => v.HasValue ? v.Value.ToString() : null,
            v => ParseNullableRoute(v)
        );

        // ─── Category ───
        builder.Entity<Category>(e =>
        {
            e.HasKey(c => c.Id);
            e.HasIndex(c => c.Code).IsUnique();
            e.Property(c => c.Code).HasMaxLength(50);
            e.Property(c => c.Name).HasMaxLength(100);
        });

        // ─── Item ───
        builder.Entity<Item>(e =>
        {
            e.HasKey(i => i.Id);
            e.HasIndex(i => i.CustomerId);
            e.HasIndex(i => i.CategoryId);
            e.HasIndex(i => i.Status);
            e.Property(i => i.Name).HasMaxLength(200);
            e.Property(i => i.Brand).HasMaxLength(100);
            e.Property(i => i.Model).HasMaxLength(100);
            e.Property(i => i.ConditionDescription).HasMaxLength(2000);
            e.Property(i => i.Status).HasConversion<string>().HasMaxLength(30);
            e.Property(i => i.SelectedRecoveryRoute).HasConversion(nullableRouteConverter).HasMaxLength(30);
            e.HasOne(i => i.Category)
             .WithMany(c => c.Items)
             .HasForeignKey(i => i.CategoryId)
             .OnDelete(DeleteBehavior.Restrict);
        });

        // ─── ItemImage ───
        builder.Entity<ItemImage>(e =>
        {
            e.HasKey(i => i.Id);
            e.Property(i => i.ImageUrl).HasMaxLength(500);
            e.HasOne(i => i.Item)
             .WithMany(i => i.Images)
             .HasForeignKey(i => i.ItemId)
             .OnDelete(DeleteBehavior.Cascade);
        });

        // ─── ItemAssessment ───
        builder.Entity<ItemAssessment>(e =>
        {
            e.HasKey(a => a.Id);
            e.Property(a => a.ConditionLevel).HasConversion<string>().HasMaxLength(30);
            e.Property(a => a.RecommendedRoute).HasConversion(routeConverter).HasMaxLength(30);
            e.Property(a => a.AlternativeRoute).HasConversion(nullableRouteConverter).HasMaxLength(30);
            e.Property(a => a.ConfidenceLevel).HasConversion<string>().HasMaxLength(30);
            e.Property(a => a.ExecutionStatus).HasConversion<string>().HasMaxLength(30);
            e.Property(a => a.Explanation).HasMaxLength(2000);
            e.HasOne(a => a.Item)
             .WithMany(i => i.Assessments)
             .HasForeignKey(a => a.ItemId)
             .OnDelete(DeleteBehavior.Cascade);
        });

        // ─── RecoveryRequest ───
        builder.Entity<RecoveryRequest>(e =>
        {
            e.HasKey(r => r.Id);
            e.HasIndex(r => r.CustomerId);
            e.HasIndex(r => r.ItemId);
            e.HasIndex(r => r.Status);
            e.Property(r => r.SelectedRoute).HasConversion(routeConverter).HasMaxLength(30);
            e.Property(r => r.Status).HasConversion<string>().HasMaxLength(30);
            e.HasOne(r => r.Item)
             .WithMany()
             .HasForeignKey(r => r.ItemId)
             .OnDelete(DeleteBehavior.Restrict);
        });

        // ─── RecoveryPlan ───
        builder.Entity<RecoveryPlan>(e =>
        {
            e.HasKey(p => p.Id);
            e.Property(p => p.Suitability).HasMaxLength(500);
            e.Property(p => p.Summary).HasMaxLength(2000);
            e.Property(p => p.RequiredPartnerType).HasMaxLength(200);
            e.HasOne(p => p.RecoveryRequest)
             .WithOne(r => r.Plan)
             .HasForeignKey<RecoveryPlan>(p => p.RecoveryRequestId)
             .OnDelete(DeleteBehavior.Cascade);
        });

        // ─── RecoveryPlanStep ───
        builder.Entity<RecoveryPlanStep>(e =>
        {
            e.HasKey(s => s.Id);
            e.Property(s => s.StepText).HasMaxLength(1000);
            e.HasOne(s => s.RecoveryPlan)
             .WithMany(p => p.Steps)
             .HasForeignKey(s => s.RecoveryPlanId)
             .OnDelete(DeleteBehavior.Cascade);
        });

        // ─── RecoverySafetyNote ───
        builder.Entity<RecoverySafetyNote>(e =>
        {
            e.HasKey(n => n.Id);
            e.Property(n => n.NoteText).HasMaxLength(1000);
            e.HasOne(n => n.RecoveryPlan)
             .WithMany(p => p.SafetyNotes)
             .HasForeignKey(n => n.RecoveryPlanId)
             .OnDelete(DeleteBehavior.Cascade);
        });

        // ─── ApprovalDecision ───
        builder.Entity<ApprovalDecision>(e =>
        {
            e.HasKey(d => d.Id);
            e.Property(d => d.Decision).HasMaxLength(30);
            e.Property(d => d.Reason).HasMaxLength(2000);
            e.HasOne(d => d.RecoveryRequest)
             .WithMany(r => r.ApprovalDecisions)
             .HasForeignKey(d => d.RecoveryRequestId)
             .OnDelete(DeleteBehavior.Cascade);
        });

        // ─── Partner ───
        builder.Entity<Partner>(e =>
        {
            e.HasKey(p => p.Id);
            e.HasIndex(p => p.IsActive);
            e.Property(p => p.Name).HasMaxLength(200);
            e.Property(p => p.ContactName).HasMaxLength(200);
            e.Property(p => p.Email).HasMaxLength(200);
            e.Property(p => p.Phone).HasMaxLength(30);
            e.Property(p => p.ServiceArea).HasMaxLength(200);
            e.Property(p => p.OperatingHours).HasMaxLength(200);
        });

        // ─── PartnerService ───
        builder.Entity<PartnerService>(e =>
        {
            e.HasKey(s => s.Id);
            e.HasIndex(s => s.RecoveryRoute);
            e.HasIndex(s => s.CategoryId);
            e.Property(s => s.RecoveryRoute).HasConversion(routeConverter).HasMaxLength(30);
            e.HasOne(s => s.Partner)
             .WithMany(p => p.Services)
             .HasForeignKey(s => s.PartnerId)
             .OnDelete(DeleteBehavior.Cascade);
            e.HasOne(s => s.Category)
             .WithMany(c => c.PartnerServices)
             .HasForeignKey(s => s.CategoryId)
             .OnDelete(DeleteBehavior.Restrict);
        });

        // ─── PartnerMatch ───
        builder.Entity<PartnerMatch>(e =>
        {
            e.HasKey(m => m.Id);
            e.HasIndex(m => m.RecoveryRequestId);
            e.Property(m => m.Reason).HasMaxLength(1000);
            e.HasOne(m => m.RecoveryRequest)
             .WithMany(r => r.PartnerMatches)
             .HasForeignKey(m => m.RecoveryRequestId)
             .OnDelete(DeleteBehavior.Cascade);
            e.HasOne(m => m.Partner)
             .WithMany(p => p.Matches)
             .HasForeignKey(m => m.PartnerId)
             .OnDelete(DeleteBehavior.Restrict);
        });

        // ─── PartnerSelection ───
        builder.Entity<PartnerSelection>(e =>
        {
            e.HasKey(s => s.Id);
            e.HasIndex(s => s.RecoveryRequestId).IsUnique();
            e.HasOne(s => s.RecoveryRequest)
             .WithOne(r => r.PartnerSelection)
             .HasForeignKey<PartnerSelection>(s => s.RecoveryRequestId)
             .OnDelete(DeleteBehavior.Cascade);
            e.HasOne(s => s.Partner)
             .WithMany()
             .HasForeignKey(s => s.PartnerId)
             .OnDelete(DeleteBehavior.Restrict);
        });

        // ─── CollectionAgentProfile ───
        builder.Entity<CollectionAgentProfile>(e =>
        {
            e.HasKey(p => p.Id);
            e.HasIndex(p => p.UserId).IsUnique();
            e.Property(p => p.Phone).HasMaxLength(30);
            e.Property(p => p.ServiceArea).HasMaxLength(200);
            e.Property(p => p.TownArea).HasMaxLength(200);
        });

        // ─── CollectionRequest ───
        builder.Entity<CollectionRequest>(e =>
        {
            e.HasKey(r => r.Id);
            e.HasIndex(r => r.CustomerId);
            e.HasIndex(r => r.AssignedCollectionAgentId);
            e.HasIndex(r => r.Status);
            e.Property(r => r.Status).HasConversion<string>().HasMaxLength(30);
            e.HasOne(r => r.RecoveryRequest)
             .WithOne(rr => rr.CollectionRequest)
             .HasForeignKey<CollectionRequest>(r => r.RecoveryRequestId)
             .OnDelete(DeleteBehavior.Restrict);
            e.HasOne(r => r.Partner)
             .WithMany()
             .HasForeignKey(r => r.PartnerId)
             .OnDelete(DeleteBehavior.Restrict);
        });

        // ─── CollectionStatusHistory ───
        builder.Entity<CollectionStatusHistory>(e =>
        {
            e.HasKey(h => h.Id);
            e.Property(h => h.Id).ValueGeneratedNever();
            e.HasIndex(h => h.CollectionRequestId);
            e.Property(h => h.Status).HasConversion<string>().HasMaxLength(30);
            e.Property(h => h.Note).HasMaxLength(1000);
            e.HasOne(h => h.CollectionRequest)
             .WithMany(r => r.StatusHistory)
             .HasForeignKey(h => h.CollectionRequestId)
             .OnDelete(DeleteBehavior.Cascade);
        });

        // ─── AgentWorkflow ───
        builder.Entity<AgentWorkflow>(e =>
        {
            e.HasKey(w => w.Id);
            e.Property(w => w.Objective).HasMaxLength(500);
            e.Property(w => w.CurrentStage).HasMaxLength(100);
            e.Property(w => w.Status).HasMaxLength(30);
            e.HasOne(w => w.Item)
             .WithMany()
             .HasForeignKey(w => w.ItemId)
             .OnDelete(DeleteBehavior.Restrict);
        });

        // ─── AgentWorkflowStep ───
        builder.Entity<AgentWorkflowStep>(e =>
        {
            e.HasKey(s => s.Id);
            e.HasIndex(s => s.WorkflowId);
            e.Property(s => s.AgentName).HasMaxLength(100);
            e.Property(s => s.StepName).HasMaxLength(100);
            e.Property(s => s.ExecutionStatus).HasConversion<string>().HasMaxLength(30);
            e.Property(s => s.InputSummary).HasMaxLength(4000);
            e.Property(s => s.OutputSummary).HasMaxLength(4000);
            e.Property(s => s.ValidationStatus).HasMaxLength(30);
            e.Property(s => s.ErrorMessage).HasMaxLength(2000);
            e.HasOne(s => s.Workflow)
             .WithMany(w => w.Steps)
             .HasForeignKey(s => s.WorkflowId)
             .OnDelete(DeleteBehavior.Cascade);
        });
    }

    private static RecoveryRoute ParseRoute(string? v)
    {
        if (string.IsNullOrWhiteSpace(v)) return RecoveryRoute.Donate;
        return Enum.TryParse<RecoveryRoute>(v, true, out var route) ? route : RecoveryRoute.Donate;
    }

    private static RecoveryRoute? ParseNullableRoute(string? v)
    {
        if (string.IsNullOrWhiteSpace(v)) return null;
        return Enum.TryParse<RecoveryRoute>(v, true, out var route) ? route : RecoveryRoute.Donate;
    }
}
