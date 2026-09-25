using System.Net;
using System.Net.Http.Json;
using LoopWorth.Application.DTOs;
using Xunit;

namespace LoopWorth.IntegrationTests;

public class AuthEndpointsTests : IClassFixture<CustomWebApplicationFactory>
{
    private readonly HttpClient _client;

    public AuthEndpointsTests(CustomWebApplicationFactory factory)
    {
        _client = factory.CreateClient();
    }

    [Fact]
    public async Task Register_ValidCustomer_ReturnsTokenAndProfile()
    {
        var email = $"customer_{Guid.NewGuid():N}@loopworth.test";
        var registerDto = new RegisterDto
        {
            Name = "Amara Dias",
            Email = email,
            Password = "Password123!",
            Phone = "0771234567",
            Address = "12 Main St",
            District = "Colombo",
            Town = "Colombo 03"
        };

        var response = await _client.PostAsJsonAsync("/api/auth/register", registerDto);
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var result = await response.Content.ReadFromJsonAsync<AuthResponseDto>();
        Assert.NotNull(result);
        Assert.NotEmpty(result.Token);
        Assert.Equal("Amara Dias", result.Name);
        Assert.Equal("Customer", result.Role);
    }

    [Fact]
    public async Task Login_InvalidPassword_ReturnsUnauthorized()
    {
        var loginDto = new LoginDto
        {
            Email = "loopworthadmin@gmail.com",
            Password = "WrongPassword!"
        };

        var response = await _client.PostAsJsonAsync("/api/auth/login", loginDto);
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task ProtectedEndpoint_WithoutToken_ReturnsUnauthorized()
    {
        var response = await _client.GetAsync("/api/items");
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task GetCategories_ReturnsSeededCategories()
    {
        var response = await _client.GetAsync("/api/categories");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var categories = await response.Content.ReadFromJsonAsync<List<CategoryDto>>();
        Assert.NotNull(categories);
        Assert.NotEmpty(categories);
        Assert.Contains(categories, c => c.Code == "PHONE");
    }
}
