using System.Text.Json;
using LoopWorth.Application.Interfaces;
using LoopWorth.Domain.Entities;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace LoopWorth.Infrastructure.Agents;

public class EcoImpactAgent : IEcoImpactAgent
{
    private readonly HttpClient _httpClient;
    private readonly string _apiKey;
    private readonly ILogger<EcoImpactAgent> _logger;

    public EcoImpactAgent(HttpClient httpClient, IConfiguration configuration, ILogger<EcoImpactAgent> logger)
    {
        _httpClient = httpClient;
        _apiKey = configuration["Gemini:EcoImpactApiKey"]
            ?? configuration["GEMINI_ECO_IMPACT_API_KEY"]
            ?? Environment.GetEnvironmentVariable("GEMINI_ECO_IMPACT_API_KEY")
            ?? configuration["Gemini:ItemsApiKey"]
            ?? string.Empty;
        _logger = logger;
    }

    public async Task<EcoImpactResult> AssessEcoImpactAsync(Item item, CancellationToken cancellationToken = default)
    {
        var imageNames = item.Images.Any()
            ? string.Join(", ", item.Images.Select(i => Path.GetFileName(i.ImageUrl)))
            : "No photos uploaded";

        var prompt = $@"You are the Environmental Safety & Eco-Impact Auditor for LoopWorth, an electronic waste and circular economy recovery platform.

CRITICAL INSTRUCTION - REASONING BASED ON CUSTOMER'S CONDITION DESCRIPTION:
1. Virtually all consumer electronic devices (smartphones, laptops, tablets, electronics) contain internal lithium-ion batteries, silicon chips, and printed circuit boards. The standard presence of an intact internal battery or electronic circuit board in an electronic item is EXPECTED and is NEVER an environmental hazard by itself!
2. Do NOT flag an item as hazardous simply because the description mentions 'battery' (e.g., 'battery health 85%', 'battery backup is good', 'battery drains fast', 'original battery included') or describes normal cosmetic wear ('minor scratches', 'small scuff', 'screen protector cracked', 'used for 1 year').
3. You must ONLY declare an active environmental hazard (`isHarmfulToEnvironment = true`) when the customer's Condition Description explicitly reports SEVERE COMPONENT DAMAGE, PHYSICAL RUPTURE, CHEMICAL EMISSIONS, OR ACTIVE DANGEROUS DEFECTS that pose an environmental or safety threat.

SCENARIO 1: ECO-SAFE & STABLE (NO ACTIVE HAZARD)
- If the customer's Condition Description describes an intact, functional, or lightly worn device (e.g., 'working perfectly', 'good battery life', 'battery health 80%', 'minor scratches on case', 'clean screen', 'normal used condition'):
  * The device is physically stable. Its battery and components are intact and sealed.
  * set `isHarmfulToEnvironment` = false
  * set `hazardLevel` = ""None"" or ""Low""
  * set `detectedHazards` = [] (Leave empty! Do NOT list intact internal components as hazards!)
  * set `isEcoFriendly` = true
  * set `canBeDonated` = true
  * set `mandatoryRoute` = null
  * set `donationUnsuitabilityReason` = null
  * set `environmentalAlert` = """"
  * set `summary` = ""Device is environmentally safe and structurally intact. Eligible for circular reuse, donation, or standard recycling.""

SCENARIO 2: SEVERE COMPONENT DAMAGE / HAZARDOUS ISSUE (ACTIVE HAZARD)
- If the customer's Condition Description explicitly reports severe dangerous issues such as:
  * Swollen, bloated, or bulging battery (severe thermal runaway / fire danger)
  * Punctured casing, leaking acid, or electrolyte fluid emissions
  * Burning smell, smoke marks, sparking, or scorched internal circuitry
  * Deep acid corrosion or severe toxic degradation
  * Severely shattered housing with exposed internal battery cells or hazardous chemicals
  * In these cases ONLY:
    - set `isHarmfulToEnvironment` = true
    - set `hazardLevel` = ""High"" or ""Critical"" (for swelling, leaks, fire/acid) or ""Moderate"" (for shattered chassis/corrosion)
    - set `detectedHazards` = [only the actual damaged component, e.g., ""Swollen Lithium-Ion Battery (Fire Risk)"", ""Leaking Electrolyte Fluid""]
    - set `isEcoFriendly` = false
    - set `canBeDonated` = false
    - set `mandatoryRoute` = ""Recycle""
    - set `donationUnsuitabilityReason` = ""Due to the damaged component / hazard described ({{hazard}}), this item cannot be accepted for donation and must be safely recycled.""
    - set `environmentalAlert` = Specific warning explaining why the damaged component is hazardous.
    - Provide 3-4 handling precautions for safety.

Device Information:
- Name: {item.Name}
- Category: {item.Category?.Name ?? "Consumer Electronics"}
- Brand: {item.Brand ?? "Unknown"}
- Model: {item.Model ?? "Unknown"}
- Condition Description (CUSTOMER REPORTED CONDITION & ISSUES): {item.ConditionDescription ?? "Unknown"}
- Photos: {imageNames}

Eco-Metrics:
- estimatedCo2OffsetKg: Estimated kg of CO2 avoided by recycling/refurbishing instead of mining virgin materials (Smartphones: 60-80 kg, Laptops: 200-300 kg, Tablets: 100-150 kg).
- estimatedEwasteGrams: Estimated weight in grams of e-waste diverted from landfill.

You must respond with ONLY valid JSON matching this exact schema:
{{
  ""isHarmfulToEnvironment"": true or false,
  ""hazardLevel"": ""None"" or ""Low"" or ""Moderate"" or ""High"" or ""Critical"",
  ""detectedHazards"": [""Damaged Hazard 1""],
  ""environmentalAlert"": ""Explanation if hazardous, or empty string if eco-safe"",
  ""handlingPrecautions"": [""Precaution 1"", ""Precaution 2""],
  ""estimatedCo2OffsetKg"": 70.5,
  ""estimatedEwasteGrams"": 240,
  ""isEcoFriendly"": true or false,
  ""canBeDonated"": true or false,
  ""donationUnsuitabilityReason"": ""Reason if cannot donate, or null"",
  ""mandatoryRoute"": ""Recycle"" or null,
  ""summary"": ""Executive summary of device environmental status""
}}

Do not include any text outside the JSON object.";

        try
        {
            var json = await GeminiHelper.CallGeminiAsync(_httpClient, _apiKey, prompt, _logger, cancellationToken);
            var result = GeminiHelper.DeserializeResponse<EcoImpactResult>(json);
            return result;
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Gemini EcoImpactAgent call failed. Falling back to deterministic environmental analysis.");
            return FallbackEcoAssessment(item);
        }
    }

    private static EcoImpactResult FallbackEcoAssessment(Item item)
    {
        var text = (item.ConditionDescription ?? string.Empty).ToLowerInvariant();
        var cat = (item.Category?.Name ?? string.Empty).ToLowerInvariant();
        var name = (item.Name ?? string.Empty).ToLowerInvariant();

        var isPhone = cat.Contains("phone") || name.Contains("iphone") || name.Contains("galaxy");
        var isLaptop = cat.Contains("laptop") || name.Contains("macbook") || name.Contains("thinkpad") || name.Contains("zenbook");

        decimal co2 = isLaptop ? 245m : (isPhone ? 68m : 110m);
        decimal weight = isLaptop ? 1800m : (isPhone ? 240m : 500m);

        // ONLY detect hazards if the condition description explicitly describes severe component damage, rupture, or hazardous emission!
        var hasSwollenBattery = text.Contains("swollen") || text.Contains("bulge") || text.Contains("bulging") || text.Contains("battery expanding") || text.Contains("bloated battery");
        var hasChemicalLeak = (text.Contains("leak") && !text.Contains("no leak") && !text.Contains("not leak")) || text.Contains("acid") || text.Contains("liquid chemical");
        var hasBurnOrSmoke = (text.Contains("smoke") || text.Contains("spark") || text.Contains("scorched") || (text.Contains("burn") && !text.Contains("burn-in") && !text.Contains("burn in"))) && !text.Contains("no burn");
        var hasCorrosion = text.Contains("corro") || (text.Contains("rust") && !text.Contains("no rust")) || text.Contains("water damage");
        var hasPuncture = text.Contains("puncture") || text.Contains("pierced");
        var hasShatteredDamage = (text.Contains("shatter") || text.Contains("crushed") || text.Contains("severely cracked") || text.Contains("casing open")) && !text.Contains("screen protector");

        var hazards = new List<string>();
        if (hasSwollenBattery)
            hazards.Add("Swollen Lithium-Ion Battery (Thermal Runaway & Fire Risk)");
        if (hasChemicalLeak)
            hazards.Add("Leaking Electrolyte Fluid / Chemical Hazard");
        if (hasBurnOrSmoke)
            hazards.Add("Scorched / Fire-Damaged Internal Electronics");
        if (hasPuncture)
            hazards.Add("Punctured Battery Bay / Mechanical Rupture");
        if (hasCorrosion)
            hazards.Add("Severe Chemical Corrosion / Acid Degradation");
        if (hasShatteredDamage)
            hazards.Add("Shattered Housing with Exposed Sharp / Internal Components");

        var isHarmful = hazards.Any();

        if (!isHarmful)
        {
            // Device components are intact and safe!
            return new EcoImpactResult
            {
                IsHarmfulToEnvironment = false,
                HazardLevel = "None",
                DetectedHazards = new List<string>(),
                EnvironmentalAlert = string.Empty,
                HandlingPrecautions = new List<string>
                {
                    "Standard electronic handling: keep in a dry, room-temperature environment.",
                    "Use standard padded protective packaging during collection and transit."
                },
                EstimatedCo2OffsetKg = co2,
                EstimatedEwasteGrams = weight,
                IsEcoFriendly = true,
                CanBeDonated = true,
                DonationUnsuitabilityReason = null,
                MandatoryRoute = null,
                Summary = $"This {item.Name} is structurally intact with no active chemical or physical component hazards. Cleared for standard circular reuse, donation, or recycling."
            };
        }

        // Active component hazard detected based on customer description
        var hazardLevel = (hasSwollenBattery || hasChemicalLeak || hasBurnOrSmoke || hasPuncture)
            ? "High"
            : "Moderate";

        return new EcoImpactResult
        {
            IsHarmfulToEnvironment = true,
            HazardLevel = hazardLevel,
            DetectedHazards = hazards,
            EnvironmentalAlert = $"Severe component hazard detected in condition description ({string.Join(", ", hazards)}). This device poses fire, toxic chemical, or environmental contamination risks and requires specialized hazardous e-waste handling.",
            HandlingPrecautions = new List<string>
            {
                "Do not puncture, compress, or expose to heat.",
                "Isolate device in a flame-retardant or anti-static padded pouch.",
                "Keep away from flammable materials until courier handover."
            },
            EstimatedCo2OffsetKg = co2,
            EstimatedEwasteGrams = weight,
            IsEcoFriendly = false,
            CanBeDonated = false,
            DonationUnsuitabilityReason = $"Due to the component hazard ({string.Join(", ", hazards)}) reported in the condition description, this item cannot be donated and must be recycled.",
            MandatoryRoute = "Recycle",
            Summary = $"Environmental hazard detected ({hazardLevel}): Requires cautious handling and certified e-waste recovery."
        };
    }
}
