using Microsoft.AspNetCore.Identity;

namespace LoopWorth.Infrastructure.Identity;

public class ApplicationUser : IdentityUser
{
    public string FullName { get; set; } = string.Empty;
    public string Name { get => FullName; set => FullName = value; }
    public string? Address { get; set; }
    public string? District { get; set; }
    public string? Town { get; set; }
}
