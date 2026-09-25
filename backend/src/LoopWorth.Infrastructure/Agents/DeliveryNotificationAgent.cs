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
        _apiKey = configuration["Gemini:CollectionApiKey"]
            ?? configuration["GEMINI_COLLECTION_API_KEY"]
            ?? Environment.GetEnvironmentVariable("GEMINI_COLLECTION_API_KEY")
            ?? configuration["Gemini:ItemsApiKey"]
            ?? string.Empty;
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
        // Extract eco impact metrics if available
        decimal co2Offset = 68.0m;
        decimal ewasteGrams = 240.0m;

        if (!string.IsNullOrEmpty(item.EcoHazardReportJson))
        {
            try
            {
                using var doc = JsonDocument.Parse(item.EcoHazardReportJson);
                if (doc.RootElement.TryGetProperty("estimatedCo2OffsetKg", out var co2Prop))
                    co2Offset = co2Prop.GetDecimal();
                if (doc.RootElement.TryGetProperty("estimatedEwasteGrams", out var ewasteProp))
                    ewasteGrams = ewasteProp.GetDecimal();
            }
            catch { }
        }

        var routeName = item.SelectedRecoveryRoute?.ToString() ?? "Circular Recovery";
        var partnerName = partner.Name ?? "our certified partner facility";
        var partnerLocation = string.IsNullOrWhiteSpace(partner.ServiceArea) ? "Registered Partner Facility" : partner.ServiceArea;
        var conditionStatus = (partnerReceivedConditionOk == true)
            ? "Verified in expected condition"
            : (partnerReceivedConditionOk == false ? "Condition noted with intake observations" : "Intake confirmed");

        var prompt = $@"You are the Customer Notification & Environmental Impact Agent for LoopWorth, an AI-driven electronic waste circular economy platform.
A customer's submitted item has just been collected by our collection courier and delivered successfully to their chosen recovery partner.

Task:
Compose a heartfelt, professional, and inspiring delivery confirmation and thank-you email for the customer.

Input Details:
- Customer Name: {customerName}
- Customer Email: {customerEmail}
- Item: {item.Name} ({item.Brand} {item.Model})
- Category: {item.Category?.Name ?? "Electronics"}
- Chosen Partner: {partnerName} ({partnerLocation})
- Recovery Route: {routeName}
- Intake Status: {conditionStatus}
- Partner Remarks: {partnerFeedback ?? "Item received and checked in at partner facility."}
- Environmental Impact: ~{co2Offset:0.#} kg of CO2 emissions avoided, ~{ewasteGrams:0.#} grams of e-waste diverted from landfill

Requirements:
1. Subject line: Engaging, celebratory, and clear (e.g., 'Delivery Confirmed: Your {item.Name} has reached {partnerName}!')
2. Greeting: Warm, personalized to {customerName}.
3. Body:
   - Announce that their item has been safely transported by the collection agent and handed over to {partnerName}.
   - Emphasize how their decision to choose {routeName} keeps hazardous materials out of landfills and reduces carbon footprint.
   - Highlight the positive environmental impact metrics (~{co2Offset:0.#} kg CO2 avoided, ~{ewasteGrams:0.#} g e-waste saved).
   - Express gratitude on behalf of LoopWorth for driving the circular electronics economy.
4. Output format: Respond in valid JSON with:
   - 'subject': string
   - 'greeting': string
   - 'messageBody': plain text summary (2-3 paragraphs)
   - 'htmlBody': full responsive HTML email template using inline CSS (colors: #16A34A forest green, #0F172A slate text, #F0FDF4 eco background card, clean button/footer).

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
            _logger.LogWarning(ex, "Gemini delivery notification agent call failed. Using deterministic notification template.");
        }

        return FallbackNotification(customerName, item, partner, routeName, co2Offset, ewasteGrams, partnerFeedback);
    }

    private static DeliveryEmailContent FallbackNotification(
        string customerName,
        Item item,
        Partner partner,
        string routeName,
        decimal co2Offset,
        decimal ewasteGrams,
        string? partnerFeedback)
    {
        var subject = $"Delivery Confirmed: Your {item.Name} has arrived at {partner.Name}!";
        var greeting = $"Hello {customerName},";
        var messageBody = $"Great news! Your {item.Name} has been safely collected and delivered to our trusted partner, {partner.Name}. " +
                          $"Thank you for participating in LoopWorth's circular recovery initiative. By routing this device for {routeName}, " +
                          $"you have helped divert approximately {ewasteGrams:0.#}g of electronic waste from landfills and saved an estimated {co2Offset:0.#}kg of carbon emissions. " +
                          $"Your proactive decision makes a lasting difference for our environment.";

        var html = $@"
<!DOCTYPE html>
<html>
<head>
  <meta charset=""utf-8"">
  <meta name=""viewport"" content=""width=device-width, initial-scale=1.0"">
  <title>{subject}</title>
</head>
<body style=""margin:0; padding:0; background-color:#F8FAFC; font-family:-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; color:#0F172A;"">
  <div style=""max-width:600px; margin:24px auto; background:#FFFFFF; border-radius:12px; overflow:hidden; border:1px solid #E2E8F0; box-shadow:0 4px 6px -1px rgba(0,0,0,0.05);"">
    
    <!-- Header Banner -->
    <div style=""background:linear-gradient(135deg, #15803D 0%, #16A34A 100%); padding:28px 24px; text-align:center; color:#FFFFFF;"">
      <div style=""display:inline-block; background:rgba(255,255,255,0.2); padding:6px 14px; border-radius:20px; font-size:12px; font-weight:700; letter-spacing:0.5px; text-transform:uppercase; margin-bottom:8px;"">
        LoopWorth Circular Recovery
      </div>
      <h1 style=""margin:0; font-size:22px; font-weight:700; color:#FFFFFF;"">Delivery Confirmed & Received</h1>
      <p style=""margin:6px 0 0; font-size:14px; color:#DCFCE7;"">Thank you for making a sustainable environmental impact</p>
    </div>

    <!-- Main Content -->
    <div style=""padding:28px 24px;"">
      <p style=""margin:0 0 16px; font-size:16px; font-weight:600; color:#0F172A;"">{greeting}</p>
      
      <p style=""margin:0 0 18px; font-size:14px; line-height:1.6; color:#334155;"">
        We are thrilled to let you know that your <strong>{item.Name}</strong> has been successfully transported by our collection agent and safely handed over to our partner, <strong>{partner.Name}</strong>.
      </p>

      <!-- Delivery Summary Card -->
      <div style=""background:#F1F5F9; border-radius:8px; padding:16px 20px; margin-bottom:20px;"">
        <div style=""font-size:12px; font-weight:700; text-transform:uppercase; color:#64748B; margin-bottom:10px;"">Delivery Handover Details</div>
        <table style=""width:100%; border-collapse:collapse; font-size:13px;"">
          <tr>
            <td style=""padding:4px 0; color:#64748B; width:130px;"">Device:</td>
            <td style=""padding:4px 0; color:#0F172A; font-weight:600;"">{item.Name} ({item.Brand} {item.Model})</td>
          </tr>
          <tr>
            <td style=""padding:4px 0; color:#64748B;"">Selected Partner:</td>
            <td style=""padding:4px 0; color:#0F172A; font-weight:600;"">{partner.Name}</td>
          </tr>
          <tr>
            <td style=""padding:4px 0; color:#64748B;"">Facility Location:</td>
            <td style=""padding:4px 0; color:#0F172A;"">{(string.IsNullOrWhiteSpace(partner.ServiceArea) ? "Partner Processing Facility" : partner.ServiceArea)}</td>
          </tr>
          <tr>
            <td style=""padding:4px 0; color:#64748B;"">Recovery Route:</td>
            <td style=""padding:4px 0; color:#15803D; font-weight:700;"">{routeName}</td>
          </tr>
        </table>
      </div>

      <!-- Eco Impact Metric Highlight -->
      <div style=""background:#F0FDF4; border:1px solid #BBF7D0; border-radius:8px; padding:18px 20px; margin-bottom:24px;"">
        <div style=""font-size:13px; font-weight:700; color:#166534; display:flex; align-items:center; margin-bottom:10px;"">
          🌱 Your Circular Environmental Impact
        </div>
        <div style=""display:flex; justify-content:space-around; text-align:center; padding:8px 0;"">
          <div style=""display:inline-block; margin-right:24px;"">
            <span style=""font-size:24px; font-weight:800; color:#15803D;"">~{co2Offset:0.#} kg</span>
            <div style=""font-size:12px; color:#166534; margin-top:2px;"">CO2 Emissions Avoided</div>
          </div>
          <div style=""display:inline-block;"">
            <span style=""font-size:24px; font-weight:800; color:#047857;"">~{ewasteGrams:0.#} g</span>
            <div style=""font-size:12px; color:#065F46; margin-top:2px;"">E-Waste Diverted From Landfills</div>
          </div>
        </div>
      </div>

      <p style=""margin:0 0 16px; font-size:14px; line-height:1.6; color:#334155;"">
        Every electronic device recovered is a step towards a cleaner, greener circular future. Thank you for your leadership and responsible environmental stewardship!
      </p>

      <p style=""margin:0; font-size:14px; color:#475569;"">
        Warm regards,<br>
        <strong>The LoopWorth Recovery Team</strong>
      </p>
    </div>

    <!-- Footer -->
    <div style=""background:#F8FAFC; border-top:1px solid #E2E8F0; padding:16px 24px; text-align:center; font-size:12px; color:#94A3B8;"">
      <p style=""margin:0 0 4px;"">Sent by LoopWorth Circular Recovery Platform via Brevo</p>
      <p style=""margin:0;"">Building a cleaner world through transparent e-waste recovery & circular reuse.</p>
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
