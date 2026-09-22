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
        var (deterministicMatch, detectedCat, detMismatchReason) = CheckCategoryConsistency(item);
        if (!deterministicMatch)
        {
            _logger.LogInformation("Deterministic check flagged category mismatch for item {ItemId}: {Reason}", item.Id, detMismatchReason);
            return new ItemAssessmentResult
            {
                IsCategoryMatch = false,
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

STEP 1 - CATEGORY CONSISTENCY CHECK:
Check whether the user-selected Category accurately matches the item's identity based on Name, Brand, Model, Condition Description, and Image references.
For example, if the user registers an 'iPhone 13 Pro Max' (a smartphone/mobile phone) under the category 'Laptop', this is a blatant category mismatch. A smartphone cannot be categorized as a Laptop!
Similarly, a MacBook or laptop cannot be categorized as a Phone, etc.
If there is a category mismatch:
- Set ""isCategoryMatch"" to false.
- Set ""detectedCategory"" to the accurate category name (e.g. 'Phone', 'Laptop', 'Tablet', 'Computer Accessories', 'Home Electronics', 'Small Electronics').
- Set ""mismatchReason"" to a clear explanation explaining that the item appears to be a [detectedCategory] and does not match the selected category.

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

            // If Gemini detected category mismatch, return immediately
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

            return result;
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Gemini assessment failed. Applying deterministic domain assessment rules.");
            var desc = (item.ConditionDescription ?? "").ToLowerInvariant();
            var isDamaged = desc.Contains("crack") || desc.Contains("broken") || desc.Contains("sluggish") || desc.Contains("degraded") || desc.Contains("outweigh");
            var isGood = desc.Contains("mint") || desc.Contains("good") || desc.Contains("working") || desc.Contains("like new");

            var condition = isDamaged ? ConditionLevel.Poor : (isGood ? ConditionLevel.Good : ConditionLevel.Fair);
            var recommendedRoute = isDamaged ? RecoveryRoute.Recycle : RecoveryRoute.Donate;
            var altRoute = isDamaged ? RecoveryRoute.Donate : RecoveryRoute.Recycle;

            return new ItemAssessmentResult
            {
                IsCategoryMatch = true,
                ConditionLevel = condition,
                RecommendedRoute = recommendedRoute,
                AlternativeRoute = altRoute,
                ConfidenceLevel = ConfidenceLevel.Medium,
                Explanation = $"Based on condition analysis ({condition}), {recommendedRoute} is recommended for optimal resource recovery."
            };
        }
    }

    private static (bool IsMatch, string? DetectedCategory, string? MismatchReason) CheckCategoryConsistency(Item item)
    {
        var categoryName = item.Category?.Name ?? string.Empty;
        var text = $"{item.Name} {item.Brand} {item.Model} {item.ConditionDescription} {string.Join(" ", item.Images.Select(i => i.ImageUrl))}".ToLowerInvariant();

        // Phone indicators
        var isPhone = text.Contains("iphone") || text.Contains("galaxy s") || text.Contains("galaxy z") ||
                      text.Contains("pixel 6") || text.Contains("pixel 7") || text.Contains("pixel 8") || text.Contains("pixel 9") ||
                      text.Contains("smartphone") || text.Contains("cell phone") || text.Contains("mobile phone") ||
                      text.Contains("redmi note") || text.Contains("oneplus");

        // Laptop indicators
        var isLaptop = text.Contains("macbook") || text.Contains("thinkpad") || text.Contains("dell xps") ||
                       text.Contains("laptop") || text.Contains("notebook") || text.Contains("chromebook") ||
                       text.Contains("zenbook") || text.Contains("ideapad");

        // Tablet indicators
        var isTablet = text.Contains("ipad") || text.Contains("galaxy tab") || text.Contains("surface pro") ||
                       text.Contains("surface go") || text.Contains("tablet");

        if (isPhone && !categoryName.Equals("Phone", StringComparison.OrdinalIgnoreCase) && !categoryName.Equals("Small Electronics", StringComparison.OrdinalIgnoreCase))
        {
            return (false, "Phone", $"Category Mismatch: '{item.Name}' is a mobile phone/smartphone, but was categorized under '{categoryName}'. Please edit the item and select the 'Phone' category.");
        }

        if (isLaptop && !categoryName.Equals("Laptop", StringComparison.OrdinalIgnoreCase))
        {
            return (false, "Laptop", $"Category Mismatch: '{item.Name}' is a laptop computer, but was categorized under '{categoryName}'. Please edit the item and select the 'Laptop' category.");
        }

        if (isTablet && !categoryName.Equals("Tablet", StringComparison.OrdinalIgnoreCase))
        {
            return (false, "Tablet", $"Category Mismatch: '{item.Name}' is a tablet device, but was categorized under '{categoryName}'. Please edit the item and select the 'Tablet' category.");
        }

        return (true, null, null);
    }
}
