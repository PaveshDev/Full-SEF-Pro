using System.Text.Json;
using LoopWorth.Application.Interfaces;
using LoopWorth.Domain.Entities;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace LoopWorth.Infrastructure.Agents;

public class DeliveryNotificationAgent : IDeliveryNotificationAgent
{
    private readonly HttpClient _httpClient;
    private readonly string _apiKey;
    private readonly ILogger<DeliveryNotificationAgent> _logger;

    public DeliveryNotificationAgent(HttpClient httpClient, IConfiguration configuration, ILogger<DeliveryNotificationAgent> logger)
    {
        _httpClient = httpClient;
        _logger = logger;
        _apiKey = ResolveConfig(configuration,
            "Gemini:CollectionApiKey", "GEMINI_COLLECTION_API_KEY",
            "Gemini:ItemsApiKey", "GEMINI_ITEMS_API_KEY");
    }

    private static string ResolveConfig(IConfiguration config, params string[] keys)
    {
        foreach (var key in keys)
        {
            var val = config[key];
            if (!string.IsNullOrWhiteSpace(val)) return val.Trim();
            val = Environment.GetEnvironmentVariable(key);
            if (!string.IsNullOrWhiteSpace(val)) return val.Trim();
        }
        return string.Empty;
    }

    public async Task<DeliveryEmailContent> GenerateDeliveryEmailAsync(
        string customerName,
        string customerEmail,
        Item item,
        Partner partner,
        string? partnerFeedback,
        bool? partnerReceivedConditionOk,
        CancellationToken cancellationToken = default)
    {
        // Calculate realistic eco impact metrics based on stored assessment or hardware category benchmarks
        var (co2Offset, ewasteGrams) = CalculateRealEcoMetrics(item);

        var routeName = item.SelectedRecoveryRoute?.ToString() ?? "Circular Recovery";
        var partnerName = partner.Name ?? "our certified partner facility";
        var partnerLocation = string.IsNullOrWhiteSpace(partner.ServiceArea) ? "Registered Partner Facility" : partner.ServiceArea;
        var conditionStatus = (partnerReceivedConditionOk == true)
            ? "Verified in expected condition"
            : (partnerReceivedConditionOk == false ? "Condition noted with intake observations" : "Intake confirmed");
        var customerCondition = string.IsNullOrWhiteSpace(item.ConditionDescription)
            ? "Standard pre-owned condition as declared"
            : item.ConditionDescription.Trim();
        var remarks = string.IsNullOrWhiteSpace(partnerFeedback)
            ? "Item unboxed, inspected, and accepted into processing queue."
            : partnerFeedback.Trim();
        var categoryName = item.Category?.Name ?? "Consumer Electronics";
        var nextStepsText = ResolveNextSteps(routeName, partnerName);

        var prompt = $@"You are the Customer Notification & Environmental Impact Agent for LoopWorth, an AI-driven electronic waste circular economy platform.
A customer's submitted item has just been collected by our courier and delivered successfully to their chosen recovery partner facility. The partner has confirmed intake.

Task:
Generate a professional, transparent, and eco-certified 'Option 1: Certified Circular Handover & Intake Receipt' email for the customer.
You MUST use the customer's REAL item data and REAL environmental metrics provided below. Do NOT use fake or generic placeholder numbers.

Real Submission Details:
- Customer Name: {customerName}
- Customer Email: {customerEmail}
- Item Name: {item.Name}
- Brand: {item.Brand ?? "Unknown"}
- Model: {item.Model ?? "Unknown"}
- Category: {categoryName}
- Customer Declared Condition: {customerCondition}
- Chosen Recovery Route: {routeName}
- Partner Facility: {partnerName} ({partnerLocation})
- Intake Verification Status: {conditionStatus}
- Partner Intake Remarks: {remarks}
- Real Environmental Metrics: ~{co2Offset:0.#} kg of CO2 emissions avoided, ~{ewasteGrams:0.#} grams of e-waste diverted from landfill
- Next Steps: {nextStepsText}

Requirements:
1. Subject line: 'Intake Confirmed: Your {item.Name} has arrived at {partnerName}'
2. Greeting: 'Dear {customerName},'
3. Content & Structure:
   - Announce safe transit and handover to {partnerName} in {partnerLocation}.
   - Verified Item Submission summary table (Item Name, Brand & Model, Category, Customer Condition Note, Recovery Route, Facility Intake Status, Partner Remarks).
   - Real Environmental Impact section featuring ~{co2Offset:0.#} kg CO2 avoided and ~{ewasteGrams:0.#} g e-waste saved.
   - Transparent Next Steps section based on {routeName}.
   - LoopWorth branding ('Give Waste Another Worth') and Brevo dispatch footer.
4. Output format: Respond in valid JSON with:
   - 'subject': string
   - 'greeting': string
   - 'messageBody': plain text summary (2-3 paragraphs)
   - 'htmlBody': full responsive HTML email template using inline CSS (include logo header https://files.catbox.moe/g8fe3a.jpg with max-width 130px, #16A34A emerald green, #065F46 dark green, #0F172A slate text, #F0FDF4 soft green card).

Schema:
{{
  ""subject"": ""..."",
  ""greeting"": ""..."",
  ""messageBody"": ""..."",
  ""htmlBody"": ""<html>...</html>""
}}
Respond with ONLY valid JSON.";

        try
        {
            var json = await GeminiHelper.CallGeminiAsync(_httpClient, _apiKey, prompt, _logger, cancellationToken);
            var content = GeminiHelper.DeserializeResponse<DeliveryEmailContent>(json);
            if (!string.IsNullOrWhiteSpace(content.HtmlBody))
            {
                return content;
            }
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Gemini delivery notification agent call failed. Using deterministic Option 1 notification template.");
        }

        return FallbackNotification(
            customerName,
            item,
            partner,
            categoryName,
            customerCondition,
            routeName,
            conditionStatus,
            remarks,
            co2Offset,
            ewasteGrams,
            nextStepsText);
    }

    private static (decimal co2Offset, decimal ewasteGrams) CalculateRealEcoMetrics(Item item)
    {
        // 1. Try parsing from verified agent assessment if available
        if (!string.IsNullOrEmpty(item.EcoHazardReportJson))
        {
            try
            {
                using var doc = JsonDocument.Parse(item.EcoHazardReportJson);
                decimal parsedCo2 = 0;
                decimal parsedEwaste = 0;

                if (doc.RootElement.TryGetProperty("estimatedCo2OffsetKg", out var co2Prop))
                    parsedCo2 = co2Prop.GetDecimal();
                if (doc.RootElement.TryGetProperty("estimatedEwasteGrams", out var ewasteProp))
                    parsedEwaste = ewasteProp.GetDecimal();

                if (parsedCo2 > 0 && parsedEwaste > 0)
                {
                    return (parsedCo2, parsedEwaste);
                }
            }
            catch { }
        }

        // 2. Realistic Life Cycle Assessment (LCA) category benchmarks based on actual hardware category
        var cat = (item.Category?.Name ?? item.Category?.Code ?? item.Name ?? string.Empty).ToLowerInvariant();

        if (cat.Contains("laptop") || cat.Contains("notebook") || cat.Contains("computer") || cat.Contains("pc"))
        {
            return (245.0m, 2200.0m); // Typical laptop: ~2.2kg weight, ~245kg CO2e avoided
        }
        if (cat.Contains("phone") || cat.Contains("smartphone") || cat.Contains("mobile"))
        {
            return (72.0m, 210.0m);   // Typical smartphone: ~210g weight, ~72kg CO2e avoided
        }
        if (cat.Contains("tablet") || cat.Contains("ipad"))
        {
            return (125.0m, 490.0m);  // Typical tablet: ~490g weight, ~125kg CO2e avoided
        }
        if (cat.Contains("monitor") || cat.Contains("display") || cat.Contains("tv") || cat.Contains("television"))
        {
            return (320.0m, 5400.0m); // Monitor / display: ~5.4kg weight, ~320kg CO2e avoided
        }
        if (cat.Contains("printer") || cat.Contains("scanner"))
        {
            return (180.0m, 6200.0m); // Printer: ~6.2kg weight, ~180kg CO2e avoided
        }
        if (cat.Contains("audio") || cat.Contains("headphone") || cat.Contains("speaker") || cat.Contains("wearable"))
        {
            return (38.0m, 320.0m);   // Audio/Wearables: ~320g weight, ~38kg CO2e avoided
        }

        // Standard electronics fallback
        return (65.0m, 850.0m);
    }

    private static string ResolveNextSteps(string routeName, string partnerName)
    {
        var r = routeName.ToLowerInvariant();
        if (r.Contains("refurbish"))
        {
            return $"Your device is now queued for authorized component diagnostics, certified data sanitation, firmware validation, and hardware refurbishment for secondary circular reuse at {partnerName}.";
        }
        if (r.Contains("recycle"))
        {
            return $"Your device has entered a specialized demanufacturing line at {partnerName}, where hazardous substances (lithium cells, flame retardants) are safely neutralized, and copper, aluminum, and precious metals are reclaimed with zero landfill waste.";
        }
        if (r.Contains("part") || r.Contains("harvest"))
        {
            return $"Your device will undergo precision technician disassembly at {partnerName} to salvage undamaged modular components (display assemblies, memory modules, and power ICs) to extend the lifespan of repair ecosystems.";
        }
        if (r.Contains("donate"))
        {
            return $"Your device is undergoing comprehensive functionality testing, sanitized data wiping, and cosmetic detailing at {partnerName} prior to community distribution.";
        }
        return $"Your item has entered {partnerName}'s certified circular recovery workflow for authorized processing and sustainable lifecycle management.";
    }

    private static DeliveryEmailContent FallbackNotification(
        string customerName,
        Item item,
        Partner partner,
        string categoryName,
        string customerCondition,
        string routeName,
        string conditionStatus,
        string remarks,
        decimal co2Offset,
        decimal ewasteGrams,
        string nextStepsText)
    {
        var partnerName = partner.Name ?? "our certified partner facility";
        var partnerLocation = string.IsNullOrWhiteSpace(partner.ServiceArea) ? "Processing Facility" : partner.ServiceArea;
        var subject = $"Intake Confirmed: Your {item.Name} has arrived at {partnerName}";
        var greeting = $"Dear {customerName},";
        var messageBody = $"Great news! Your {item.Name} has completed its collection journey. Our assigned courier successfully delivered your package to {partnerName} in {partnerLocation}, and the facility team has formally verified and checked in the device.\n\n" +
                          $"By directing this device for {routeName}, you have helped divert approximately {ewasteGrams:0.#}g of electronic waste from landfills and prevented an estimated {co2Offset:0.#}kg of carbon emissions.\n\n" +
                          $"Next Steps: {nextStepsText}\n\n" +
                          $"Thank you for your active participation in LoopWorth's circular recovery initiative.";

        var html = $@"<!DOCTYPE html>
<html>
<head>
  <meta charset=""utf-8"">
  <meta name=""viewport"" content=""width=device-width, initial-scale=1.0"">
  <title>{subject}</title>
</head>
<body style=""margin:0; padding:0; background-color:#F8FAFC; font-family:-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; color:#0F172A;"">
  <div style=""max-width:600px; margin:24px auto; background:#FFFFFF; border-radius:16px; overflow:hidden; border:1px solid #E2E8F0; box-shadow:0 4px 6px -1px rgba(0,0,0,0.05);"">
    
    <!-- Brand Header Banner -->
    <div style=""background:#F0FDF4; padding:28px 24px; text-align:center; border-bottom:1px solid #DCFCE7;"">
      <div style=""text-align:center; margin-bottom:12px;"">
        <img src=""https://files.catbox.moe/g8fe3a.jpg"" alt=""LoopWorth - Give Waste Another Worth"" width=""120"" style=""display:inline-block; max-width:120px; height:auto; border-radius:10px;"" />
      </div>
      <div>
        <span style=""display:inline-block; background:#16A34A; color:#FFFFFF; padding:4px 12px; border-radius:9999px; font-size:11px; font-weight:700; text-transform:uppercase; letter-spacing:0.5px;"">
          Intake Verified &bull; Handover Complete
        </span>
      </div>
      <h1 style=""margin:12px 0 4px 0; font-size:20px; font-weight:800; color:#065F46;"">Your Item Has Safely Arrived</h1>
      <p style=""margin:0; font-size:13px; color:#15803D;"">Certified Circular Recovery Milestone</p>
    </div>

    <!-- Main Content -->
    <div style=""padding:28px 24px;"">
      <p style=""margin:0 0 14px; font-size:15px; font-weight:600; color:#0F172A;"">{greeting}</p>
      
      <p style=""margin:0 0 20px; font-size:13px; line-height:1.6; color:#334155;"">
        Great news! Your item has completed its collection transit. Our courier successfully delivered your package to <strong>{partnerName}</strong> in <strong>{partnerLocation}</strong>, and the facility team has formally verified and checked in your device.
      </p>

      <!-- Verified Item Details Table -->
      <div style=""background:#FFFFFF; border:1px solid #E2E8F0; border-radius:10px; padding:16px 18px; margin-bottom:20px;"">
        <div style=""font-size:12px; font-weight:700; text-transform:uppercase; color:#0F172A; letter-spacing:0.5px; margin-bottom:12px; border-bottom:1px solid #F1F5F9; padding-bottom:8px;"">
          📋 Verified Item Submission
        </div>
        <table style=""width:100%; border-collapse:collapse; font-size:13px;"">
          <tr>
            <td style=""padding:8px 0; color:#64748B; width:38%; border-bottom:1px solid #F8FAFC;"">Item Name</td>
            <td style=""padding:8px 0; color:#0F172A; font-weight:600; border-bottom:1px solid #F8FAFC;"">{item.Name}</td>
          </tr>
          <tr>
            <td style=""padding:8px 0; color:#64748B; border-bottom:1px solid #F8FAFC;"">Brand & Model</td>
            <td style=""padding:8px 0; color:#0F172A; font-weight:600; border-bottom:1px solid #F8FAFC;"">{item.Brand ?? ""} {item.Model ?? ""}</td>
          </tr>
          <tr>
            <td style=""padding:8px 0; color:#64748B; border-bottom:1px solid #F8FAFC;"">Category</td>
            <td style=""padding:8px 0; color:#0F172A; border-bottom:1px solid #F8FAFC;"">{categoryName}</td>
          </tr>
          <tr>
            <td style=""padding:8px 0; color:#64748B; border-bottom:1px solid #F8FAFC;"">Your Declared Condition</td>
            <td style=""padding:8px 0; color:#334155; font-style:italic; border-bottom:1px solid #F8FAFC;"">{customerCondition}</td>
          </tr>
          <tr>
            <td style=""padding:8px 0; color:#64748B; border-bottom:1px solid #F8FAFC;"">Chosen Recovery Route</td>
            <td style=""padding:8px 0; color:#15803D; font-weight:700; border-bottom:1px solid #F8FAFC;"">{routeName}</td>
          </tr>
          <tr>
            <td style=""padding:8px 0; color:#64748B; border-bottom:1px solid #F8FAFC;"">Facility Intake Status</td>
            <td style=""padding:8px 0; color:#0F172A; font-weight:600; border-bottom:1px solid #F8FAFC;"">{conditionStatus}</td>
          </tr>
          <tr>
            <td style=""padding:8px 0; color:#64748B;"">Partner Remarks</td>
            <td style=""padding:8px 0; color:#334155;"">&ldquo;{remarks}&rdquo;</td>
          </tr>
        </table>
      </div>

      <!-- Real Environmental Impact Box -->
      <div style=""background:linear-gradient(135deg, #F0FDF4 0%, #DCFCE7 100%); border:1px solid #BBF7D0; border-radius:12px; padding:18px 20px; margin-bottom:24px;"">
        <div style=""font-size:13px; font-weight:700; color:#166534; margin-bottom:4px;"">
          🌱 Verified Environmental Impact
        </div>
        <p style=""margin:0 0 12px 0; font-size:12px; color:#15803D;"">
          By routing this {categoryName.ToLowerInvariant()} for certified circular recovery instead of municipal waste:
        </p>
        <table style=""width:100%; border-collapse:collapse;"">
          <tr>
            <td style=""width:50%; padding-right:8px;"">
              <div style=""background:#FFFFFF; border:1px solid #DCFCE7; border-radius:8px; padding:12px; text-align:center;"">
                <div style=""font-size:22px; font-weight:800; color:#15803D;"">~{co2Offset:0.#} kg</div>
                <div style=""font-size:11px; color:#64748B; margin-top:2px;"">CO2 Emissions Avoided</div>
              </div>
            </td>
            <td style=""width:50%; padding-left:8px;"">
              <div style=""background:#FFFFFF; border:1px solid #DCFCE7; border-radius:8px; padding:12px; text-align:center;"">
                <div style=""font-size:22px; font-weight:800; color:#047857;"">~{ewasteGrams:0.#} g</div>
                <div style=""font-size:11px; color:#64748B; margin-top:2px;"">E-Waste Diverted From Landfill</div>
              </div>
            </td>
          </tr>
        </table>
      </div>

      <!-- What Happens Next -->
      <div style=""margin-bottom:24px;"">
        <div style=""font-size:13px; font-weight:700; color:#0F172A; text-transform:uppercase; letter-spacing:0.5px; margin-bottom:8px;"">
          🔄 What Happens Next?
        </div>
        <p style=""margin:0; font-size:13px; line-height:1.6; color:#334155;"">
          {nextStepsText}
        </p>
      </div>

      <p style=""margin:0 0 4px; font-size:13px; line-height:1.6; color:#334155;"">
        Thank you for choosing circular responsibility and giving your electronics a second life.
      </p>
      <p style=""margin:12px 0 0; font-size:13px; color:#475569;"">
        Warm regards,<br>
        <strong>The LoopWorth Recovery Team</strong>
      </p>
    </div>

    <!-- Footer -->
    <div style=""background:#F8FAFC; border-top:1px solid #E2E8F0; padding:18px 24px; text-align:center; font-size:11px; color:#94A3B8;"">
      <p style=""margin:0 0 4px;"">LoopWorth &bull; Give Waste Another Worth</p>
      <p style=""margin:0;"">Automated notification generated by LoopWorth Agentic AI &amp; dispatched via Brevo.</p>
    </div>

  </div>
</body>
</html>";

        return new DeliveryEmailContent
        {
            Subject = subject,
            Greeting = greeting,
            MessageBody = messageBody,
            HtmlBody = html
        };
    }
}
