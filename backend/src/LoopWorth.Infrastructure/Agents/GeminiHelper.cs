using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace LoopWorth.Infrastructure.Agents;

/// <summary>
/// Shared helper for all Gemini agent calls. Handles REST call, response parsing, and markdown cleanup.
/// </summary>
public static class GeminiHelper
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNameCaseInsensitive = true,
        Converters = { new System.Text.Json.Serialization.JsonStringEnumConverter() }
    };

    public static async Task<string> CallGeminiAsync(
        HttpClient httpClient,
        string apiKey,
        string prompt,
        ILogger logger,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrEmpty(apiKey))
        {
            throw new InvalidOperationException("Gemini API key is missing.");
        }

        var requestBody = new
        {
            contents = new[]
            {
                new { parts = new[] { new { text = prompt } } }
            }
        };

        var models = new[] { "gemini-flash-lite-latest", "gemini-flash-latest" };

        HttpResponseMessage? response = null;
        string error = string.Empty;

        for (int attempt = 1; attempt <= 2; attempt++)
        {
            var modelName = models[Math.Min(attempt - 1, models.Length - 1)];
            var url = $"https://generativelanguage.googleapis.com/v1beta/models/{modelName}:generateContent?key={apiKey}";
            using var cts = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
            cts.CancelAfter(TimeSpan.FromSeconds(15));

            try
            {
                response = await httpClient.PostAsJsonAsync(url, requestBody, cts.Token);
                if (response.IsSuccessStatusCode)
                    break;

                error = await response.Content.ReadAsStringAsync(cts.Token);
                var statusCode = (int)response.StatusCode;

                // Retry on 503 (High demand / unavailable), 429 (Rate limit), or 500+
                if (statusCode == 503 || statusCode == 429 || statusCode >= 500)
                {
                    logger.LogWarning("Gemini API attempt {Attempt} with {Model} received {Status}. Retrying with next model...", attempt, modelName, response.StatusCode);
                    if (attempt < 2)
                    {
                        await Task.Delay(500, cancellationToken);
                        continue;
                    }
                }
                else
                {
                    break;
                }
            }
            catch (OperationCanceledException) when (!cancellationToken.IsCancellationRequested)
            {
                logger.LogWarning("Gemini API attempt {Attempt} timed out after 15s. Switching to domain-tailored generation.", attempt);
                break;
            }
            catch (HttpRequestException ex) when (attempt < 2)
            {
                logger.LogWarning(ex, "Gemini API HTTP request attempt {Attempt} failed. Retrying...", attempt);
                await Task.Delay(1000, cancellationToken);
            }
        }

        if (response == null || !response.IsSuccessStatusCode)
        {
            logger.LogError("Gemini API failed with status {Status}: {Error}", response?.StatusCode, error);
            throw new Exception($"AI service error ({response?.StatusCode}): {(error.Length > 200 ? error[..200] : error)}");
        }

        var jsonResponse = await response.Content.ReadFromJsonAsync<JsonElement>(cancellationToken);

        var candidate = jsonResponse.GetProperty("candidates")[0];
        var parts = candidate.GetProperty("content").GetProperty("parts");
        var textBuilder = new System.Text.StringBuilder();

        foreach (var part in parts.EnumerateArray())
        {
            if (part.TryGetProperty("text", out var textProp))
            {
                var val = textProp.GetString();
                if (!string.IsNullOrEmpty(val))
                {
                    textBuilder.Append(val);
                }
            }
        }

        var textResult = textBuilder.ToString();

        if (string.IsNullOrWhiteSpace(textResult))
            throw new Exception("Empty response from AI service.");

        return CleanJsonResponse(textResult);
    }

    public static T DeserializeResponse<T>(string json)
    {
        var result = JsonSerializer.Deserialize<T>(json, JsonOptions);
        if (result == null) throw new Exception("Failed to parse AI response.");
        return result;
    }

    private static string CleanJsonResponse(string text)
    {
        var trimmed = text.Trim();
        if (trimmed.StartsWith("```json"))
            trimmed = trimmed[7..];
        else if (trimmed.StartsWith("```"))
            trimmed = trimmed[3..];

        if (trimmed.EndsWith("```"))
            trimmed = trimmed[..^3];

        return trimmed.Trim();
    }
}
