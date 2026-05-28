// ─────────────────────────────────────────────────────────────────────────────
// TEMPLATE FILE — copy to tests/YourApp.Tests.E2E/Infrastructure/E2ETestBase.cs
// Update the namespace to match your project. No other changes required.
// ─────────────────────────────────────────────────────────────────────────────

// Replace with your project's namespace:
// namespace YourApp.Tests.E2E.Infrastructure;

namespace ServiceNet.Tests.Infrastructure;

/// <summary>
/// Base class for all ServiceNet E2E test classes. Manages Playwright browser lifecycle.
///
/// Usage:
///   public sealed class MyFeatureTests : ServiceNetTestBase { ... }
///
/// Each test class gets one Chromium browser (shared across test methods in that class).
/// Each test method should call NewPageAsync() to get a fresh context and page.
/// Always dispose the context at the end of each test: await ctx.DisposeAsync().
///
/// Auth state:
///   Requires a saved auth.json file (captured via qa-save-auth.js).
///   Auth file path is read from the E2E_AUTH_PATH environment variable,
///   falling back to "auth.json" in the working directory.
///
/// Environment variables:
///   E2E_BASE_URL    — app URL (default: https://localhost:7052)
///   E2E_AUTH_PATH   — path to auth state JSON (default: auth.json)
///   E2E_HEADLESS    — set to "false" to watch the browser (default: headless)
/// </summary>
public abstract class ServiceNetTestBase : IAsyncLifetime
{
    protected IPlaywright Playwright { get; private set; } = null!;
    protected IBrowser    Browser    { get; private set; } = null!;

    public async Task InitializeAsync()
    {
        Playwright = await Microsoft.Playwright.Playwright.CreateAsync();
        Browser = await Playwright.Chromium.LaunchAsync(new BrowserTypeLaunchOptions
        {
            Headless          = TestConfig.Headless,
            IgnoreDefaultArgs = ["--disable-extensions"],
        });
    }

    public async Task DisposeAsync()
    {
        await Browser.DisposeAsync();
        Playwright.Dispose();
    }

    /// <summary>
    /// Creates a new browser context loaded with saved Azure AD auth state,
    /// and opens a fresh page. Dispose the returned context after each test method.
    /// </summary>
    protected async Task<(IBrowserContext Context, IPage Page)> NewPageAsync()
    {
        var authPath = TestConfig.AuthStatePath;
        if (!File.Exists(authPath))
            throw new InvalidOperationException(
                $"Auth state not found at '{authPath}'. " +
                "Run: node qa-save-auth.js --url <app-url> from the repo root.");

        var context = await Browser.NewContextAsync(new BrowserNewContextOptions
        {
            StorageStatePath  = authPath,
            IgnoreHTTPSErrors = true,
        });
        var page = await context.NewPageAsync();
        return (context, page);
    }
}

/// <summary>
/// Placeholder — replace with your project's actual TestConfig.
/// </summary>
file static class TestConfig
{
    public static string BaseUrl       => Environment.GetEnvironmentVariable("E2E_BASE_URL")  ?? "https://localhost:7052";
    public static string AuthStatePath => Environment.GetEnvironmentVariable("E2E_AUTH_PATH") ?? "auth.json";
    public static bool   Headless      => Environment.GetEnvironmentVariable("E2E_HEADLESS")  != "false";
}
