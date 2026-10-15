using CloudinaryDotNet;
using CloudinaryDotNet.Actions;
using LoopWorth.Application.Interfaces;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace LoopWorth.Infrastructure.Services;

public class CloudinaryFileStorageService : IFileStorageService
{
    private readonly Cloudinary _cloudinary;
    private readonly ILogger<CloudinaryFileStorageService> _logger;

    public CloudinaryFileStorageService(IConfiguration config, ILogger<CloudinaryFileStorageService> logger)
    {
        _logger = logger;

        var cloudName = config["Cloudinary:CloudName"]
            ?? Environment.GetEnvironmentVariable("CLOUDINARY_CLOUD_NAME")
            ?? "hpv7anoh";
        var apiKey = config["Cloudinary:ApiKey"]
            ?? Environment.GetEnvironmentVariable("CLOUDINARY_API_KEY")
            ?? "958446124794267";
        var apiSecret = config["Cloudinary:ApiSecret"]
            ?? Environment.GetEnvironmentVariable("CLOUDINARY_API_SECRET")
            ?? "xx3n-8ERz_QGJWfSGfoQEWTBJSw";

        var cloudinaryUrl = config["CLOUDINARY_URL"] ?? Environment.GetEnvironmentVariable("CLOUDINARY_URL");
        if (!string.IsNullOrWhiteSpace(cloudinaryUrl))
        {
            _cloudinary = new Cloudinary(cloudinaryUrl);
        }
        else
        {
            var account = new Account(cloudName, apiKey, apiSecret);
            _cloudinary = new Cloudinary(account);
        }
        _cloudinary.Api.Secure = true;
    }

    public async Task<string> SaveFileAsync(Stream fileStream, string fileName, string folder)
    {
        var uploadParams = new ImageUploadParams
        {
            File = new FileDescription(fileName, fileStream),
            Folder = folder,
            PublicId = Guid.NewGuid().ToString(),
            Overwrite = true
        };

        var uploadResult = await _cloudinary.UploadAsync(uploadParams);
        if (uploadResult.Error != null)
        {
            _logger.LogError("Cloudinary upload failed: {Error}", uploadResult.Error.Message);
            throw new InvalidOperationException($"Cloudinary upload failed: {uploadResult.Error.Message}");
        }

        var secureUrl = uploadResult.SecureUrl?.ToString() ?? uploadResult.Url?.ToString();
        _logger.LogInformation("File uploaded to Cloudinary successfully: {Url}", secureUrl);
        return secureUrl ?? throw new InvalidOperationException("Cloudinary did not return a valid URL.");
    }

    public async Task DeleteFileAsync(string filePath)
    {
        if (string.IsNullOrWhiteSpace(filePath)) return;

        try
        {
            if (filePath.Contains("res.cloudinary.com"))
            {
                var uri = new Uri(filePath);
                var segments = uri.AbsolutePath.Split('/');
                var uploadIdx = Array.IndexOf(segments, "upload");
                if (uploadIdx >= 0 && uploadIdx < segments.Length - 1)
                {
                    var startIdx = uploadIdx + 1;
                    if (startIdx < segments.Length && segments[startIdx].StartsWith("v") && long.TryParse(segments[startIdx].Substring(1), out _))
                    {
                        startIdx++;
                    }
                    var publicIdWithExt = string.Join("/", segments.Skip(startIdx));
                    var publicId = Path.ChangeExtension(publicIdWithExt, null);

                    var destroyParams = new DeletionParams(publicId);
                    await _cloudinary.DestroyAsync(destroyParams);
                }
            }
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to delete file from Cloudinary: {Path}", filePath);
        }
    }
}
