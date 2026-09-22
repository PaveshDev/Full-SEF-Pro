using LoopWorth.Application.Interfaces;
using LoopWorth.Domain.Entities;
using LoopWorth.Domain.Enums;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace LoopWorth.Infrastructure.Agents;

public class RecoveryPlanningAgent : IRecoveryPlanningAgent
{
    private readonly HttpClient _httpClient;
    private readonly string _apiKey;
    private readonly ILogger<RecoveryPlanningAgent> _logger;

    public RecoveryPlanningAgent(HttpClient httpClient, IConfiguration configuration, ILogger<RecoveryPlanningAgent> logger)
    {
        _httpClient = httpClient;
        _apiKey = configuration["Gemini:RecoveryApiKey"]
            ?? configuration["GEMINI_RECOVERY_API_KEY"]
            ?? Environment.GetEnvironmentVariable("GEMINI_RECOVERY_API_KEY")
            ?? string.Empty;
        _logger = logger;
    }

    public async Task<RecoveryPlanResult> GeneratePlanAsync(Item item, ItemAssessment assessment, RecoveryRoute selectedRoute, CancellationToken cancellationToken = default)
    {
        var imageNames = item.Images.Any()
            ? string.Join(", ", item.Images.Select(img => Path.GetFileName(img.ImageUrl)))
            : "None";

        var prompt = $@"You are the Recovery Planning Agent (Agent 2) for LoopWorth, an intelligent electronic waste recovery platform.
Your objective is to generate a highly tailored, device-specific recovery preparation plan.

CRITICAL INSTRUCTION - DEVICE SPECIFICITY:
- The preparation steps and safety precautions MUST be tailored specifically to the exact item, category, model, and condition described below.
- NEVER provide generic smartphone advice (such as 'Remove SIM cards') for non-phone items like laptops, tablets, or accessories!
- For a Laptop: Include steps such as backing up files to external/cloud drive, performing operating system factory reset or disk wipe, disconnecting the AC power adapter/charger and USB dongles/wireless mice, and cushioning the screen/chassis in a laptop sleeve or padded box.
- For a Smartphone/Phone: Include removing SIM card and microSD card, unlinking Apple ID/Google accounts, factory resetting, removing cases, and handling cracked screen/back glass safely.
- For a Tablet: Include cloud backup, signing out of accounts, removing screen protector/case/stylus, and protecting the glass digitizer.
- For Accessories/Peripherals: Include disconnecting cables, removing AA/AAA batteries from wireless devices, and coiling cords neatly.
- Incorporate specific safety notes based on the reported condition (e.g., handling broken/shattered glass splinters, avoiding pressure on swollen/degraded lithium batteries, handling loose hinges or exposed internals).

Item Details:
- Item Name: {item.Name}
- Category: {item.Category?.Name ?? "Electronic Device"}
- Brand: {item.Brand ?? "Unknown"}
- Model: {item.Model ?? "Unknown"}
- Reported Physical & Operational Condition: {item.ConditionDescription}
- Associated Photos: {imageNames}
- Assessed Condition Level: {assessment.ConditionLevel}
- Selected Recovery Route: {selectedRoute}
- Agent 1 Advisory Rationale: {assessment.Explanation}

Respond with ONLY valid JSON matching this exact schema:
{{
  ""suitability"": ""Suitability analysis specifically referencing {item.Name} and {selectedRoute} route"",
  ""summary"": ""Concise preparation summary specifically for this {item.Category?.Name ?? "device"} and condition"",
  ""preparationSteps"": [
    ""Specific step 1..."",
    ""Specific step 2..."",
    ""Specific step 3..."",
    ""Specific step 4...""
  ],
  ""safetyNotes"": [
    ""Safety note 1 addressing specific hazards (e.g. battery, glass, electrical)..."",
    ""Safety note 2...""
  ],
  ""requiredPartnerType"": ""Specific partner type, e.g. Certified E-Waste Recycler for {item.Category?.Name}""
}}

Do not include any text outside the JSON object.";

        try
        {
            var json = await GeminiHelper.CallGeminiAsync(_httpClient, _apiKey, prompt, _logger, cancellationToken);
            var result = GeminiHelper.DeserializeResponse<RecoveryPlanResult>(json);

            // Validate required fields
            if (string.IsNullOrWhiteSpace(result.Summary))
                throw new Exception("AI returned empty plan summary.");
            if (result.PreparationSteps == null || result.PreparationSteps.Count == 0)
                throw new Exception("AI returned no preparation steps.");

            return result;
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Gemini recovery planning unavailable or timed out. Generating tailored domain preparation plan for {ItemName} ({Category}).", item.Name, item.Category?.Name);
            return GenerateDynamicPreparationPlan(item, assessment, selectedRoute);
        }
    }

    private static RecoveryPlanResult GenerateDynamicPreparationPlan(Item item, ItemAssessment assessment, RecoveryRoute selectedRoute)
    {
        var category = (item.Category?.Name ?? "").ToLowerInvariant();
        var name = (item.Name ?? "").ToLowerInvariant();
        var model = (item.Model ?? "").ToLowerInvariant();
        var desc = (item.ConditionDescription ?? "").ToLowerInvariant();

        var isLaptop = category.Contains("laptop") || name.Contains("laptop") || name.Contains("notebook") || name.Contains("macbook") || name.Contains("zenbook") || name.Contains("thinkpad");
        var isPhone = category.Contains("phone") || name.Contains("phone") || name.Contains("iphone") || name.Contains("galaxy s") || name.Contains("pixel");
        var isTablet = category.Contains("tablet") || name.Contains("tablet") || name.Contains("ipad") || name.Contains("galaxy tab") || name.Contains("surface");

        var hasBatteryIssue = desc.Contains("battery") || desc.Contains("swollen") || desc.Contains("bulge") || desc.Contains("charge") || desc.Contains("overheat") || desc.Contains("drain");
        var hasGlassDamage = desc.Contains("screen") || desc.Contains("glass") || desc.Contains("shatter") || desc.Contains("crack") || desc.Contains("broken");

        if (isLaptop)
        {
            var steps = new List<string>();
            if (selectedRoute == RecoveryRoute.Donate)
            {
                steps.Add("Back up all personal files, documents, and browser data to an external drive or cloud storage (e.g. OneDrive or Google Drive).");
                steps.Add("Perform a full operating system factory reset (Windows Reset or macOS Erase Assistant) to erase all user accounts and personal data.");
                steps.Add("Disconnect all external peripherals, including USB dongles, wireless mouse receivers, external storage, and SD cards.");
                steps.Add("Gather the original AC power adapter and charging cable, coiling the cords neatly alongside the laptop.");
                steps.Add("Clean the display and keyboard gently with a dry microfiber cloth, and pack the unit in a protective laptop sleeve or padded carton.");
            }
            else // Recycle
            {
                if (!desc.Contains("dead") && !desc.Contains("won't turn on") && !desc.Contains("no power"))
                {
                    steps.Add("If the laptop can still power on, back up any accessible personal files and perform an operating system reset or drive wipe.");
                }
                steps.Add("Disconnect and remove all external accessories, including USB flash drives, wireless mouse dongles, and SD memory cards.");
                steps.Add("Unplug the AC power adapter brick and charging cable, securing the cords alongside the laptop.");
                steps.Add("Gently close the laptop display lid and secure the unit in a cushioned box or padded sleeve to protect internal parts during transit.");
            }

            var safety = new List<string>();
            if (hasBatteryIssue)
            {
                safety.Add("Battery Hazard Precaution: Do not attempt to charge, compress, or tamper with the laptop chassis if the internal battery is swollen or bulging.");
            }
            else
            {
                safety.Add("Electrical & Battery Safety: Ensure the laptop is completely powered down and disconnected from wall outlets prior to pickup.");
            }

            if (hasGlassDamage || desc.Contains("hinge"))
            {
                safety.Add("Structural & Display Caution: Handle the fragile screen and damaged hinge assembly carefully to prevent further structural cracking or glass splinters.");
            }
            else
            {
                safety.Add("Transit Cushioning: Wrap the laptop securely in bubble wrap or a padded carton to protect the display panel and chassis.");
            }

            return new RecoveryPlanResult
            {
                Suitability = $"The {item.Name} ({item.Category?.Name ?? "Laptop"}) is suitable for {selectedRoute} processing based on its {assessment.ConditionLevel.ToString().ToLower()} condition.",
                Summary = $"Tailored preparation protocol for {item.Name} ({item.Category?.Name ?? "Laptop"}) designated for {selectedRoute}.",
                PreparationSteps = steps,
                SafetyNotes = safety,
                RequiredPartnerType = selectedRoute == RecoveryRoute.Recycle ? "Certified E-Waste Recycler (IT & Computer Hardware)" : "Community Laptop Refurbishment Center"
            };
        }

        if (isPhone)
        {
            var steps = new List<string>();
            if (selectedRoute == RecoveryRoute.Donate)
            {
                steps.Add("Back up all photos, contacts, and personal data to iCloud or Google Drive.");
                steps.Add("Sign out of your Apple ID / Google Account and disable 'Find My' / Device Activation Lock.");
                steps.Add("Eject your physical SIM card using a SIM tool or paperclip, and remove any microSD expandable storage cards.");
                steps.Add("Perform a complete factory reset to remove all personal data, saved passwords, and accounts.");
                steps.Add("Remove external protective cases and package the smartphone in a padded envelope or box.");
            }
            else // Recycle
            {
                steps.Add("Eject your physical SIM card using a SIM ejector tool or paperclip, and remove any expandable microSD storage card.");
                steps.Add("If the screen remains touch-responsive, sign out of personal accounts and trigger a factory reset.");
                steps.Add("Remove protective phone cases, magnetic accessories, and adhesive card attachments.");
                steps.Add("Place the smartphone into a sealable protective pouch or padded envelope for doorstep collection.");
            }

            var safety = new List<string>();
            if (hasGlassDamage)
            {
                safety.Add("Broken Glass Caution: The phone has shattered or cracked glass. Place in a clear zip pouch to prevent cuts or loose glass splinters.");
            }
            if (hasBatteryIssue)
            {
                safety.Add("Lithium Battery Precaution: Do not attempt to charge, heat, or puncture the degraded or swollen battery.");
            }
            if (!safety.Any())
            {
                safety.Add("Keep the device powered off and protected from moisture and high heat while awaiting pickup.");
            }

            return new RecoveryPlanResult
            {
                Suitability = $"The {item.Name} is suitable for {selectedRoute} processing based on its reported {assessment.ConditionLevel.ToString().ToLower()} physical condition.",
                Summary = $"Mobile device preparation and data security protocol for {item.Name} slated for {selectedRoute}.",
                PreparationSteps = steps,
                SafetyNotes = safety,
                RequiredPartnerType = selectedRoute == RecoveryRoute.Recycle ? "Certified Mobile & Small Electronics Recycler" : "Mobile Device Donation & Rehoming Center"
            };
        }

        if (isTablet)
        {
            var steps = new List<string>
            {
                "Back up all personal files, photos, and apps to your cloud storage account.",
                "Sign out of Apple ID / Google / Microsoft accounts and turn off remote device tracking.",
                "Remove any inserted SIM cards, microSD memory cards, and detach magnetic stylus pens (e.g., Apple Pencil or S-Pen).",
                "Perform a full factory reset to erase all personal information.",
                "Wrap the tablet in protective bubble wrap to prevent screen damage during transit."
            };

            var safety = new List<string>
            {
                "Handle cracked glass digitizer surfaces carefully to avoid cuts.",
                "Store at room temperature and do not pierce or apply pressure to internal battery cells."
            };

            return new RecoveryPlanResult
            {
                Suitability = $"The {item.Name} is suitable for {selectedRoute} processing.",
                Summary = $"Tablet preparation protocol for {item.Name} slated for {selectedRoute}.",
                PreparationSteps = steps,
                SafetyNotes = safety,
                RequiredPartnerType = selectedRoute == RecoveryRoute.Recycle ? "Certified Tablet & E-Waste Recycler" : "Educational Technology Donation Center"
            };
        }

        // Generic electronics fallback
        return new RecoveryPlanResult
        {
            Suitability = $"The {item.Name} is suitable for {selectedRoute} processing.",
            Summary = $"Preparation procedure for {item.Name} ({item.Category?.Name ?? "Electronic Device"}) slated for {selectedRoute}.",
            PreparationSteps = new List<string>
            {
                "Disconnect all cables, power adapters, and external accessories from the device.",
                "Remove any disposable AA/AAA batteries or removable memory storage cards.",
                "Clean exterior surfaces with a dry cloth.",
                "Bundle all power cords and accessories neatly alongside the main unit in a secure carton."
            },
            SafetyNotes = new List<string>
            {
                "Ensure the equipment is completely powered down and disconnected from power outlets.",
                "Do not include leaking or damaged batteries with the package."
            },
            RequiredPartnerType = selectedRoute == RecoveryRoute.Recycle ? "Certified E-Waste Recycler" : "Charity Donation Center"
        };
    }
}
