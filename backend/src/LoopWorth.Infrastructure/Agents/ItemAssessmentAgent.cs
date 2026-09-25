using LoopWorth.Application.Interfaces;
using LoopWorth.Domain.Entities;
using LoopWorth.Domain.Enums;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace LoopWorth.Infrastructure.Agents;

public class ItemAssessmentAgent : IItemAssessmentAgent
{
    private readonly HttpClient _httpClient;
    private readonly string _apiKey;
    private readonly ILogger<ItemAssessmentAgent> _logger;

    public ItemAssessmentAgent(HttpClient httpClient, IConfiguration configuration, ILogger<ItemAssessmentAgent> logger)
    {
        _httpClient = httpClient;
        _apiKey = configuration["Gemini:ItemsApiKey"]
            ?? configuration["GEMINI_ITEMS_API_KEY"]
            ?? Environment.GetEnvironmentVariable("GEMINI_ITEMS_API_KEY")
            ?? string.Empty;
        _logger = logger;
    }

    public async Task<ItemAssessmentResult> AssessItemAsync(Item item, CancellationToken cancellationToken = default)
    {
        // First, check deterministic rules as a baseline safeguard
        var (deterministicMatch, detectedCat, detMismatchReason, detInconsistencyType) = CheckCategoryConsistency(item);
        if (!deterministicMatch)
        {
            _logger.LogInformation("Deterministic check flagged {Type} for item {ItemId}: {Reason}", detInconsistencyType, item.Id, detMismatchReason);
            return new ItemAssessmentResult
            {
                IsCategoryMatch = false,
                InconsistencyType = detInconsistencyType,
                DetectedCategory = detectedCat,
                MismatchReason = detMismatchReason,
                ConditionLevel = ConditionLevel.Unknown,
                RecommendedRoute = RecoveryRoute.Recycle,
                ConfidenceLevel = ConfidenceLevel.High,
                Explanation = detMismatchReason!
            };
        }

        var imageNames = item.Images.Any()
            ? string.Join(", ", item.Images.Select(img => Path.GetFileName(img.ImageUrl)))
            : "None";

        var prompt = $@"You are the Item Assessment Agent (Agent 1) for LoopWorth, an AI-assisted electronic waste recovery platform.
Your task has two critical steps:

STEP 1 - CONSISTENCY & VALIDITY CHECK:
Analyze the item's Name, Brand, Model, Selected Category, Condition Description, and Image references.
Determine if there is an inconsistency:

A) CATEGORY MISMATCH:
The physical device identity (Name, Brand, Model) clearly belongs to a different category than the user-selected category.
Example: Device is an 'iPhone 13' (Phone), but user selected 'Laptop' category.
If Category Mismatch:
- Set ""isCategoryMatch"" to false.
- Set ""inconsistencyType"" to ""CategoryMismatch"".
- Set ""detectedCategory"" to the accurate category name ('Phone', 'Laptop', 'Tablet', 'Computer Accessories', 'Home Electronics', 'Small Electronics').
- Set ""mismatchReason"" to: ""Category Mismatch: '{item.Name}' is a [detectedCategory], but was categorized under '[Selected Category]'. Please edit the item and select the '[detectedCategory]' category.""

B) DESCRIPTION INCONSISTENCY:
The user-selected category accurately matches the physical device identity (Name, Brand, Model), BUT the Condition Description describes a completely different type of device!
Example: The device is an 'iPhone 13 Pro Max' and the user correctly selected 'Phone' category, but the Condition Description describes an 'ASUS Zenbook laptop' or other unrelated device.
In this case, the Category is ALREADY CORRECT. The user made a mistake in the description! Do NOT tell the user to change the category to Laptop! Instead, instruct them to edit their description.
If Description Inconsistency:
- Set ""isCategoryMatch"" to false.
- Set ""inconsistencyType"" to ""DescriptionMismatch"".
- Set ""detectedCategory"" to the item's true category ('Phone').
- Set ""mismatchReason"" to: ""Description Inconsistency: '{item.Name}' is categorized correctly as a [Selected Category], but the condition description appears to describe a different device. Please edit the item's condition description to accurately describe your {item.Name}.""

STEP 2 - CONDITION & ROUTE RECOMMENDATION (Only if isCategoryMatch is true):
Analyze the device physical and operational condition and recommend the optimal recovery route ('Donate' for functional/mild wear, 'Recycle' for broken/damaged/unrepairable).
If isCategoryMatch is false, set conditionLevel to ""Unknown"", recommendedRoute to ""Recycle"", and confidenceLevel to ""Low"".

Item Information:
- Name: {item.Name}
- Selected Category: {item.Category?.Name ?? "Unknown"}
- Brand: {item.Brand ?? "Unknown"}
- Model: {item.Model ?? "Unknown"}
- Condition Description: {item.ConditionDescription ?? "Unknown"}
- Photos: {imageNames}

You must respond with ONLY valid JSON matching this exact schema:
{{
  ""isCategoryMatch"": true or false,
  ""inconsistencyType"": ""CategoryMismatch"" or ""DescriptionMismatch"" or null,
  ""detectedCategory"": ""Phone"" or ""Laptop"" or ""Tablet"" or ""Computer Accessories"" or ""Home Electronics"" or ""Small Electronics"" or null,
  ""mismatchReason"": ""Explanation if isCategoryMatch is false, otherwise null"",
  ""conditionLevel"": ""Good"" or ""Fair"" or ""Poor"" or ""Unknown"",
  ""recommendedRoute"": ""Donate"" or ""Recycle"",
  ""alternativeRoute"": ""Donate"" or ""Recycle"" or null,
  ""confidenceLevel"": ""Low"" or ""Medium"" or ""High"",
  ""explanation"": ""Short explanation of assessment or recommendation""
}}

Do not include any text outside the JSON object.";

        try
        {
            var json = await GeminiHelper.CallGeminiAsync(_httpClient, _apiKey, prompt, _logger, cancellationToken);
            var result = GeminiHelper.DeserializeResponse<ItemAssessmentResult>(json);

            // If Gemini detected category mismatch or description mismatch, return immediately
            if (!result.IsCategoryMatch)
            {
                result.ConditionLevel = ConditionLevel.Unknown;
                result.ConfidenceLevel = ConfidenceLevel.High;
                return result;
            }

            // Deterministic validation of route / condition enum values
            if (!Enum.IsDefined(typeof(ConditionLevel), result.ConditionLevel))
                throw new Exception("AI returned invalid condition level.");
            if (!Enum.IsDefined(typeof(RecoveryRoute), result.RecommendedRoute))
                throw new Exception("AI returned invalid recovery route.");
            if (!Enum.IsDefined(typeof(ConfidenceLevel), result.ConfidenceLevel))
                throw new Exception("AI returned invalid confidence level.");
            if (result.AlternativeRoute.HasValue && !Enum.IsDefined(typeof(RecoveryRoute), result.AlternativeRoute.Value))
                throw new Exception("AI returned invalid alternative route.");

            var hasHazard = item.EcoHazardLevel is "High" or "Critical" or "Moderate" ||
                            (item.EcoHazardReportJson != null && item.EcoHazardReportJson.Contains("\"IsHarmfulToEnvironment\":true"));
            if (hasHazard && result.RecommendedRoute == RecoveryRoute.Donate)
            {
                result.RecommendedRoute = RecoveryRoute.Recycle;
                result.AlternativeRoute = null;
                result.Explanation = (result.Explanation + " (Switched to Recycle because environmental safety hazard/damage reported in condition description precludes donation.)").Trim();
            }

            return result;
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Gemini assessment failed. Applying deterministic domain assessment rules.");
            var desc = (item.ConditionDescription ?? "").ToLowerInvariant();
            var hasHazard = item.EcoHazardLevel is "High" or "Critical" or "Moderate" ||
                            (item.EcoHazardReportJson != null && item.EcoHazardReportJson.Contains("\"IsHarmfulToEnvironment\":true")) ||
                            desc.Contains("swollen") || desc.Contains("leak") || desc.Contains("puncture");
            var isDamaged = hasHazard || desc.Contains("crack") || desc.Contains("broken") || desc.Contains("sluggish") || desc.Contains("degraded") || desc.Contains("outweigh");
            var isGood = !hasHazard && (desc.Contains("mint") || desc.Contains("good") || desc.Contains("working") || desc.Contains("like new"));

            var condition = isDamaged ? ConditionLevel.Poor : (isGood ? ConditionLevel.Good : ConditionLevel.Fair);
            var recommendedRoute = isDamaged ? RecoveryRoute.Recycle : RecoveryRoute.Donate;
            var altRoute = hasHazard ? (RecoveryRoute?)null : (isDamaged ? RecoveryRoute.Donate : RecoveryRoute.Recycle);

            return new ItemAssessmentResult
            {
                IsCategoryMatch = true,
                ConditionLevel = condition,
                RecommendedRoute = recommendedRoute,
                AlternativeRoute = altRoute,
                ConfidenceLevel = ConfidenceLevel.Medium,
                Explanation = hasHazard
                    ? $"Based on condition analysis and environmental hazard review, {recommendedRoute} is mandatory. Damaged or hazardous electronics cannot be donated."
                    : $"Based on condition analysis ({condition}), {recommendedRoute} is recommended for optimal resource recovery."
            };
        }
    }

    private static (bool IsMatch, string? DetectedCategory, string? MismatchReason, string? InconsistencyType) CheckCategoryConsistency(Item item)
    {
        var categoryName = item.Category?.Name ?? string.Empty;
        var identityText = $"{item.Name} {item.Brand} {item.Model} {string.Join(" ", item.Images.Select(i => i.ImageUrl))}".ToLowerInvariant();
        var descText = (item.ConditionDescription ?? string.Empty).ToLowerInvariant();

        // 1. Determine device identity from Name, Brand, Model, and Image names
        var identityIsPhone = identityText.Contains("iphone") || identityText.Contains("galaxy s") || identityText.Contains("galaxy z") ||
                              identityText.Contains("pixel 6") || identityText.Contains("pixel 7") || identityText.Contains("pixel 8") || identityText.Contains("pixel 9") ||
                              identityText.Contains("smartphone") || identityText.Contains("cell phone") || identityText.Contains("mobile phone") ||
                              identityText.Contains("redmi note") || identityText.Contains("oneplus");

        var identityIsLaptop = identityText.Contains("macbook") || identityText.Contains("thinkpad") || identityText.Contains("dell xps") ||
                               identityText.Contains("laptop") || identityText.Contains("notebook") || identityText.Contains("chromebook") ||
                               identityText.Contains("zenbook") || identityText.Contains("ideapad") || identityText.Contains("vivobook") ||
                               identityText.Contains("surface laptop");

        var identityIsTablet = identityText.Contains("ipad") || identityText.Contains("galaxy tab") || identityText.Contains("surface pro") ||
                               identityText.Contains("surface go") || identityText.Contains("tablet");

        // 2. Determine description device indicators
        var descIsPhone = descText.Contains("iphone") || descText.Contains("smartphone") || descText.Contains("cell phone") || descText.Contains("sim tray");
        var descIsLaptop = descText.Contains("macbook") || descText.Contains("thinkpad") || descText.Contains("zenbook") ||
                           descText.Contains("laptop") || descText.Contains("notebook") || descText.Contains("chromebook") ||
                           descText.Contains("chassis overhaul");
        var descIsTablet = descText.Contains("ipad") || descText.Contains("tablet") || descText.Contains("stylus pen");

        // Category matching flags
        var isCatPhone = categoryName.Equals("Phone", StringComparison.OrdinalIgnoreCase) || categoryName.Equals("Small Electronics", StringComparison.OrdinalIgnoreCase);
        var isCatLaptop = categoryName.Equals("Laptop", StringComparison.OrdinalIgnoreCase);
        var isCatTablet = categoryName.Equals("Tablet", StringComparison.OrdinalIgnoreCase);

        // --- SCENARIO 2: Description Inconsistency (Identity matches Category, but Description contradicts it!) ---
        if (identityIsPhone && isCatPhone && descIsLaptop)
        {
            var detectedMention = descText.Contains("zenbook") ? "ASUS Zenbook laptop" : "laptop";
            return (false, "Phone",
                $"Description Inconsistency: '{item.Name}' is categorized correctly as a Phone, but the condition description appears to describe an {detectedMention} instead of your phone. Please edit the item's condition description to accurately describe your {item.Name}.",
                "DescriptionMismatch");
        }

        if (identityIsLaptop && isCatLaptop && descIsPhone)
        {
            return (false, "Laptop",
                $"Description Inconsistency: '{item.Name}' is categorized correctly as a Laptop, but the condition description appears to describe a phone instead of your laptop. Please edit the item's condition description to accurately describe your {item.Name}.",
                "DescriptionMismatch");
        }

        if (identityIsTablet && isCatTablet && (descIsLaptop || descIsPhone))
        {
            var deviceMention = descIsLaptop ? "laptop" : "phone";
            return (false, "Tablet",
                $"Description Inconsistency: '{item.Name}' is categorized correctly as a Tablet, but the condition description appears to describe a {deviceMention}. Please edit the item's condition description to accurately describe your {item.Name}.",
                "DescriptionMismatch");
        }

        // --- SCENARIO 1: Category Mismatch (Identity does not match selected Category) ---
        if (identityIsPhone && !isCatPhone)
        {
            return (false, "Phone",
                $"Category Mismatch: '{item.Name}' is a mobile phone/smartphone, but was categorized under '{categoryName}'. Please edit the item and select the 'Phone' category.",
                "CategoryMismatch");
        }

        if (identityIsLaptop && !isCatLaptop)
        {
            return (false, "Laptop",
                $"Category Mismatch: '{item.Name}' is a laptop computer, but was categorized under '{categoryName}'. Please edit the item and select the 'Laptop' category.",
                "CategoryMismatch");
        }

        if (identityIsTablet && !isCatTablet)
        {
            return (false, "Tablet",
                $"Category Mismatch: '{item.Name}' is a tablet device, but was categorized under '{categoryName}'. Please edit the item and select the 'Tablet' category.",
                "CategoryMismatch");
        }

        return (true, null, null, null);
    }
}
