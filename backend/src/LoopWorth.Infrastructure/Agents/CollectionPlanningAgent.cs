using LoopWorth.Application.Interfaces;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace LoopWorth.Infrastructure.Agents;

public class CollectionPlanningAgent : ICollectionPlanningAgent
{
    private readonly HttpClient _httpClient;
    private readonly string _apiKey;
    private readonly ILogger<CollectionPlanningAgent> _logger;

    public CollectionPlanningAgent(HttpClient httpClient, IConfiguration configuration, ILogger<CollectionPlanningAgent> logger)
    {
        _httpClient = httpClient;
        _apiKey = configuration["Gemini:CollectionApiKey"]
            ?? configuration["GEMINI_COLLECTION_API_KEY"]
            ?? Environment.GetEnvironmentVariable("GEMINI_COLLECTION_API_KEY")
            ?? string.Empty;
        _logger = logger;
    }

    public async Task<CollectionPlanResult> PlanCollectionAsync(
        Guid collectionRequestId,
        DateTime preferredDate,
        TimeSpan preferredStartTime,
        TimeSpan preferredEndTime,
        string partnerName,
        string? partnerOperatingHours,
        string itemCategory,
        List<CollectionAgentCandidate> candidates,
        string? customerDistrict = null,
        string? customerTown = null,
        CancellationToken cancellationToken = default)
    {
        if (candidates.Count == 0)
            throw new Exception("No available collection agents found.");

        var candidateList = string.Join("\n", candidates.Select(c =>
            $"- UserId: {c.UserId}, Name: {c.Name}, ServiceArea: {c.ServiceArea}, TownArea: {c.TownArea ?? "All"}, SlotAvailability: {(c.IsBusyAtRequestedTime ? $"BUSY ({c.BusyReason})" : "FREE (Available at this date/time)")}, TotalActiveJobs: {c.ActiveJobsCount}"));

        var validIds = candidates.Select(c => c.UserId).ToHashSet();

        var prompt = $@"You are the Collection Planning Agent for LoopWorth.
Plan the collection logistics for this pickup.

Customer Location Details:
- Customer District / Service Area: {customerDistrict ?? "Colombo"}
- Customer Town / Local Area: {customerTown ?? "Not specified"}

Customer Requested Pickup Schedule:
- Date: {preferredDate:yyyy-MM-dd}
- Time Window: {preferredStartTime:hh\:mm} to {preferredEndTime:hh\:mm}

Partner: {partnerName}
Partner Operating Hours: {partnerOperatingHours ?? "Not specified"}
Item Category: {itemCategory}

Available Collection Agents (these are the ONLY valid agents):
{candidateList}

DISPATCH RULES:
1. CUSTOMER LOCATION: Find and select an agent whose ServiceArea covers or matches the customer's service area ({customerDistrict ?? "Colombo"}).
2. DATE & TIME AVAILABILITY: Check whether each agent is FREE or BUSY on the customer requested date ({preferredDate:yyyy-MM-dd}) at the mentioned time window ({preferredStartTime:hh\:mm} to {preferredEndTime:hh\:mm}).
3. IF BUSY, REASSIGN TO ANOTHER AGENT: If an agent is BUSY on that customer requested date/time, do NOT select him. You MUST assign another collection agent in that area who is FREE.
4. IF FREE, ASSIGN HIM: If an agent in that area is FREE on that date and time, assign him. If multiple agents are free, prioritize an agent whose TownArea matches the customer's town ({customerTown ?? "N/A"}), followed by the lowest TotalActiveJobs.
5. CRITICAL: You must ONLY use a UserId from the list above. Do not invent or modify any UserId.

Suggest the best date, time window, and collection agent.
The suggested time should respect the customer preference and partner operating hours.

Respond with ONLY valid JSON matching this schema:
{{
  ""suggestedDate"": ""YYYY-MM-DD"",
  ""suggestedStartTime"": ""HH:MM"",
  ""suggestedEndTime"": ""HH:MM"",
  ""suggestedCollectionAgentId"": ""exact-userId-from-list"",
  ""reason"": ""Brief explanation of the assigned agent (e.g. verified free in customer area {customerDistrict} on {preferredDate:yyyy-MM-dd} at {preferredStartTime:hh\:mm}-{preferredEndTime:hh\:mm})""
}}

Do not include any text outside the JSON object.";

        try
        {
            var json = await GeminiHelper.CallGeminiAsync(_httpClient, _apiKey, prompt, _logger, cancellationToken);

            // Parse with custom handling for time format
            var doc = System.Text.Json.JsonDocument.Parse(json);
            var root = doc.RootElement;

            var suggestedAgentId = root.GetProperty("suggestedCollectionAgentId").GetString() ?? "";
            if (!validIds.Contains(suggestedAgentId))
            {
                _logger.LogWarning("Rejected hallucinated CollectionAgentId {AgentId} from AI", suggestedAgentId);
                var targetArea = customerDistrict ?? "Colombo";
                var inArea = candidates.Where(c => c.IsAvailable && string.Equals(c.ServiceArea, targetArea, StringComparison.OrdinalIgnoreCase)).ToList();
                var pool = inArea.Count > 0 ? inArea : candidates.Where(c => c.IsAvailable).ToList();

                var fallbackAgent = pool
                    .OrderBy(c => c.IsBusyAtRequestedTime ? 1 : 0)
                    .ThenBy(c => (!string.IsNullOrEmpty(customerTown) && !string.IsNullOrEmpty(c.TownArea) && c.TownArea.Contains(customerTown, StringComparison.OrdinalIgnoreCase)) ? 0 : 1)
                    .ThenBy(c => c.ActiveJobsCount)
                    .FirstOrDefault() ?? candidates.First();
                suggestedAgentId = fallbackAgent.UserId;
            }

            var dateStr = root.GetProperty("suggestedDate").GetString() ?? preferredDate.ToString("yyyy-MM-dd");
            var startStr = root.GetProperty("suggestedStartTime").GetString() ?? preferredStartTime.ToString(@"hh\:mm");
            var endStr = root.GetProperty("suggestedEndTime").GetString() ?? preferredEndTime.ToString(@"hh\:mm");
            var reason = root.GetProperty("reason").GetString() ?? "AI suggestion";

            return new CollectionPlanResult
            {
                SuggestedDate = DateTime.TryParse(dateStr, out var d) ? d : preferredDate,
                SuggestedStartTime = TimeSpan.TryParse(startStr, out var st) ? st : preferredStartTime,
                SuggestedEndTime = TimeSpan.TryParse(endStr, out var et) ? et : preferredEndTime,
                SuggestedCollectionAgentId = suggestedAgentId,
                Reason = reason
            };
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Gemini collection planning encountered error. Allocating best available free agent.");
            var targetArea = customerDistrict ?? "Colombo";
            var inArea = candidates.Where(c => c.IsAvailable && string.Equals(c.ServiceArea, targetArea, StringComparison.OrdinalIgnoreCase)).ToList();
            var pool = inArea.Count > 0 ? inArea : candidates.Where(c => c.IsAvailable).ToList();

            var agent = pool
                .OrderBy(c => c.IsBusyAtRequestedTime ? 1 : 0)
                .ThenBy(c => (!string.IsNullOrEmpty(customerTown) && !string.IsNullOrEmpty(c.TownArea) && c.TownArea.Contains(customerTown, StringComparison.OrdinalIgnoreCase)) ? 0 : 1)
                .ThenBy(c => c.ActiveJobsCount)
                .FirstOrDefault() ?? candidates.First();

            return new CollectionPlanResult
            {
                SuggestedDate = preferredDate,
                SuggestedStartTime = preferredStartTime,
                SuggestedEndTime = preferredEndTime,
                SuggestedCollectionAgentId = agent.UserId,
                Reason = $"Scheduled with agent {agent.Name} in {agent.ServiceArea} (BusyAtSlot: {agent.IsBusyAtRequestedTime}, Active jobs: {agent.ActiveJobsCount})."
            };
        }
    }
}
