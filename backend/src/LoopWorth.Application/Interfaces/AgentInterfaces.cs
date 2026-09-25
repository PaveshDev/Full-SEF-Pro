using LoopWorth.Domain.Entities;
using LoopWorth.Domain.Enums;

namespace LoopWorth.Application.Interfaces;

public class ItemAssessmentResult
{
    public bool IsCategoryMatch { get; set; } = true;
    public string? InconsistencyType { get; set; } // "CategoryMismatch" or "DescriptionMismatch"
    public string? DetectedCategory { get; set; }
    public string? MismatchReason { get; set; }
    public ConditionLevel ConditionLevel { get; set; }
    public RecoveryRoute RecommendedRoute { get; set; }
    public RecoveryRoute? AlternativeRoute { get; set; }
    public ConfidenceLevel ConfidenceLevel { get; set; }
    public string Explanation { get; set; } = string.Empty;
}

public interface IItemAssessmentAgent
{
    Task<ItemAssessmentResult> AssessItemAsync(Item item, CancellationToken cancellationToken = default);
}

public class EcoImpactResult
{
    public bool IsHarmfulToEnvironment { get; set; }
    public string HazardLevel { get; set; } = "Low"; // "None", "Low", "Moderate", "High", "Critical"
    public List<string> DetectedHazards { get; set; } = new();
    public string EnvironmentalAlert { get; set; } = string.Empty;
    public List<string> HandlingPrecautions { get; set; } = new();
    public decimal EstimatedCo2OffsetKg { get; set; }
    public decimal EstimatedEwasteGrams { get; set; }
    public bool IsEcoFriendly { get; set; }
    public string Summary { get; set; } = string.Empty;
    public bool CanBeDonated { get; set; } = true;
    public string? DonationUnsuitabilityReason { get; set; }
    public string? MandatoryRoute { get; set; }
}

public interface IEcoImpactAgent
{
    Task<EcoImpactResult> AssessEcoImpactAsync(Item item, CancellationToken cancellationToken = default);
}

public class RecoveryPlanResult
{
    public string Suitability { get; set; } = string.Empty;
    public string Summary { get; set; } = string.Empty;
    public List<string> PreparationSteps { get; set; } = new();
    public List<string> SafetyNotes { get; set; } = new();
    public string RequiredPartnerType { get; set; } = string.Empty;
}

public interface IRecoveryPlanningAgent
{
    Task<RecoveryPlanResult> GeneratePlanAsync(Item item, ItemAssessment assessment, RecoveryRoute selectedRoute, CancellationToken cancellationToken = default);
}

public class PartnerMatchResult
{
    public Guid PartnerId { get; set; }
    public int Rank { get; set; }
    public string Reason { get; set; } = string.Empty;
}

public class PartnerCandidate
{
    public Guid PartnerId { get; set; }
    public string Name { get; set; } = string.Empty;
    public string SupportedRoute { get; set; } = string.Empty;
    public string Category { get; set; } = string.Empty;
    public string ServiceArea { get; set; } = string.Empty;
    public int AverageProcessingDays { get; set; }
}

public interface IPartnerMatchingAgent
{
    Task<List<PartnerMatchResult>> MatchPartnersAsync(Guid recoveryRequestId, RecoveryRoute selectedRoute, string itemCategory, List<PartnerCandidate> candidates, CancellationToken cancellationToken = default);
}

public class CollectionPlanResult
{
    public DateTime SuggestedDate { get; set; }
    public TimeSpan SuggestedStartTime { get; set; }
    public TimeSpan SuggestedEndTime { get; set; }
    public string SuggestedCollectionAgentId { get; set; } = string.Empty;
    public string Reason { get; set; } = string.Empty;
}

public class CollectionAgentCandidate
{
    public string UserId { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public string ServiceArea { get; set; } = string.Empty;
    public string? TownArea { get; set; }
    public bool IsAvailable { get; set; }
    public bool HasActiveJob { get; set; }
    public int ActiveJobsCount { get; set; }
    public bool IsBusyAtRequestedTime { get; set; }
    public string? BusyReason { get; set; }
}

public interface ICollectionPlanningAgent
{
    Task<CollectionPlanResult> PlanCollectionAsync(
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
        CancellationToken cancellationToken = default);
}

public interface IFileStorageService
{
    Task<string> SaveFileAsync(Stream fileStream, string fileName, string folder);
    Task DeleteFileAsync(string filePath);
}

public class DeliveryEmailContent
{
    public string Subject { get; set; } = string.Empty;
    public string Greeting { get; set; } = string.Empty;
    public string MessageBody { get; set; } = string.Empty;
    public string HtmlBody { get; set; } = string.Empty;
}

public interface IDeliveryNotificationAgent
{
    Task<DeliveryEmailContent> GenerateDeliveryEmailAsync(
        string customerName,
        string customerEmail,
        Item item,
        Partner partner,
        string? partnerFeedback,
        bool? partnerReceivedConditionOk,
        CancellationToken cancellationToken = default);
}

public interface IEmailService
{
    Task<bool> SendEmailAsync(string toEmail, string toName, string subject, string htmlContent, CancellationToken cancellationToken = default);
}

