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

        // Seed Collection Agents — only when explicitly enabled via configuration or environment variable
        if (config.GetValue<bool>("SeedCollectionAgents", false) || Environment.GetEnvironmentVariable("SEED_COLLECTION_AGENTS") == "true")
        {
            var districtAgents = new (string District, string Town, string Agent1Name, string Agent1Phone, string Agent2Name, string Agent2Phone)[]
            {
                ("Colombo",        "Colombo 03",      "Kasun Perera",         "0771000001", "Nadeesha Silva",        "0771000002"),
                ("Gampaha",        "Negombo",          "Ruwan Jayawardena",    "0772000001", "Dilini Fernando",       "0772000002"),
                ("Kalutara",       "Panadura",         "Chamara Bandara",      "0773000001", "Iresha Kumari",         "0773000002"),
                ("Kandy",          "Peradeniya",       "Nuwan Rathnayake",     "0774000001", "Sachini Weerasinghe",   "0774000002"),
                ("Matale",         "Dambulla",         "Tharindu Herath",      "0775000001", "Kumari Dissanayake",    "0775000002"),
                ("Nuwara Eliya",   "Hatton",           "Saman Wijesinghe",     "0776000001", "Ruwanthi Perera",       "0776000002"),
                ("Galle",          "Galle Fort",       "Lakmal de Silva",      "0777000001", "Harshani Gunasekara",   "0777000002"),
                ("Matara",         "Weligama",         "Prasad Wickramasinghe","0778000001", "Nimesha Ranasinghe",    "0778000002"),
                ("Hambantota",     "Tangalle",         "Asanka Rajapaksha",    "0779000001", "Sanduni Jayasuriya",    "0779000002"),
                ("Jaffna",         "Nallur",           "Kumaran Selvarajah",   "0710000001", "Thushara Nadarajah",    "0710000002"),
                ("Kilinochchi",    "Kilinochchi Town", "Pradeep Rajaratnam",   "0711000001", "Kavitha Shanmuganathan","0711000002"),
                ("Mannar",         "Mannar Town",      "Dinesh Kumaraswamy",   "0712000001", "Malini Thirunavukkarasu","0712000002"),
                ("Vavuniya",       "Vavuniya Town",    "Suresh Pathmanathan",  "0713000001", "Deepa Sivanesanathan",  "0713000002"),
                ("Mullaitivu",     "Mullaitivu Town",  "Arun Ganeshalingam",   "0714000001", "Priya Balachandran",    "0714000002"),
                ("Batticaloa",     "Batticaloa Town",  "Ramesh Yogarajah",     "0715000001", "Shamila Muralitharan",  "0715000002"),
                ("Ampara",         "Kalmunai",         "Mohamed Farook",       "0716000001", "Fathima Rizna",         "0716000002"),
                ("Trincomalee",    "Trincomalee Town", "Kamal Jeyaratnam",     "0717000001", "Nishanthi Wickremaratne","0717000002"),
                ("Kurunegala",     "Kurunegala Town",  "Ajith Samaraweera",    "0718000001", "Gayani Ekanayake",      "0718000002"),
                ("Puttalam",       "Chilaw",           "Isuru Seneviratne",    "0719000001", "Chathurika Amarasinghe","0719000002"),
                ("Anuradhapura",   "Anuradhapura Town","Mahesh Liyanage",      "0720000001", "Nadeeka Karunaratne",   "0720000002"),
                ("Polonnaruwa",    "Kaduruwela",       "Lasantha Gunawardena", "0721000001", "Hiruni Samarasekara",   "0721000002"),
                ("Badulla",        "Bandarawela",      "Chathura Madushan",    "0722000001", "Sewwandi Abeysinghe",   "0722000002"),
                ("Monaragala",     "Wellawaya",        "Dilan Priyankara",     "0723000001", "Anusha Madushani",      "0723000002"),
                ("Ratnapura",      "Ratnapura Town",   "Sampath Wimalasena",   "0724000001", "Thilini Jayaweera",     "0724000002"),
                ("Kegalle",        "Mawanella",        "Indika Pathirana",     "0725000001", "Nethmi Gunatilake",     "0725000002"),
            };

            int seededAgentCount = 0;
            foreach (var (district, town, agent1Name, agent1Phone, agent2Name, agent2Phone) in districtAgents)
            {
                var agents = new[]
                {
                    (Name: agent1Name, Phone: agent1Phone, Index: 1),
                    (Name: agent2Name, Phone: agent2Phone, Index: 2),
                };

                foreach (var agent in agents)
                {
                    var emailSlug = agent.Name.ToLowerInvariant().Replace(" ", ".").Replace("'", "");
                    var email = $"{emailSlug}@loopworth.local";
                    var existingUser = await userManager.FindByEmailAsync(email);
                    if (existingUser != null) continue;

                    var user = new ApplicationUser
                    {
                        UserName = email,
                        Email = email,
                        FullName = agent.Name,
                        PhoneNumber = agent.Phone,
                        PhoneNumberConfirmed = true,
                        EmailConfirmed = true,
                        District = district,
                        Town = town
                    };

                    var result = await userManager.CreateAsync(user, "Agent123!");
                    if (!result.Succeeded)
                    {
                        logger.LogWarning("Failed to seed collection agent {Email}: {Errors}",
                            email, string.Join(", ", result.Errors.Select(e => e.Description)));
                        continue;
                    }

                    await userManager.AddToRoleAsync(user, "CollectionAgent");

                    var profile = new CollectionAgentProfile
                    {
                        UserId = user.Id,
                        Phone = agent.Phone,
                        ServiceArea = district,
                        TownArea = town,
                        IsAvailable = true,
                        IsActive = true
                    };

                    context.CollectionAgentProfiles.Add(profile);
                    seededAgentCount++;
                }
            }

            if (seededAgentCount > 0)
            {
                await context.SaveChangesAsync();
                logger.LogInformation("Seeded {Count} collection agents across {Districts} districts",
                    seededAgentCount, districtAgents.Length);
            }
        }
    }
}

