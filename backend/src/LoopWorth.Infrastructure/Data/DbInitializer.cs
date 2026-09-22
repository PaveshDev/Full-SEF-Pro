using LoopWorth.Domain.Entities;
using LoopWorth.Domain.Enums;
using LoopWorth.Infrastructure.Identity;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;

namespace LoopWorth.Infrastructure.Data;

public static class DbInitializer
{
    public static async Task SeedAsync(IServiceProvider serviceProvider)
    {
        var logger = serviceProvider.GetRequiredService<ILogger<AppDbContext>>();
        var roleManager = serviceProvider.GetRequiredService<RoleManager<IdentityRole>>();
        var userManager = serviceProvider.GetRequiredService<UserManager<ApplicationUser>>();
        var context = serviceProvider.GetRequiredService<AppDbContext>();
        var config = serviceProvider.GetRequiredService<IConfiguration>();

        // Ensure PostgreSQL schema columns exist and handle clean slate purge
        if (context.Database.IsRelational())
        {
            try
            {
                await context.Database.ExecuteSqlRawAsync(
                    @"ALTER TABLE ""AspNetUsers"" ADD COLUMN IF NOT EXISTS ""Address"" text;
                      ALTER TABLE ""AspNetUsers"" ADD COLUMN IF NOT EXISTS ""District"" text;
                      ALTER TABLE ""AspNetUsers"" ADD COLUMN IF NOT EXISTS ""Town"" text;
                      ALTER TABLE ""CollectionAgentProfiles"" ADD COLUMN IF NOT EXISTS ""TownArea"" text;
                      ALTER TABLE ""Partners"" ADD COLUMN IF NOT EXISTS ""UserId"" text;
                      ALTER TABLE ""CollectionRequests"" ADD COLUMN IF NOT EXISTS ""PartnerPhotoUrl"" text;
                      ALTER TABLE ""CollectionRequests"" ADD COLUMN IF NOT EXISTS ""PartnerFeedback"" text;
                      ALTER TABLE ""CollectionRequests"" ADD COLUMN IF NOT EXISTS ""PartnerConfirmedAt"" timestamp with time zone;
                      ALTER TABLE ""CollectionRequests"" ADD COLUMN IF NOT EXISTS ""PartnerReceivedConditionOk"" boolean;");

                // Check for clean slate purge trigger
                var triggerFile1 = Path.Combine(Directory.GetCurrentDirectory(), "purge_database.trigger");
                var triggerFile2 = Path.Combine(AppContext.BaseDirectory, "purge_database.trigger");
                var shouldPurge = Environment.GetEnvironmentVariable("PURGE_DB") == "true"
                    || File.Exists(triggerFile1)
                    || File.Exists(triggerFile2);

                if (shouldPurge)
                {
                    logger.LogWarning("Clean slate database purge triggered! Purging all items, requests, partners, agents and non-admin users...");
                    await context.Database.ExecuteSqlRawAsync(@"
                        TRUNCATE TABLE ""CollectionStatusHistories"", ""CollectionRequests"", ""CollectionAgentProfiles"", ""PartnerSelections"", ""PartnerMatches"", ""PartnerServices"", ""Partners"", ""ApprovalDecisions"", ""RecoverySafetyNotes"", ""RecoveryPlanSteps"", ""RecoveryPlans"", ""RecoveryRequests"", ""ItemAssessments"", ""ItemImages"", ""AgentWorkflowSteps"", ""AgentWorkflows"", ""Items"" CASCADE;
                        DELETE FROM ""AspNetUserRoles"" WHERE ""UserId"" IN (SELECT ""Id"" FROM ""AspNetUsers"" WHERE ""NormalizedEmail"" != 'ADMIN@LOOPWORTH.LOCAL');
                        DELETE FROM ""AspNetUserClaims"" WHERE ""UserId"" IN (SELECT ""Id"" FROM ""AspNetUsers"" WHERE ""NormalizedEmail"" != 'ADMIN@LOOPWORTH.LOCAL');
                        DELETE FROM ""AspNetUserLogins"" WHERE ""UserId"" IN (SELECT ""Id"" FROM ""AspNetUsers"" WHERE ""NormalizedEmail"" != 'ADMIN@LOOPWORTH.LOCAL');
                        DELETE FROM ""AspNetUserTokens"" WHERE ""UserId"" IN (SELECT ""Id"" FROM ""AspNetUsers"" WHERE ""NormalizedEmail"" != 'ADMIN@LOOPWORTH.LOCAL');
                        DELETE FROM ""AspNetUsers"" WHERE ""NormalizedEmail"" != 'ADMIN@LOOPWORTH.LOCAL';
                    ");

                    if (File.Exists(triggerFile1))
                    {
                        try { File.Delete(triggerFile1); } catch { }
                    }
                    if (File.Exists(triggerFile2))
                    {
                        try { File.Delete(triggerFile2); } catch { }
                    }
                    logger.LogInformation("Database purge successfully completed.");
                }
            }
            catch (Exception ex)
            {
                logger.LogWarning(ex, "Could not run schema check or database purge.");
            }
        }

        // Seed Roles
        string[] roles = { "Customer", "Admin", "CollectionAgent", "Partner" };
        foreach (var role in roles)
        {
            if (!await roleManager.RoleExistsAsync(role))
            {
                await roleManager.CreateAsync(new IdentityRole(role));
                logger.LogInformation("Seeded role: {Role}", role);
            }
        }

        // Seed Admin
        var adminEmail = config["AdminSeed:Email"] ?? "admin@loopworth.local";
        var adminPassword = config["AdminSeed:Password"] ?? "Admin123!";
        if (await userManager.FindByEmailAsync(adminEmail) == null)
        {
            var admin = new ApplicationUser
            {
                UserName = adminEmail,
                Email = adminEmail,
                FullName = "System Admin",
                EmailConfirmed = true
            };
            var result = await userManager.CreateAsync(admin, adminPassword);
            if (result.Succeeded)
            {
                await userManager.AddToRoleAsync(admin, "Admin");
                logger.LogInformation("Seeded admin user: {Email}", adminEmail);
            }
            else
            {
                logger.LogWarning("Failed to seed admin: {Errors}",
                    string.Join(", ", result.Errors.Select(e => e.Description)));
            }
        }

        // Seed Categories
        if (!await context.Categories.AnyAsync())
        {
            var categories = new List<Category>
            {
                new() { Code = "PHONE", Name = "Phone" },
                new() { Code = "LAPTOP", Name = "Laptop" },
                new() { Code = "TABLET", Name = "Tablet" },
                new() { Code = "SMALL_ELECTRONICS", Name = "Small Electronics" },
                new() { Code = "COMPUTER_ACCESSORIES", Name = "Computer Accessories" },
                new() { Code = "HOME_ELECTRONICS", Name = "Home Electronics" },
            };
            context.Categories.AddRange(categories);
            await context.SaveChangesAsync();
            logger.LogInformation("Seeded {Count} categories", categories.Count);
        }
    }
}

