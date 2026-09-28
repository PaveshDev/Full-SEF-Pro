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
                      ALTER TABLE ""CollectionRequests"" ADD COLUMN IF NOT EXISTS ""PartnerReceivedConditionOk"" boolean;
                      ALTER TABLE ""Items"" ADD COLUMN IF NOT EXISTS ""EcoHazardReportJson"" text;
                      ALTER TABLE ""Items"" ADD COLUMN IF NOT EXISTS ""EcoHazardAcknowledged"" boolean DEFAULT FALSE;
                      ALTER TABLE ""Items"" ADD COLUMN IF NOT EXISTS ""EcoHazardLevel"" text;
                      ALTER TABLE ""RecoveryPlans"" ADD COLUMN IF NOT EXISTS ""ChecklistJson"" text;
                      ALTER TABLE ""RecoveryPlans"" ADD COLUMN IF NOT EXISTS ""IsPreparationVerified"" boolean DEFAULT FALSE;
                      ALTER TABLE ""RecoveryPlans"" ADD COLUMN IF NOT EXISTS ""AdminHandlingInstructions"" text;
                      ALTER TABLE ""ApprovalDecisions"" ADD COLUMN IF NOT EXISTS ""CustomHandlingInstructions"" text;
                      ALTER TABLE ""ApprovalDecisions"" ADD COLUMN IF NOT EXISTS ""OverriddenRoute"" text;
                      ALTER TABLE ""CollectionRequests"" ADD COLUMN IF NOT EXISTS ""DeliveryEmailSent"" boolean DEFAULT FALSE;
                      ALTER TABLE ""CollectionRequests"" ADD COLUMN IF NOT EXISTS ""DeliveryEmailSentAt"" timestamp with time zone;
                      ALTER TABLE ""CollectionRequests"" ADD COLUMN IF NOT EXISTS ""DeliveryEmailSubject"" text;");

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
                        DELETE FROM ""AspNetUserRoles"" WHERE ""UserId"" IN (SELECT ""Id"" FROM ""AspNetUsers"" WHERE ""NormalizedEmail"" NOT IN ('LOOPWORTHADMIN@GMAIL.COM', 'ADMIN@LOOPWORTH.LOCAL'));
                        DELETE FROM ""AspNetUserClaims"" WHERE ""UserId"" IN (SELECT ""Id"" FROM ""AspNetUsers"" WHERE ""NormalizedEmail"" NOT IN ('LOOPWORTHADMIN@GMAIL.COM', 'ADMIN@LOOPWORTH.LOCAL'));
                        DELETE FROM ""AspNetUserLogins"" WHERE ""UserId"" IN (SELECT ""Id"" FROM ""AspNetUsers"" WHERE ""NormalizedEmail"" NOT IN ('LOOPWORTHADMIN@GMAIL.COM', 'ADMIN@LOOPWORTH.LOCAL'));
                        DELETE FROM ""AspNetUserTokens"" WHERE ""UserId"" IN (SELECT ""Id"" FROM ""AspNetUsers"" WHERE ""NormalizedEmail"" NOT IN ('LOOPWORTHADMIN@GMAIL.COM', 'ADMIN@LOOPWORTH.LOCAL'));
                        DELETE FROM ""AspNetUsers"" WHERE ""NormalizedEmail"" NOT IN ('LOOPWORTHADMIN@GMAIL.COM', 'ADMIN@LOOPWORTH.LOCAL');
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

        // Seed & Consolidate Admin: Keep strictly ONE admin with loopworthadmin@gmail.com
        var adminEmail = config["AdminSeed:Email"] ?? Environment.GetEnvironmentVariable("ADMIN_EMAIL") ?? "loopworthadmin@gmail.com";
        var adminPassword = config["AdminSeed:Password"] ?? Environment.GetEnvironmentVariable("ADMIN_PASSWORD") ?? "Admin123!";

        var adminUsers = (await userManager.GetUsersInRoleAsync("Admin")).ToList();

        // Also check if any old admin exists by email or username
        var oldAdminUsers = await context.Users
            .Where(u => u.Email == "admin@loopworth.local" || u.UserName == "admin@loopworth.local")
            .ToListAsync();
        foreach (var oldUser in oldAdminUsers)
        {
            if (!adminUsers.Any(u => u.Id == oldUser.Id))
            {
                adminUsers.Add(oldUser);
            }
        }

        var targetAdmin = await userManager.FindByEmailAsync(adminEmail);

        if (targetAdmin == null)
        {
            if (adminUsers.Count > 0)
            {
                // Edit the existing old admin directly
                targetAdmin = adminUsers[0];
                targetAdmin.Email = adminEmail;
                targetAdmin.NormalizedEmail = userManager.NormalizeEmail(adminEmail);
                targetAdmin.UserName = adminEmail;
                targetAdmin.NormalizedUserName = userManager.NormalizeName(adminEmail);
                targetAdmin.EmailConfirmed = true;
                targetAdmin.PhoneNumber = "0757809030";
                targetAdmin.PhoneNumberConfirmed = true;
                targetAdmin.Address = "No. 45/2, Galle Road";
                targetAdmin.District = "Colombo";
                targetAdmin.Town = "Colombo 03";
                await userManager.UpdateAsync(targetAdmin);

                var token = await userManager.GeneratePasswordResetTokenAsync(targetAdmin);
                await userManager.ResetPasswordAsync(targetAdmin, token, adminPassword);
                logger.LogInformation("Updated old admin user to: {Email}", adminEmail);
            }
            else
            {
                targetAdmin = new ApplicationUser
                {
                    UserName = adminEmail,
                    Email = adminEmail,
                    FullName = "System Admin",
                    PhoneNumber = "0757809030",
                    PhoneNumberConfirmed = true,
                    Address = "No. 45/2, Galle Road",
                    District = "Colombo",
                    Town = "Colombo 03",
                    EmailConfirmed = true
                };
                var result = await userManager.CreateAsync(targetAdmin, adminPassword);
                if (result.Succeeded)
                {
                    await userManager.AddToRoleAsync(targetAdmin, "Admin");
                    logger.LogInformation("Seeded admin user: {Email}", adminEmail);
                }
                else
                {
                    logger.LogWarning("Failed to seed admin: {Errors}",
                        string.Join(", ", result.Errors.Select(e => e.Description)));
                }
            }
        }
        else
        {
            targetAdmin.UserName = adminEmail;
            targetAdmin.NormalizedUserName = userManager.NormalizeName(adminEmail);
            targetAdmin.NormalizedEmail = userManager.NormalizeEmail(adminEmail);
            targetAdmin.EmailConfirmed = true;
            targetAdmin.PhoneNumber = "0757809030";
            targetAdmin.PhoneNumberConfirmed = true;
            targetAdmin.Address = "No. 45/2, Galle Road";
            targetAdmin.District = "Colombo";
            targetAdmin.Town = "Colombo 03";
            await userManager.UpdateAsync(targetAdmin);

            if (!await userManager.IsInRoleAsync(targetAdmin, "Admin"))
            {
                await userManager.AddToRoleAsync(targetAdmin, "Admin");
            }
        }

        // Delete all other admin users so only ONE admin remains in the system
        if (targetAdmin != null)
        {
            var redundantAdmins = adminUsers.Where(u => u.Id != targetAdmin.Id).ToList();
            foreach (var extra in redundantAdmins)
            {
                logger.LogInformation("Removing redundant admin user: {Email} ({Id})", extra.Email, extra.Id);

                var decisions = await context.ApprovalDecisions.Where(d => d.AdminId == extra.Id).ToListAsync();
                foreach (var d in decisions)
                {
                    d.AdminId = targetAdmin.Id;
                }
                await context.SaveChangesAsync();

                await userManager.DeleteAsync(extra);
            }

            // Also clean up any extra users in AspNetUsers that have old admin emails
            var residualOldAdmins = await context.Users
                .Where(u => u.Id != targetAdmin.Id && (u.Email == "admin@loopworth.local" || u.UserName == "admin@loopworth.local"))
                .ToListAsync();
            foreach (var res in residualOldAdmins)
            {
                await userManager.DeleteAsync(res);
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

