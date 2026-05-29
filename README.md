# ServiceNet QA Automation

A test scaffolding and automation tool for ServiceNet Blazor Server applications. Gives every IS project a consistent set of unit and integration tests, a one-command developer test runner, and a GitHub Actions regression suite.

---

## Overview

ServiceNet IS developers use this framework to catch bugs before they reach production. The developer-facing workflow is a single script — `Run-Tests.ps1` — that runs unit and integration tests with no browser, no auth, and no manual steps. GitHub Actions handles the rest automatically after each deploy.

This framework provides:

1. **A simple developer QA command.** `.\Run-Tests.ps1` runs unit and integration tests. No setup beyond a connection string. Safe to run at any time, including while the dev server is running.

2. **Consistent test structure across every app.** Same categories, same project layout, same CI triggers. Any IS developer can pick up any project and run its tests without learning a new system.

3. **Automated CI coverage.** Smoke tests trigger after every deploy to test. A full regression suite runs nightly. Neither requires developer action.

**Target audience:** ServiceNet IS developers.

---

## Quick Start

### Step 1: Scaffold the test projects (one-time per project)

From the project root in PowerShell:

```powershell
& ([scriptblock]::Create([Text.Encoding]::UTF8.GetString([Convert]::FromBase64String(((irm https://api.github.com/repos/lopatkm/qa-automation/contents/install.ps1).content -replace '\n',''))))) -Force
```

Scaffolds Unit, Integration, and E2E test projects plus `Run-Tests.ps1`. Existing files are never overwritten — safe to re-run.

### Step 2: Run tests

```powershell
.\Run-Tests.ps1
```

Unit tests run immediately. Integration tests run automatically if the connection string env var is set.

### Option: Claude Code skill

Open the project in Claude Code and run `/setup-testing` to scaffold and write starter tests tailored to the app's pages and stored procedures.

To apply to a new ServiceNet project from scratch, see [Applying to a New Project](#applying-to-a-new-servicenet-project).

---

## Test Categories

All tests use `[Trait("Category", TestCategories.X)]` from `TestCategories.cs`. Tests can carry multiple category traits (e.g., Smoke + Regression).

| Category      | Description                                                            | When to Run                        | Filter Command                               |
|---------------|------------------------------------------------------------------------|------------------------------------|----------------------------------------------|
| `Unit`        | Pure logic — no I/O, no database, no browser. Always fast.             | Every build, every PR              | `dotnet test --filter "Category=Unit"`       |
| `Integration` | Live SQL Server — stored proc schemas, security scoping, data shape.   | PR CI with DB access, nightly      | `dotnet test --filter "Category=Integration"`|
| `Smoke`       | App alive, auth works, key pages load. Must finish under 2 minutes.    | After every deploy to test env     | `dotnet test --filter "Category=Smoke"`      |
| `Extended`    | Full feature coverage — all flows, filters, drilldowns, edge cases.    | Before releases, feature branches  | `dotnet test --filter "Category=Extended"`   |
| `Regression`  | Full nightly suite. Combines Smoke + Extended + Integration.           | Nightly scheduled run              | `dotnet test --filter "Category=Regression"` |
| `Performance` | Page load times and SQL query benchmarks against defined thresholds.   | Weekly or on performance changes   | `dotnet test --filter "Category=Performance"`|
| `Accessibility`| WCAG 2.1 AA compliance via axe-core. Staff-facing tools must pass.   | Before releases, nightly           | `dotnet test --filter "Category=Accessibility"`|
| `Security`    | Auth enforcement, security response headers, no secrets in HTML.       | Before releases, nightly           | `dotnet test --filter "Category=Security"`   |
| `DataQuality` | Snapshot tables refreshed on schedule, required fields non-null.       | Nightly, after ETL jobs            | `dotnet test --filter "Category=DataQuality"`|
| `API`         | HTTP status codes, response shape, auth enforcement on API endpoints.  | PR CI, nightly (API apps only)     | `dotnet test --filter "Category=API"`        |

---

## Running Tests

### Developer workflow (no auth required)

```powershell
.\Run-Tests.ps1
```

Runs Unit and Integration tests. Set the connection string env var to include integration tests:

```powershell
$env:YOURAPP_TEST_CONNSTR = "Server=...;Database=...;Integrated Security=true;Encrypt=Optional;"
```

### Specific test categories

```powershell
# Unit only
dotnet test -c Release --filter "Category=Unit"

# Integration + Data Quality
dotnet test -c Release --filter "Category=Integration|Category=DataQuality"

# Accessibility + Security
dotnet test -c Release --filter "Category=Accessibility|Category=Security"

# Full nightly suite
dotnet test -c Release --filter "Category=Regression"

# Verbose output for debugging
dotnet test -c Release --filter "Category=Unit" --logger "console;verbosity=detailed"
```

---

## Quality Report

> Note: `Generate-QualityReport.ps1` is scaffolded into `tools/` by the installer.

```powershell
# Generate report
.\tools\Generate-QualityReport.ps1

# Generate and open immediately
.\tools\Generate-QualityReport.ps1 -Open
```

Scans `.trx` result files and produces a self-contained `test-report.html` summarizing pass/fail by category. Safe to email to IS leadership — contains no PHI/PII.

`test-report.html` is in `.gitignore` and should never be committed.

---

## GitHub Actions Integration

### Smoke tests — after every deploy to test

```yaml
# .github/workflows/qa-smoke.yml
on:
  workflow_run:
    workflows: ["Deploy to Test"]
    types: [completed]
```

Triggers automatically when the deploy workflow completes. Runs `dotnet test --filter "Category=Smoke"`.

### Regression suite — nightly

```yaml
# .github/workflows/qa-regression.yml
on:
  schedule:
    - cron: '0 6 * * *'   # 6:00 AM UTC — 2:00 AM ET
```

Runs `dotnet test --filter "Category=Regression"` nightly. On failure, uploads `.trx` files as artifacts (retained 7 days).

### Unit + Integration — on every PR

```yaml
- name: Run unit and integration tests
  run: dotnet test -c Release --filter "Category=Unit|Category=Integration"
  env:
    YOURAPP_TEST_CONNSTR: ${{ secrets.INTEGRATION_TEST_CONNSTR }}
```

Replace `YOURAPP_TEST_CONNSTR` with the env var name the installer generated for your app.

### Self-hosted runner requirement

All QA workflows use `runs-on: [self-hosted, test-runner]`. The runner must be:
- Domain-joined (for Windows auth to SQL Server)
- Have .NET 10 SDK installed
- Have `INTEGRATION_TEST_CONNSTR` secret configured in the GitHub repo

---

## Writing New Tests

### Adding a test for a new page

**Step 1: Create a page object**

Create `tests/YourApp.Tests.E2E/PageObjects/MyNewPage.cs`:

```csharp
using YourApp.Tests.E2E.Infrastructure;

namespace YourApp.Tests.E2E.PageObjects;

public sealed class MyNewPage(IPage page) : BlazorPageBase(page)
{
    public static string Url => "/my-new-page";

    public async Task NavigateAsync()
        => await Page.GotoAsync($"{TestConfig.BaseUrl}{Url}",
               new PageGotoOptions { WaitUntil = WaitUntilState.DOMContentLoaded });

    public async Task<string> GetPageTitleAsync()
        => await Page.EvalOnSelectorAsync<string>("h2", "el => el.innerText");
}
```

**Step 2: Add a feature test**

Create `tests/YourApp.Tests.E2E/Features/MyNewFeature/MyNewFeatureTests.cs`:

```csharp
using YourApp.Tests.E2E.Infrastructure;
using YourApp.Tests.E2E.PageObjects;

namespace YourApp.Tests.E2E.Features.MyNewFeature;

[Trait("Category", "Extended")]
[Trait("Category", "Regression")]
[Trait("Feature", "MyNewFeature")]
public sealed class MyNewFeatureTests : E2ETestBase
{
    [Fact(DisplayName = "Page loads with data and no error state")]
    public async Task Page_Loads_With_Data()
    {
        var (ctx, page) = await NewPageAsync();
        var po = new MyNewPage(page);

        await po.NavigateAsync();
        await po.WaitForLoadAsync();

        var err = await po.GetErrorStateTextAsync();
        err.Should().BeNull("page should load without error");

        await ctx.DisposeAsync();
    }
}
```

**Step 3: Add a smoke test entry**

In `Smoke/AppHealthSmokeTests.cs`, add the new route to the `Key_Pages_Resolve` theory data:

```csharp
[InlineData("/my-new-page")]
```

### Adding a stored proc schema test

In `tests/YourApp.Tests.Integration/StoredProcedureSchemaTests.cs`:

```csharp
[Fact(DisplayName = "MyNewProc returns rows with expected columns")]
public async Task MyNewProc_ReturnsExpectedColumns()
{
    using var conn = OpenConnection();

    var rows = (await conn.QueryAsync<dynamic>(
        new CommandDefinition(
            "dbo.MyApp_GetMyNewProc",
            new { Email = "admin@servicenet.org", HasGlobalAccess = 1 },
            commandType: CommandType.StoredProcedure,
            commandTimeout: 60))).AsList();

    rows.Should().NotBeEmpty("MyNewProc should return at least one row");

    var first = (IDictionary<string, object>)rows[0];
    first.Should().ContainKey("ExpectedColumn1");
    first.Should().ContainKey("ExpectedColumn2");
}
```

Never use `SELECT *` and never assert on specific data values. Only assert on column presence and non-empty results.

---

## Project Structure

```
qa-automation/
  Infrastructure/
    ServiceNetTestBase.cs      Base class: Playwright browser lifecycle, auth context creation
    BlazorPageBase.cs          Base class: Blazor-specific helpers (WaitForLoad, GetErrorState,
                               GetSummaryStats, GetTableRows, IsAuthenticated)
  TestCategories.cs            Shared category constants
  workflows/
    qa-smoke.yml               GitHub Actions: smoke tests triggered after every test deploy
    qa-regression.yml          GitHub Actions: nightly full regression suite
  install.ps1                  One-command installer
  Generate-QualityReport.ps1   HTML quality report generator
  README.md                    This file

tests/
  YourApp.Tests/
    Infrastructure/
      TestCategories.cs        Copy of template, namespace updated to match app
    Tests/
      *Tests.cs                Unit tests — pure logic, no I/O
    YourApp.Tests.csproj

  YourApp.Tests.Integration/
    TestConfig.cs              Connection string from env var, Windows auth fallback
    StoredProcedureSchemaTests.cs  One test per stored proc — schema and non-empty results
    DataQualityTests.cs        Snapshot freshness checks, null-field checks
    SecurityScopeIntegrationTests.cs  (if app has security scoping) Full pipeline tests
    YourApp.Tests.Integration.csproj

  YourApp.Tests.E2E/
    Infrastructure/
      E2ETestBase.cs           Browser lifecycle
      BlazorPageBase.cs        Blazor helpers
      TestCategories.cs        Category constants, E2E namespace
    PageObjects/
      *Page.cs                 One class per Blazor page — navigation + typed selectors
    Smoke/
      AppHealthSmokeTests.cs   One test per route — HTTP status, no Blazor error boundary
    Features/
      */
        *Tests.cs              Extended feature tests — filters, drilldowns, interactions
    Performance/
      PageLoadPerformanceTests.cs  Load time assertions by page type
    Accessibility/
      AccessibilityTests.cs    axe-core WCAG 2.1 AA violations (critical + serious)
    Security/
      SecurityTests.cs         Unauthenticated redirect, security headers, no secrets in HTML
    TestConfig.cs              E2E_BASE_URL, E2E_AUTH_PATH, E2E_HEADLESS from env vars
    YourApp.Tests.E2E.csproj
```

---

## Applying to a New ServiceNet Project

Follow this checklist when standing up QA for a new app:

- [ ] Run the one-command installer from the project root (see Quick Start)
- [ ] Run the three `dotnet sln add` commands the installer prints
- [ ] Build the solution: `dotnet build`
- [ ] Set the connection string env var the installer generated for your app
- [ ] Run `.\Run-Tests.ps1` to confirm unit and integration tests pass
- [ ] Commit the test projects and `Run-Tests.ps1`
- [ ] Copy `qa-smoke.yml` and `qa-regression.yml` from `qa-automation/workflows/` into `.github/workflows/`
- [ ] Add the `INTEGRATION_TEST_CONNSTR` secret to the GitHub repo
- [ ] Verify the smoke workflow triggers after the next test deploy

---

## PHI/PII Safety Rules

ServiceNet apps are HIPAA-covered. These rules apply to all test code:

**Never put real client or staff data in tests.** This includes:
- Real client names, IDs, dates of birth, addresses, or diagnoses
- Real staff names or email addresses (use `admin@servicenet.org` only for admin-access assertions against the test environment)
- Actual financial figures from production records
- Real program IDs that could be linked to an individual

**What is safe to use:**
- Aggregate counts and totals returned by authenticated API calls (asserting shape, not values)
- System-generated IDs that have no standalone meaning
- Column names and schema structure
- Synthetic placeholder data: `Jane Doe`, `PRG001`, `1970-01-01`

**What integration tests may assert:**
- Column presence and row count > 0
- Numeric values are within a plausible range (e.g., a percentage is 0-100)
- Required columns are non-null
- Snapshot tables have a refresh timestamp within 25 hours

**What integration tests must not assert:**
- Specific dollar amounts from production data
- Specific staff names or client counts that change over time
- Any value that could be used to infer individual-level PHI

If a stored proc test returns a result set and you are uncertain whether any column contains PHI, stop and consult the Compliance team before asserting on values.
