using System.Net.Http.Json;
using System.Text.Json;
using LoopWorth.Application.Interfaces;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace LoopWorth.Infrastructure.Services;

public class BrevoEmailService : IEmailService
{
    private readonly HttpClient _httpClient;
    private readonly string _apiKey;
    private readonly string _senderEmail;
    private readonly string _senderName;
    private readonly ILogger<BrevoEmailService> _logger;

    public BrevoEmailService(HttpClient httpClient, IConfiguration configuration, ILogger<BrevoEmailService> logger)
    {
        _httpClient = httpClient;
        _logger = logger;
        _apiKey = configuration["Brevo:ApiKey"]
            ?? configuration["BREVO_API_KEY"]
            ?? Environment.GetEnvironmentVariable("BREVO_API_KEY")
            ?? string.Empty;

        _senderEmail = configuration["Brevo:SenderEmail"]
            ?? configuration["BREVO_SENDER_EMAIL"]
            ?? Environment.GetEnvironmentVariable("BREVO_SENDER_EMAIL")
            ?? "loopworthadmin@gmail.com";

        _senderName = configuration["Brevo:SenderName"]
            ?? configuration["BREVO_SENDER_NAME"]
            ?? Environment.GetEnvironmentVariable("BREVO_SENDER_NAME")
            ?? "LoopWorth Circular Recovery";
    }

    public async Task<bool> SendEmailAsync(string toEmail, string toName, string subject, string htmlContent, CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(toEmail))
        {
            _logger.LogWarning("Cannot send email: recipient email address is empty.");
            return false;
        }

        if (string.IsNullOrWhiteSpace(_apiKey))
        {
            _logger.LogWarning("Brevo API key is not configured. Email will not be sent.");
            return false;
        }

        var payload = new
        {
            sender = new
            {
                name = _senderName,
                email = _senderEmail
            },
            to = new[]
            {
                new
                {
                    email = toEmail,
                    name = string.IsNullOrWhiteSpace(toName) ? toEmail : toName
                }
            },
            subject = subject,
            htmlContent = htmlContent
        };

        try
        {
            using var request = new HttpRequestMessage(HttpMethod.Post, "https://api.brevo.com/v3/smtp/email")
            {
                Content = JsonContent.Create(payload)
            };

            request.Headers.Add("api-key", _apiKey);
            request.Headers.Add("accept", "application/json");

            var response = await _httpClient.SendAsync(request, cancellationToken);
            var responseContent = await response.Content.ReadAsStringAsync(cancellationToken);

            if (response.IsSuccessStatusCode)
            {
                _logger.LogInformation("Brevo transactional email sent successfully to {Recipient} with subject '{Subject}'. Response: {Response}", toEmail, subject, responseContent);
                return true;
            }
            else
            {
                _logger.LogError("Brevo API returned error status {Status} when sending to {Recipient}: {Error}", response.StatusCode, toEmail, responseContent);
                return false;
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Exception occurred while sending Brevo email to {Recipient}", toEmail);
            return false;
        }
    }
}
