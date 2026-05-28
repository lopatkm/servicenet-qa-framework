// ─────────────────────────────────────────────────────────────────────────────
// TEMPLATE FILE — copy to tests/YourApp.Tests.E2E/Infrastructure/BlazorPageBase.cs
// Update the namespace to match your project.
// ─────────────────────────────────────────────────────────────────────────────

// Replace with your project's namespace:
// namespace YourApp.Tests.E2E.Infrastructure;

namespace ServiceNet.Tests.Infrastructure;

/// <summary>
/// Base helpers for testing Blazor Server pages.
/// Handles loading-state waits and common Blazor rendering patterns.
///
/// Usage: inherit in page-object classes.
///   public sealed class MyFeaturePage(IPage page) : BlazorPageBase(page) { ... }
///
/// CSS class conventions expected (match your app's CSS):
///   .loading-state      — shown while data is loading
///   .empty-state        — shown when there is no data or an error
///   .drilldown-summary  — summary stats strip (label/value pairs)
/// </summary>
public abstract class BlazorPageBase(IPage page)
{
    protected IPage Page { get; } = page;

    /// <summary>
    /// Waits until the .loading-state element disappears from the DOM.
    /// Increase timeoutMs for pages with slow SQL queries.
    /// </summary>
    protected async Task WaitForLoadAsync(int timeoutMs = 15000)
    {
        await Page.WaitForFunctionAsync(
            "() => !document.querySelector('.loading-state')",
            null,
            new PageWaitForFunctionOptions { Timeout = timeoutMs });
    }

    /// <summary>
    /// Returns the inner text of .empty-state if present, otherwise null.
    /// Use to assert that error states appear when expected, or are absent.
    /// </summary>
    protected async Task<string?> GetErrorStateTextAsync()
    {
        var el = await Page.QuerySelectorAsync(".empty-state");
        return el is null ? null : await el.InnerTextAsync();
    }

    /// <summary>
    /// Reads all .drilldown-summary label/value pairs into a dictionary.
    /// Keys are the span text; values are the strong text.
    /// </summary>
    protected async Task<Dictionary<string, string>> GetSummaryStatsAsync()
    {
        return await Page.EvaluateAsync<Dictionary<string, string>>(@"() => {
            const result = {};
            document.querySelectorAll('.drilldown-summary > div').forEach(d => {
                const label = d.querySelector('span')?.innerText?.trim();
                const value = d.querySelector('strong')?.innerText?.trim();
                if (label) result[label] = value;
            });
            return result;
        }");
    }

    /// <summary>
    /// Returns all visible table rows as arrays of trimmed cell text.
    /// </summary>
    protected async Task<List<string[]>> GetTableRowsAsync(string selector = "tbody tr")
    {
        return await Page.EvaluateAsync<List<string[]>>($@"() =>
            Array.from(document.querySelectorAll('{selector}')).map(row =>
                Array.from(row.querySelectorAll('td')).map(td => td.innerText.trim()))");
    }

    /// <summary>
    /// Returns true if the current page URL is not an Azure AD login page.
    /// </summary>
    protected bool IsAuthenticated()
    {
        var url = Page.Url;
        return !url.Contains("microsoftonline") && !url.Contains("login.microsoft");
    }
}
