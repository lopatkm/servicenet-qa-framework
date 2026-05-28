<#
.SYNOPSIS
    ServiceNet QA Framework — one-command installer.
    Scaffolds Unit, Integration, and E2E test projects for any ServiceNet Blazor Server app.

.USAGE
    # One-command from project root:
    iex (irm https://raw.githubusercontent.com/lopatkm/servicenet-qa-framework/main/install.ps1)

    # Local (after cloning ai-agent-config):
    & "$env:CODE_DIR\ai-agent-config\qa-template\install.ps1"

    # With explicit names:
    & "$env:CODE_DIR\ai-agent-config\qa-template\install.ps1" -AppName "MyApp"

.PARAMETER AppName
    Base name for test projects. Defaults to the .sln filename.

.PARAMETER Namespace
    Root C# namespace. Defaults to AppName.

.PARAMETER AppUrl
    Default base URL used in generated tests. Defaults to https://localhost:7052.

.PARAMETER ConnStrEnvVar
    Environment variable name for the integration test connection string.
    Defaults to <APPNAME_UPPERCASE>_TEST_CONNSTR.

.PARAMETER SkipWorkflows
    Skip creating .github/workflows files.
#>

param(
    [string]$AppName       = "",
    [string]$Namespace     = "",
    [string]$AppUrl        = "https://localhost:7052",
    [string]$ConnStrEnvVar = "",
    [switch]$SkipWorkflows,
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ─── Detect project ───────────────────────────────────────────────────────────

$root    = $PWD.Path
$slnFile = Get-ChildItem -Path $root -Filter "*.sln" -ErrorAction SilentlyContinue | Select-Object -First 1

if (-not $AppName) {
    if ($slnFile) {
        $AppName = [IO.Path]::GetFileNameWithoutExtension($slnFile.Name)
    } else {
        Write-Host ""
        Write-Host "No .sln file found. Enter the app name manually." -ForegroundColor Yellow
        $AppName = Read-Host "App name (e.g. DirectorFinancialDashboard)"
        if (-not $AppName) { Write-Error "App name is required."; exit 1 }
    }
}

if (-not $Namespace)     { $Namespace     = $AppName -replace '[^a-zA-Z0-9.]', '.' }
if (-not $ConnStrEnvVar) { $ConnStrEnvVar = ($AppName -replace '[^a-zA-Z0-9]', '_').ToUpper() + "_TEST_CONNSTR" }

Write-Host ""
Write-Host "ServiceNet QA Framework Installer" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  App:          $AppName"
Write-Host "  Namespace:    $Namespace"
Write-Host "  Test URL:     $AppUrl"
Write-Host "  Conn var:     $ConnStrEnvVar"
Write-Host "  Root:         $root"
Write-Host ""

if (-not $Force) {
    $confirm = Read-Host "Create test projects? [Y/n]"
    if ($confirm -and $confirm -match '^[Nn]') { Write-Host "Aborted."; exit 0 }
}

# ─── Helpers ──────────────────────────────────────────────────────────────────

$created = [System.Collections.Generic.List[string]]::new()
$skipped = [System.Collections.Generic.List[string]]::new()

function Write-File([string]$RelPath, [string]$Content) {
    $full = Join-Path $script:root $RelPath
    $dir  = Split-Path $full -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    if (Test-Path $full) { $script:skipped.Add($RelPath); return }
    [IO.File]::WriteAllText($full, $Content, [Text.Encoding]::UTF8)
    $script:created.Add($RelPath)
    Write-Host "  + $RelPath" -ForegroundColor Green
}

function Apply([string]$s) {
    return $s `
        -replace '\{\{AppName\}\}',       $AppName `
        -replace '\{\{Namespace\}\}',     $Namespace `
        -replace '\{\{AppUrl\}\}',        $AppUrl `
        -replace '\{\{ConnStrEnvVar\}\}', $ConnStrEnvVar
}

# ─── PROJECT 1: Unit tests ─────────────────────────────────────────────────────

Write-Host ""
Write-Host "Unit test project ($AppName.Tests) ..." -ForegroundColor Yellow

Write-File "tests/$AppName.Tests/$AppName.Tests.csproj" (Apply @'
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
    <IsPackable>false</IsPackable>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="Microsoft.NET.Test.Sdk"    Version="17.12.0" />
    <PackageReference Include="xunit"                     Version="2.9.3" />
    <PackageReference Include="xunit.runner.visualstudio" Version="2.8.2" />
    <PackageReference Include="Moq"                       Version="4.20.72" />
    <PackageReference Include="FluentAssertions"          Version="6.12.0" />
    <PackageReference Include="coverlet.collector"        Version="6.0.2" />
  </ItemGroup>
</Project>
'@)

Write-File "tests/$AppName.Tests/Infrastructure/TestCategories.cs" (Apply @'
namespace {{Namespace}}.Tests.Infrastructure;

public static class TestCategories
{
    public const string Smoke         = "Smoke";
    public const string Extended      = "Extended";
    public const string Integration   = "Integration";
    public const string Regression    = "Regression";
    public const string Unit          = "Unit";
    public const string Performance   = "Performance";
    public const string Accessibility = "Accessibility";
    public const string Security      = "Security";
    public const string DataQuality   = "DataQuality";
    public const string Api           = "API";
}
'@)

Write-File "tests/$AppName.Tests/Tests/SampleTests.cs" (Apply @'
using {{Namespace}}.Tests.Infrastructure;

namespace {{Namespace}}.Tests.Tests;

[Trait("Category", TestCategories.Unit)]
public sealed class SampleTests
{
    [Fact(DisplayName = "Starter unit test — replace with real logic tests")]
    public void Placeholder_Passes()
    {
        // Add tests for helper classes, formatters, and domain logic.
        Assert.True(true);
    }
}
'@)

# ─── PROJECT 2: Integration tests ─────────────────────────────────────────────

Write-Host ""
Write-Host "Integration test project ($AppName.Tests.Integration) ..." -ForegroundColor Yellow

Write-File "tests/$AppName.Tests.Integration/$AppName.Tests.Integration.csproj" (Apply @'
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
    <IsPackable>false</IsPackable>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="Microsoft.NET.Test.Sdk"    Version="17.12.0" />
    <PackageReference Include="xunit"                     Version="2.9.3" />
    <PackageReference Include="xunit.runner.visualstudio" Version="2.8.2" />
    <PackageReference Include="FluentAssertions"          Version="6.12.0" />
    <PackageReference Include="Dapper"                    Version="2.1.35" />
    <PackageReference Include="Microsoft.Data.SqlClient"  Version="5.2.2" />
    <PackageReference Include="coverlet.collector"        Version="6.0.2" />
  </ItemGroup>
  <ItemGroup>
    <Using Include="System.Data" />
    <Using Include="Microsoft.Data.SqlClient" />
    <Using Include="Dapper" />
  </ItemGroup>
</Project>
'@)

Write-File "tests/$AppName.Tests.Integration/TestConfig.cs" (Apply @'
namespace {{Namespace}}.Tests.Integration;

internal static class TestConfig
{
    // Set {{ConnStrEnvVar}} in your environment before running integration tests.
    // Windows auth fallback: omit the env var to use integrated security.
    public static string ConnectionString =>
        Environment.GetEnvironmentVariable("{{ConnStrEnvVar}}")
        ?? "Server=srv-sql-prod02;Database=careLogic_Import;Integrated Security=true;Encrypt=Optional;";
}
'@)

Write-File "tests/$AppName.Tests.Integration/StoredProcedureSchemaTests.cs" (Apply @'
using {{Namespace}}.Tests.Infrastructure;
using FluentAssertions;

namespace {{Namespace}}.Tests.Integration;

// Integration tests require SQL Server access.
// Run with: dotnet test --filter "Category=Integration"

[Trait("Category", TestCategories.Integration)]
public sealed class StoredProcedureSchemaTests
{
    private SqlConnection OpenConnection() => new(TestConfig.ConnectionString);

    // Add one [Fact] per stored procedure.
    // Assert on column presence and non-empty results only.
    // Never assert on specific data values — assert on shape only.
    //
    // Example:
    // [Fact(DisplayName = "GetMyProc returns rows with expected columns")]
    // public async Task GetMyProc_ReturnsExpectedColumns()
    // {
    //     using var conn = OpenConnection();
    //     var rows = (await conn.QueryAsync<dynamic>(
    //         new CommandDefinition("dbo.MyProc", new { Email = "admin@servicenet.org" },
    //             commandType: CommandType.StoredProcedure, commandTimeout: 60))).AsList();
    //     rows.Should().NotBeEmpty();
    //     var first = (IDictionary<string, object>)rows[0];
    //     first.Should().ContainKey("ColumnOne");
    // }
}
'@)

Write-File "tests/$AppName.Tests.Integration/DataQualityTests.cs" (Apply @'
using {{Namespace}}.Tests.Infrastructure;
using FluentAssertions;

namespace {{Namespace}}.Tests.Integration;

[Trait("Category", TestCategories.DataQuality)]
public sealed class DataQualityTests
{
    private SqlConnection OpenConnection() => new(TestConfig.ConnectionString);

    // Add data quality checks:
    //   - Snapshot tables refreshed within the last 25 hours
    //   - Required columns are non-null
    //   - Numeric totals in plausible ranges (e.g. percentages 0-100)
}
'@)

# ─── PROJECT 3: E2E tests ──────────────────────────────────────────────────────

Write-Host ""
Write-Host "E2E test project ($AppName.Tests.E2E) ..." -ForegroundColor Yellow

Write-File "tests/$AppName.Tests.E2E/$AppName.Tests.E2E.csproj" (Apply @'
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
    <IsPackable>false</IsPackable>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="Microsoft.NET.Test.Sdk"    Version="17.12.0" />
    <PackageReference Include="xunit"                     Version="2.9.3" />
    <PackageReference Include="xunit.runner.visualstudio" Version="2.8.2" />
    <PackageReference Include="FluentAssertions"          Version="6.12.0" />
    <PackageReference Include="Microsoft.Playwright"      Version="1.49.0" />
    <PackageReference Include="coverlet.collector"        Version="6.0.2" />
  </ItemGroup>
  <ItemGroup>
    <Using Include="Microsoft.Playwright" />
    <Using Include="Xunit" />
    <Using Include="FluentAssertions" />
  </ItemGroup>
</Project>
'@)

Write-File "tests/$AppName.Tests.E2E/TestConfig.cs" (Apply @'
namespace {{Namespace}}.Tests.E2E;

internal static class TestConfig
{
    public static string BaseUrl       => Environment.GetEnvironmentVariable("E2E_BASE_URL")  ?? "{{AppUrl}}";
    public static string AuthStatePath => Environment.GetEnvironmentVariable("E2E_AUTH_PATH") ?? "auth.json";
    public static bool   Headless      => Environment.GetEnvironmentVariable("E2E_HEADLESS")  != "false";
}
'@)

Write-File "tests/$AppName.Tests.E2E/Auth/AuthStateManager.cs" (Apply @'
namespace {{Namespace}}.Tests.E2E.Auth;

internal static class AuthStateManager
{
    public static void EnsureAuthFile()
    {
        if (!File.Exists(TestConfig.AuthStatePath))
            throw new InvalidOperationException(
                $"Azure AD auth state not found at '{TestConfig.AuthStatePath}'. " +
                "Run: node qa-save-auth.js --url <app-url> from the repo root.");
    }
}
'@)

Write-File "tests/$AppName.Tests.E2E/Infrastructure/E2ETestBase.cs" (Apply @'
using {{Namespace}}.Tests.E2E.Auth;

namespace {{Namespace}}.Tests.E2E.Infrastructure;

public abstract class E2ETestBase : IAsyncLifetime
{
    protected IPlaywright Playwright { get; private set; } = null!;
    protected IBrowser    Browser    { get; private set; } = null!;

    public async Task InitializeAsync()
    {
        AuthStateManager.EnsureAuthFile();
        Playwright = await Microsoft.Playwright.Playwright.CreateAsync();
        Browser    = await Playwright.Chromium.LaunchAsync(new BrowserTypeLaunchOptions
        {
            Headless = TestConfig.Headless,
        });
    }

    public async Task DisposeAsync()
    {
        await Browser.DisposeAsync();
        Playwright.Dispose();
    }

    protected async Task<(IBrowserContext Context, IPage Page)> NewPageAsync()
    {
        var context = await Browser.NewContextAsync(new BrowserNewContextOptions
        {
            StorageStatePath  = TestConfig.AuthStatePath,
            IgnoreHTTPSErrors = true,
        });
        var page = await context.NewPageAsync();
        return (context, page);
    }
}
'@)

Write-File "tests/$AppName.Tests.E2E/Infrastructure/BlazorPageBase.cs" (Apply @'
namespace {{Namespace}}.Tests.E2E.Infrastructure;

public abstract class BlazorPageBase(IPage page)
{
    protected IPage Page { get; } = page;

    protected async Task WaitForLoadAsync(int timeoutMs = 15000)
        => await Page.WaitForFunctionAsync(
               "() => !document.querySelector('.loading-state')", null,
               new PageWaitForFunctionOptions { Timeout = timeoutMs });

    protected async Task<string?> GetErrorStateTextAsync()
    {
        var el = await Page.QuerySelectorAsync(".empty-state");
        return el is null ? null : await el.InnerTextAsync();
    }

    protected async Task<Dictionary<string, string>> GetSummaryStatsAsync()
        => await Page.EvaluateAsync<Dictionary<string, string>>(@"() => {
            const r = {};
            document.querySelectorAll('.drilldown-summary > div').forEach(d => {
                const label = d.querySelector('span')?.innerText?.trim();
                const value = d.querySelector('strong')?.innerText?.trim();
                if (label) r[label] = value;
            });
            return r;
        }");

    protected async Task<List<string[]>> GetTableRowsAsync(string selector = "tbody tr")
        => await Page.EvaluateAsync<List<string[]>>($@"() =>
            Array.from(document.querySelectorAll('{selector}')).map(r =>
                Array.from(r.querySelectorAll('td')).map(td => td.innerText.trim()))");

    protected bool IsAuthenticated()
        => !Page.Url.Contains("microsoftonline") && !Page.Url.Contains("login.microsoft");
}
'@)

Write-File "tests/$AppName.Tests.E2E/Smoke/AppHealthSmokeTests.cs" (Apply @'
using {{Namespace}}.Tests.E2E.Infrastructure;
using {{Namespace}}.Tests.Infrastructure;

namespace {{Namespace}}.Tests.E2E.Smoke;

[Trait("Category", TestCategories.Smoke)]
[Trait("Category", TestCategories.Regression)]
public sealed class AppHealthSmokeTests : E2ETestBase
{
    [Fact(DisplayName = "App responds to homepage request")]
    public async Task App_Responds_To_Root()
    {
        var (ctx, page) = await NewPageAsync();
        var response = await page.GotoAsync(TestConfig.BaseUrl,
            new PageGotoOptions { WaitUntil = WaitUntilState.DOMContentLoaded, Timeout = 20000 });
        response.Should().NotBeNull();
        ((int)response!.Status).Should().Be(200);
        await ctx.DisposeAsync();
    }

    [Fact(DisplayName = "Session is authenticated (not redirected to Azure AD)")]
    public async Task Session_Is_Authenticated()
    {
        var (ctx, page) = await NewPageAsync();
        await page.GotoAsync(TestConfig.BaseUrl,
            new PageGotoOptions { WaitUntil = WaitUntilState.DOMContentLoaded });
        page.Url.Should().NotContain("microsoftonline");
        await ctx.DisposeAsync();
    }

    // Add key page routes:
    // [Theory(DisplayName = "Key pages load without error state")]
    // [InlineData("/")]
    // [InlineData("/my-feature")]
    // public async Task Key_Pages_Load(string route)
    // {
    //     var (ctx, page) = await NewPageAsync();
    //     await page.GotoAsync(TestConfig.BaseUrl + route,
    //         new PageGotoOptions { WaitUntil = WaitUntilState.DOMContentLoaded });
    //     var err = await page.QuerySelectorAsync(".empty-state");
    //     err.Should().BeNull($"page {route} should load without error");
    //     await ctx.DisposeAsync();
    // }
}
'@)

Write-File "tests/$AppName.Tests.E2E/Features/SampleFeature/SampleFeatureTests.cs" (Apply @'
using {{Namespace}}.Tests.E2E.Infrastructure;
using {{Namespace}}.Tests.Infrastructure;

namespace {{Namespace}}.Tests.E2E.Features.SampleFeature;

[Trait("Category", TestCategories.Extended)]
[Trait("Category", TestCategories.Regression)]
[Trait("Feature", "SampleFeature")]
public sealed class SampleFeatureTests : E2ETestBase
{
    [Fact(DisplayName = "Sample — replace with real feature tests")]
    public async Task Sample_Placeholder()
    {
        var (ctx, page) = await NewPageAsync();
        // Navigate, interact, assert.
        await ctx.DisposeAsync();
    }
}
'@)

Write-File "tests/$AppName.Tests.E2E/Performance/PageLoadPerformanceTests.cs" (Apply @'
using {{Namespace}}.Tests.E2E.Infrastructure;
using {{Namespace}}.Tests.Infrastructure;

namespace {{Namespace}}.Tests.E2E.Performance;

[Trait("Category", TestCategories.Performance)]
public sealed class PageLoadPerformanceTests : E2ETestBase
{
    private const int SimplePageMs = 3000;
    private const int DataPageMs   = 8000;

    // [Theory(DisplayName = "Pages load within threshold")]
    // [InlineData("/", SimplePageMs)]
    // [InlineData("/my-data-page", DataPageMs)]
    // public async Task Page_Loads_Within_Threshold(string route, int thresholdMs)
    // {
    //     var (ctx, page) = await NewPageAsync();
    //     var sw = System.Diagnostics.Stopwatch.StartNew();
    //     await page.GotoAsync(TestConfig.BaseUrl + route,
    //         new PageGotoOptions { WaitUntil = WaitUntilState.DOMContentLoaded });
    //     sw.Stop();
    //     sw.ElapsedMilliseconds.Should().BeLessThan(thresholdMs);
    //     await ctx.DisposeAsync();
    // }
}
'@)

Write-File "tests/$AppName.Tests.E2E/Accessibility/AccessibilityTests.cs" (Apply @'
using {{Namespace}}.Tests.E2E.Infrastructure;
using {{Namespace}}.Tests.Infrastructure;

namespace {{Namespace}}.Tests.E2E.Accessibility;

// Uses axe-core (CDN injection) for WCAG 2.1 AA compliance checks.

[Trait("Category", TestCategories.Accessibility)]
[Trait("Category", TestCategories.Regression)]
public sealed class AccessibilityTests : E2ETestBase
{
    private const string AxeCdn = "https://cdnjs.cloudflare.com/ajax/libs/axe-core/4.9.1/axe.min.js";

    // [Theory(DisplayName = "Page has no critical or serious WCAG 2.1 AA violations")]
    // [InlineData("/")]
    // public async Task Page_Has_No_Critical_Violations(string route)
    // {
    //     var (ctx, page) = await NewPageAsync();
    //     await page.GotoAsync(TestConfig.BaseUrl + route,
    //         new PageGotoOptions { WaitUntil = WaitUntilState.NetworkIdle });
    //     await page.AddScriptTagAsync(new PageAddScriptTagOptions { Url = AxeCdn });
    //     var violations = await page.EvaluateAsync<List<AxeViolation>>(@"
    //         async () => {
    //             const r = await axe.run({ runOnly: ['wcag2a','wcag2aa'] });
    //             return r.violations
    //                 .filter(v => v.impact === 'critical' || v.impact === 'serious')
    //                 .map(v => ({ id: v.id, impact: v.impact, description: v.description }));
    //         }");
    //     violations.Should().BeEmpty($"page {route} should have no critical/serious WCAG violations");
    //     await ctx.DisposeAsync();
    // }

    private record AxeViolation(string Id, string Impact, string Description);
}
'@)

Write-File "tests/$AppName.Tests.E2E/Security/SecurityTests.cs" (Apply @'
using {{Namespace}}.Tests.E2E.Infrastructure;
using {{Namespace}}.Tests.Infrastructure;

namespace {{Namespace}}.Tests.E2E.Security;

[Trait("Category", TestCategories.Security)]
[Trait("Category", TestCategories.Regression)]
public sealed class SecurityTests : E2ETestBase
{
    [Fact(DisplayName = "Unauthenticated request redirects to Azure AD login")]
    public async Task Unauthenticated_Redirects_To_AzureAD()
    {
        var context = await Browser.NewContextAsync(new BrowserNewContextOptions
        {
            IgnoreHTTPSErrors = true,
        });
        var page = await context.NewPageAsync();
        await page.GotoAsync(TestConfig.BaseUrl,
            new PageGotoOptions { WaitUntil = WaitUntilState.DOMContentLoaded });
        page.Url.Should().ContainAny(
            new[] { "microsoftonline.com", "login.microsoft.com" },
            "unauthenticated requests should redirect to Azure AD");
        await context.DisposeAsync();
    }

    [Fact(DisplayName = "Authenticated pages do not expose secrets in page source")]
    public async Task Pages_Do_Not_Expose_Secrets()
    {
        var (ctx, page) = await NewPageAsync();
        await page.GotoAsync(TestConfig.BaseUrl,
            new PageGotoOptions { WaitUntil = WaitUntilState.DOMContentLoaded });
        var content = await page.ContentAsync();
        content.Should().NotContain("password");
        content.Should().NotContain("connectionString");
        content.Should().NotContain("ClientSecret");
        await ctx.DisposeAsync();
    }
}
'@)

# ─── Tools: Generate-QualityReport.ps1 ────────────────────────────────────────

Write-Host ""
Write-Host "Quality report tool ..." -ForegroundColor Yellow

$reportDest    = Join-Path $root "tools\Generate-QualityReport.ps1"
$reportDestDir = Split-Path $reportDest -Parent

if (Test-Path $reportDest) {
    $skipped.Add("tools/Generate-QualityReport.ps1")
} else {
    if (-not (Test-Path $reportDestDir)) {
        New-Item -ItemType Directory -Force -Path $reportDestDir | Out-Null
    }

    $obtained = $false

    # 1. Copy from local ai-agent-config clone
    $candidates = @()
    if ($env:CODE_DIR) {
        $candidates += Join-Path $env:CODE_DIR "ai-agent-config\qa-template\Generate-QualityReport.ps1"
    }
    if ($PSCommandPath) {
        $candidates += Join-Path (Split-Path -Parent $PSCommandPath) "Generate-QualityReport.ps1"
    }

    foreach ($c in $candidates) {
        if (Test-Path $c) {
            Copy-Item $c $reportDest
            $created.Add("tools/Generate-QualityReport.ps1")
            Write-Host "  + tools/Generate-QualityReport.ps1" -ForegroundColor Green
            $obtained = $true
            break
        }
    }

    # 2. Download from GitHub as fallback
    if (-not $obtained) {
        try {
            $dlUrl = "https://raw.githubusercontent.com/lopatkm/servicenet-qa-framework/main/Generate-QualityReport.ps1"
            Invoke-WebRequest -Uri $dlUrl -OutFile $reportDest -UseBasicParsing -ErrorAction Stop
            $created.Add("tools/Generate-QualityReport.ps1")
            Write-Host "  + tools/Generate-QualityReport.ps1 (downloaded)" -ForegroundColor Green
        } catch {
            Write-Host "  ! Could not get Generate-QualityReport.ps1: $($_.Exception.Message)" -ForegroundColor Yellow
            Write-Host "    Copy manually: ai-agent-config/qa-template/Generate-QualityReport.ps1 -> tools/" -ForegroundColor Yellow
        }
    }
}

# ─── Auth capture helper ───────────────────────────────────────────────────────

Write-Host ""
Write-Host "Auth capture helper (qa-save-auth.js) ..." -ForegroundColor Yellow

$saveAuthPath = Join-Path $root "qa-save-auth.js"
if (-not (Test-Path $saveAuthPath)) {
    [IO.File]::WriteAllText($saveAuthPath, @'
/**
 * qa-save-auth.js - Captures Azure AD session state for Playwright E2E tests.
 *
 * Usage:
 *   node qa-save-auth.js --url https://localhost:7052
 *   node qa-save-auth.js --url https://yourtestapp.servicenet.org
 *
 * Opens a browser window. Sign in, then close the tab.
 * Saves the session to auth.json. Re-run when expired (typically 24h-90d).
 * auth.json is gitignored - never commit it.
 */

const { chromium } = require('playwright');

const args   = process.argv.slice(2);
const getArg = key => { const i = args.indexOf(key); return i !== -1 ? args[i + 1] : null; };
const url    = getArg('--url') || 'https://localhost:7052';
const out    = getArg('--out') || 'auth.json';

(async () => {
    console.log(`Opening browser - sign in at ${url}`);
    console.log('Close the browser tab when the dashboard is visible.\n');

    const browser = await chromium.launch({ headless: false, ignoreHTTPSErrors: true });
    const context = await browser.newContext({ ignoreHTTPSErrors: true });
    const page    = await context.newPage();

    await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 120000 });
    await page.waitForURL(
        u => !u.includes('microsoftonline') && !u.includes('login.microsoft'),
        { timeout: 120000 }
    );

    await context.storageState({ path: out });
    console.log(`\nSession saved to ${out}`);
    console.log('Run E2E tests: dotnet test --filter "Category=Smoke"');

    await browser.close();
})().catch(err => { console.error(err.message); process.exit(1); });
'@, [Text.Encoding]::UTF8)
    $created.Add("qa-save-auth.js")
    Write-Host "  + qa-save-auth.js" -ForegroundColor Green
} else {
    $skipped.Add("qa-save-auth.js")
}

# ─── GitHub Actions workflows ──────────────────────────────────────────────────

if (-not $SkipWorkflows) {
    Write-Host ""
    Write-Host "GitHub Actions workflows ..." -ForegroundColor Yellow

    Write-File ".github/workflows/qa-smoke.yml" (Apply @'
name: QA Smoke Tests

on:
  workflow_run:
    workflows: ["Deploy to Test"]
    types: [completed]
  workflow_dispatch:

jobs:
  smoke:
    if: ${{ github.event.workflow_run.conclusion == 'success' || github.event_name == 'workflow_dispatch' }}
    runs-on: [self-hosted, test-runner]
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-dotnet@v4
        with:
          dotnet-version: '10.0.x'
      - name: Build
        run: dotnet build --configuration Release
      - name: Install Playwright browsers
        run: pwsh tests/{{AppName}}.Tests.E2E/bin/Release/net10.0/playwright.ps1 install chromium
      - name: Run smoke tests
        env:
          E2E_BASE_URL: {{AppUrl}}
          E2E_AUTH_PATH: ${{ secrets.E2E_AUTH_JSON_PATH }}
          E2E_HEADLESS: "true"
        run: dotnet test --filter "Category=Smoke" --logger "trx;LogFileName=smoke-results.trx"
      - name: Publish test results
        uses: dorny/test-reporter@v1
        if: always()
        with:
          name: Smoke Test Results
          path: "**/*.trx"
          reporter: dotnet-trx
'@)

    Write-File ".github/workflows/qa-regression.yml" (Apply @'
name: QA Regression Tests (Nightly)

on:
  schedule:
    - cron: '0 6 * * *'
  workflow_dispatch:

jobs:
  regression:
    runs-on: [self-hosted, test-runner]
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-dotnet@v4
        with:
          dotnet-version: '10.0.x'
      - name: Restore and build
        run: dotnet build --configuration Release
      - name: Install Playwright browsers
        run: pwsh tests/{{AppName}}.Tests.E2E/bin/Release/net10.0/playwright.ps1 install chromium
      - name: Run regression suite
        env:
          E2E_BASE_URL: {{AppUrl}}
          E2E_AUTH_PATH: ${{ secrets.E2E_AUTH_JSON_PATH }}
          E2E_HEADLESS: "true"
          {{ConnStrEnvVar}}: ${{ secrets.INTEGRATION_TEST_CONNSTR }}
        run: dotnet test --filter "Category=Regression" --configuration Release --logger "trx;LogFileName=regression-results.trx"
      - name: Publish test results
        uses: dorny/test-reporter@v1
        if: always()
        with:
          name: Regression Test Results
          path: "**/*.trx"
          reporter: dotnet-trx
      - name: Upload artifacts on failure
        uses: actions/upload-artifact@v4
        if: failure()
        with:
          name: regression-failure-artifacts
          path: |
            **/*.trx
            **/*.png
          retention-days: 7
'@)
}

# ─── .gitignore entries ────────────────────────────────────────────────────────

$gitignorePath = Join-Path $root ".gitignore"
if (Test-Path $gitignorePath) {
    $gi      = Get-Content $gitignorePath -Raw
    $entries = @("auth.json", "test-report.html", "**/TestResults/")
    $toAdd   = $entries | Where-Object { $gi -notmatch [regex]::Escape($_) }
    if ($toAdd) {
        Add-Content -Path $gitignorePath -Value ("`n# ServiceNet QA Framework`n" + ($toAdd -join "`n"))
        Write-Host ""
        Write-Host "  Updated .gitignore (+$($toAdd.Count) entries)" -ForegroundColor Green
    }
}

# ─── Summary ──────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Done: $($created.Count) files created, $($skipped.Count) already existed." -ForegroundColor Cyan
Write-Host ""

if ($created.Count -gt 0) {
    Write-Host "Next steps:" -ForegroundColor White
    Write-Host ""
    Write-Host "  1. Add test projects to your solution:" -ForegroundColor Yellow
    Write-Host "     dotnet sln add tests/$AppName.Tests/$AppName.Tests.csproj"
    Write-Host "     dotnet sln add tests/$AppName.Tests.Integration/$AppName.Tests.Integration.csproj"
    Write-Host "     dotnet sln add tests/$AppName.Tests.E2E/$AppName.Tests.E2E.csproj"
    Write-Host ""
    Write-Host "  2. Build:" -ForegroundColor Yellow
    Write-Host "     dotnet build"
    Write-Host ""
    Write-Host "  3. Install Playwright browsers:" -ForegroundColor Yellow
    Write-Host "     pwsh tests/$AppName.Tests.E2E/bin/Debug/net10.0/playwright.ps1 install chromium"
    Write-Host ""
    Write-Host "  4. Run unit tests:" -ForegroundColor Yellow
    Write-Host "     dotnet test --filter `"Category=Unit`""
    Write-Host ""
    Write-Host "  5. Set integration test connection string and run:" -ForegroundColor Yellow
    Write-Host "     `$env:$ConnStrEnvVar = `"Server=...;Integrated Security=true;Encrypt=Optional;`""
    Write-Host "     dotnet test --filter `"Category=Integration`""
    Write-Host ""
    Write-Host "  6. Capture Azure AD session and run E2E smoke tests:" -ForegroundColor Yellow
    Write-Host "     node qa-save-auth.js --url $AppUrl"
    Write-Host "     dotnet test --filter `"Category=Smoke`""
    Write-Host ""
    Write-Host "  7. Generate the HTML quality report:" -ForegroundColor Yellow
    Write-Host "     dotnet test --logger `"trx;LogFileName=results.trx`""
    Write-Host "     .\tools\Generate-QualityReport.ps1 -Open"
    Write-Host ""
    Write-Host "  Docs:  ai-agent-config/qa-template/README.md" -ForegroundColor DarkGray
    Write-Host "  Skill: /setup-testing in Claude Code adds tests for specific pages" -ForegroundColor DarkGray
}

Write-Host ""
