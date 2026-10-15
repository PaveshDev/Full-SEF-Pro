using System.Text;
using LoopWorth.Application.Interfaces;
using LoopWorth.Infrastructure.Agents;
using LoopWorth.Infrastructure.Data;
using LoopWorth.Infrastructure.Identity;
using LoopWorth.Infrastructure.Services;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;

// Load .env file if present
Program.LoadDotEnvFiles();

var builder = WebApplication.CreateBuilder(args);

// Propagate non-empty environment variables into builder.Configuration
var envBrevoKey = Environment.GetEnvironmentVariable("BREVO_API_KEY");
if (!string.IsNullOrWhiteSpace(envBrevoKey))
{
    builder.Configuration["Brevo:ApiKey"] = envBrevoKey;
    builder.Configuration["BREVO_API_KEY"] = envBrevoKey;
}
var envBrevoSender = Environment.GetEnvironmentVariable("BREVO_SENDER_EMAIL");
if (!string.IsNullOrWhiteSpace(envBrevoSender))
{
    builder.Configuration["Brevo:SenderEmail"] = envBrevoSender;
}
var envBrevoName = Environment.GetEnvironmentVariable("BREVO_SENDER_NAME");
if (!string.IsNullOrWhiteSpace(envBrevoName))
{
    builder.Configuration["Brevo:SenderName"] = envBrevoName;
}

// Cloudinary Cloud Storage
var envCloudName = Environment.GetEnvironmentVariable("CLOUDINARY_CLOUD_NAME");
var envCloudKey = Environment.GetEnvironmentVariable("CLOUDINARY_API_KEY");
var envCloudSecret = Environment.GetEnvironmentVariable("CLOUDINARY_API_SECRET");
var envCloudUrl = Environment.GetEnvironmentVariable("CLOUDINARY_URL");
if (!string.IsNullOrWhiteSpace(envCloudName)) builder.Configuration["CLOUDINARY_CLOUD_NAME"] = envCloudName;
if (!string.IsNullOrWhiteSpace(envCloudKey)) builder.Configuration["CLOUDINARY_API_KEY"] = envCloudKey;
if (!string.IsNullOrWhiteSpace(envCloudSecret)) builder.Configuration["CLOUDINARY_API_SECRET"] = envCloudSecret;
if (!string.IsNullOrWhiteSpace(envCloudUrl)) builder.Configuration["CLOUDINARY_URL"] = envCloudUrl;

// Controllers
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.AddSecurityDefinition("Bearer", new Microsoft.OpenApi.Models.OpenApiSecurityScheme
    {
        Name = "Authorization",
        Type = Microsoft.OpenApi.Models.SecuritySchemeType.Http,
        Scheme = "bearer",
        BearerFormat = "JWT",
        In = Microsoft.OpenApi.Models.ParameterLocation.Header,
        Description = "Enter your JWT token"
    });
    c.AddSecurityRequirement(new Microsoft.OpenApi.Models.OpenApiSecurityRequirement
    {
        {
            new Microsoft.OpenApi.Models.OpenApiSecurityScheme
            {
                Reference = new Microsoft.OpenApi.Models.OpenApiReference
                {
                    Type = Microsoft.OpenApi.Models.ReferenceType.SecurityScheme,
                    Id = "Bearer"
                }
            },
            Array.Empty<string>()
        }
    });
});

builder.Services.AddProblemDetails();

// Database
var rawConnectionString = builder.Configuration.GetConnectionString("DefaultConnection")
    ?? Environment.GetEnvironmentVariable("ConnectionStrings__DefaultConnection")
    ?? Environment.GetEnvironmentVariable("CONNECTION_STRING")
    ?? builder.Configuration["CONNECTION_STRING"];

string? connectionString = null;
if (!string.IsNullOrWhiteSpace(rawConnectionString) && !rawConnectionString.Contains("<NEON_HOST>"))
{
    connectionString = NormalizeConnectionString(rawConnectionString);
}

if (!string.IsNullOrWhiteSpace(connectionString))
{
    builder.Services.AddDbContext<AppDbContext>(options =>
        options.UseNpgsql(connectionString, npgsql =>
            npgsql.EnableRetryOnFailure(5, TimeSpan.FromSeconds(5), null)));
}
else
{
    // Fast, zero-config in-memory database for immediate developer manual testing out-of-the-box
    builder.Services.AddDbContext<AppDbContext>(options =>
        options.UseInMemoryDatabase("LoopWorthManualTestDb"));
}

// Identity
builder.Services.AddIdentity<ApplicationUser, IdentityRole>(options =>
{
    options.Password.RequireDigit = true;
    options.Password.RequiredLength = 6;
    options.Password.RequireNonAlphanumeric = false;
    options.Password.RequireUppercase = false;
    options.Password.RequireLowercase = false;
})
.AddEntityFrameworkStores<AppDbContext>()
.AddDefaultTokenProviders();

// JWT
var jwtSecret = builder.Configuration["JwtSettings:Secret"]
    ?? builder.Configuration["JWT_SECRET"]
    ?? Environment.GetEnvironmentVariable("JWT_SECRET")
    ?? "DevOnly-LoopWorth-Secret-Key-Minimum-32-Characters-Long!";
var jwtIssuer = builder.Configuration["JwtSettings:Issuer"]
    ?? builder.Configuration["JWT_ISSUER"]
    ?? Environment.GetEnvironmentVariable("JWT_ISSUER")
    ?? "LoopWorth";
var jwtAudience = builder.Configuration["JwtSettings:Audience"]
    ?? builder.Configuration["JWT_AUDIENCE"]
    ?? Environment.GetEnvironmentVariable("JWT_AUDIENCE")
    ?? "LoopWorth";

builder.Services.AddAuthentication(options =>
{
    options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
    options.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
})
.AddJwtBearer(options =>
{
    options.TokenValidationParameters = new TokenValidationParameters
    {
        ValidateIssuer = true,
        ValidateAudience = true,
        ValidateLifetime = true,
        ValidateIssuerSigningKey = true,
        ValidIssuer = jwtIssuer,
        ValidAudience = jwtAudience,
        IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtSecret))
    };
});

// DI: Services
builder.Services.AddHttpClient();
var hasCloudinary = !string.IsNullOrWhiteSpace(builder.Configuration["CLOUDINARY_API_KEY"]
    ?? Environment.GetEnvironmentVariable("CLOUDINARY_API_KEY")
    ?? builder.Configuration["CLOUDINARY_URL"]
    ?? Environment.GetEnvironmentVariable("CLOUDINARY_URL"));

if (hasCloudinary)
{
    Console.WriteLine("[LoopWorth Storage] Initializing CloudinaryFileStorageService for uploads...");
    builder.Services.AddScoped<IFileStorageService, CloudinaryFileStorageService>();
}
else
{
    Console.WriteLine("[LoopWorth Storage] Cloudinary credentials not found. Using LocalFileStorageService...");
    builder.Services.AddScoped<IFileStorageService, LocalFileStorageService>();
}


builder.Services.AddScoped<IEcoImpactAgent, EcoImpactAgent>();
builder.Services.AddScoped<IItemAssessmentAgent, ItemAssessmentAgent>();
builder.Services.AddScoped<IRecoveryPlanningAgent, RecoveryPlanningAgent>();
builder.Services.AddScoped<IPartnerMatchingAgent, PartnerMatchingAgent>();
builder.Services.AddScoped<ICollectionPlanningAgent, CollectionPlanningAgent>();
builder.Services.AddScoped<IEmailService, BrevoEmailService>();
builder.Services.AddScoped<IDeliveryNotificationAgent, DeliveryNotificationAgent>();

// CORS
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAll", policy =>
        policy.AllowAnyOrigin()
            .AllowAnyHeader()
            .AllowAnyMethod());
});

var app = builder.Build();

app.UseForwardedHeaders(new ForwardedHeadersOptions
{
    ForwardedHeaders = Microsoft.AspNetCore.HttpOverrides.ForwardedHeaders.XForwardedFor | Microsoft.AspNetCore.HttpOverrides.ForwardedHeaders.XForwardedProto
});

// Middleware pipeline
app.UseSwagger();
app.UseSwaggerUI();
app.UseCors("AllowAll");

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler();
}

// Serve uploaded files
var uploadsDir = Path.Combine(builder.Environment.ContentRootPath, "uploads");
Directory.CreateDirectory(uploadsDir);
app.UseStaticFiles();
app.UseStaticFiles(new StaticFileOptions
{
    FileProvider = new Microsoft.Extensions.FileProviders.PhysicalFileProvider(uploadsDir),
    RequestPath = "/uploads"
});

app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();
app.MapGet("/", () => Results.Redirect("/swagger"));

// Seed on startup
try
{
    using var scope = app.Services.CreateScope();
    var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    await db.Database.EnsureCreatedAsync();
    await DbInitializer.SeedAsync(scope.ServiceProvider);
}
catch (Exception ex)
{
    app.Logger.LogWarning(ex, "Database seeding was skipped or encountered an error on startup.");
}

app.Run();

// Make Program accessible for integration tests
public partial class Program
{
    public static string NormalizeConnectionString(string raw)
    {
        if (string.IsNullOrWhiteSpace(raw)) return raw;
        if (raw.StartsWith("postgresql://", StringComparison.OrdinalIgnoreCase) ||
            raw.StartsWith("postgres://", StringComparison.OrdinalIgnoreCase))
        {
            var uri = new Uri(raw);
            var userInfo = uri.UserInfo.Split(':');
            var username = Uri.UnescapeDataString(userInfo[0]);
            var password = userInfo.Length > 1 ? Uri.UnescapeDataString(userInfo[1]) : "";
            var port = uri.Port > 0 ? uri.Port : 5432;
            var database = uri.AbsolutePath.TrimStart('/');
            return $"Host={uri.Host};Port={port};Database={database};Username={username};Password={password};SSL Mode=Require;Trust Server Certificate=true;Keepalive=30;Pooling=true;Minimum Pool Size=2;Maximum Pool Size=20;";
        }
        return raw;
    }

    public static void LoadDotEnvFiles()
    {
        var candidates = new[]
        {
            Directory.GetCurrentDirectory(),
            AppContext.BaseDirectory,
            Path.GetFullPath(Path.Combine(Directory.GetCurrentDirectory(), "..")),
            Path.GetFullPath(Path.Combine(Directory.GetCurrentDirectory(), "..", ".."))
        };

        foreach (var dir in candidates)
        {
            var envFile = Path.Combine(dir, ".env");
            if (File.Exists(envFile))
            {
                foreach (var rawLine in File.ReadAllLines(envFile))
                {
                    var line = rawLine.Trim();
                    if (string.IsNullOrWhiteSpace(line) || line.StartsWith("#")) continue;
                    var parts = line.Split('=', 2);
                    if (parts.Length == 2)
                    {
                        var key = parts[0].Trim();
                        var val = parts[1].Trim();
                        if (string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable(key)))
                        {
                            Environment.SetEnvironmentVariable(key, val);
                        }
                    }
                }
                break;
            }
        }
    }
}
