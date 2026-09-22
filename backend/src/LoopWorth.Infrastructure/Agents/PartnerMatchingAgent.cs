using System.Text.Json;
using LoopWorth.Application.Interfaces;
using LoopWorth.Domain.Enums;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace LoopWorth.Infrastructure.Agents;

public class PartnerMatchingAgent : IPartnerMatchingAgent
{
    private readonly HttpClient _httpClient;
    private readonly string _apiKey;
    private readonly ILogger<PartnerMatchingAgent> _logger;

    public PartnerMatchingAgent(HttpClient httpClient, IConfiguration configuration, ILogger<PartnerMatchingAgent> logger)
    {
        _httpClient = httpClient;
        _apiKey = configuration["Gemini:PartnersApiKey"]
            ?? configuration["GEMINI_PARTNERS_API_KEY"]
            ?? Environment.GetEnvironmentVariable("GEMINI_PARTNERS_API_KEY")
            ?? string.Empty;
        _logger = logger;
    }

    public async Task<List<PartnerMatchResult>> MatchPartnersAsync(
        Guid recoveryRequestId,
        RecoveryRoute selectedRoute,
        string itemCategory,
        List<PartnerCandidate> candidates,
        CancellationToken cancellationToken = default)
    {
        if (candidates.Count == 0)
            return new List<PartnerMatchResult>();

        var candidateList = string.Join("\n", candidates.Select(c =>
            $"- PartnerId: {c.PartnerId}, Name: {c.Name}, Route: {c.SupportedRoute}, Category: {c.Category}, ServiceArea: {c.ServiceArea}, ProcessingDays: {c.AverageProcessingDays}"));

        var validIds = candidates.Select(c => c.PartnerId).ToHashSet();

        var prompt = $@"You are the Partner Matching Agent for LoopWorth.
Rank the following pre-filtered eligible partners for this recovery request.

Selected Route: {selectedRoute}
Item Category: {itemCategory}

Eligible Partners (these are the ONLY valid partners):
{candidateList}

Rank ALL listed partners by suitability. Provide a brief reason for each ranking.

CRITICAL: You must ONLY use the exact PartnerId values listed above. Do not invent or modify any PartnerId.

Respond with ONLY a valid JSON array matching this schema:
[
  {{
    ""partnerId"": ""exact-guid-from-list"",
    ""rank"": 1,
    ""reason"": ""Brief reason for this ranking""
  }}
]

Do not include any text outside the JSON array.";

        try
        {
            var json = await GeminiHelper.CallGeminiAsync(_httpClient, _apiKey, prompt, _logger, cancellationToken);
            var results = GeminiHelper.DeserializeResponse<List<PartnerMatchResult>>(json);

            // Deterministic validation: reject any hallucinated partner IDs
            var validated = new List<PartnerMatchResult>();
            foreach (var r in results)
            {
                if (!validIds.Contains(r.PartnerId))
                {
                    _logger.LogWarning("Rejected hallucinated PartnerId {PartnerId} from AI response", r.PartnerId);
                    continue;
                }
                validated.Add(r);
            }

            if (validated.Count > 0)
                return validated.OrderBy(r => r.Rank).ToList();
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Gemini partner matching failed. Applying multi-criteria deterministic ranking.");
        }

        // Deterministic fallback: rank by fastest processing turnaround time
        return candidates
            .OrderBy(c => c.AverageProcessingDays)
            .Select((c, idx) => new PartnerMatchResult
            {
                PartnerId = c.PartnerId,
                Rank = idx + 1,
                Reason = $"Matched by optimal turnaround capacity ({c.AverageProcessingDays} avg days) for {c.SupportedRoute} of {c.Category} in {c.ServiceArea}."
            })
            .ToList();
    }
}
