# ServiceNet QA Framework

A three-tier automated test suite for ServiceNet Blazor Server applications. Provides consistent test structure, shared infrastructure, and management-readable reporting across every IS project.

---

## Overview

ServiceNet IS maintains a growing portfolio of internal Blazor Server dashboards. Each app handles sensitive operational data — financial metrics, claims, documentation compliance, workforce analytics — adjacent to protected health information. That combination demands enterprise-grade quality assurance that goes beyond "does it deploy."

This framework solves three problems:

1. **Consistency.** Every ServiceNet app gets the same test categories, the same CI triggers, and the same report format. A new developer or director can read any project's QA output without learning a new system.

2. **Right coverage at the right time.** Smoke tests run in under 2 minutes after every deploy. Full regression runs overnight. Integration tests run whenever the database is reachable. You never block a deploy waiting for slow tests, and you never skip the thorough checks.

3. **Management-readable output.** The HTML quality report summarizes pass/fail by category in plain language suitable for IS leadership review.

**Target audience:** ServiceNet IS developers. The `/setup-testing` skill in Claude Code is the single entry point — it scaffolds everything automatically from this template.

---

## Quick Start (5 minutes)

### Option 1: One-command installer (from any project root)

```powershell
& ([scriptblock]::Create([Text.Encoding]::UTF8.GetString([Convert]::FromBase64String(((irm https://api.github.com/repos/lopatkm/servicenet-qa-framework/contents/install.ps1).content -replace '\n',''))))) -Force
```

This scaffolds all three test projects (Unit, Integration, E2E), GitHub Actions workflows, and tooling. Existing files are never overwritten — safe to re-run.

### Option 2: Claude Code skill

Open the target project in Claude Code and run:

```
/setup-testing
```

The skill reads `CLAUDE.md`, discovers Blazor pages and stored procedures, presents a plan for your approval, then creates all three test projects, wires GitHub Actions, and writes starter tests.

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
| `Accessibility`| WCAG 2.1 AA compliance via axe-core. Staff-facing tools must pass.    | Before releases, nightly           | `dotnet test --filter "Category=Accessibility"`|
| `Security`    | Auth enforcement, security response headers, no secrets in HTML.       | Before releases, nightly           | `dotnet test --filter "Category=Security"`   |
| `DataQuality` | Snapshot tables refreshed on schedule, required fields non-null.       | Nightly, after ETL jobs            | `dotnet test --filter "Category=DataQuality"`|
| `API`         | HTTP status codes, response shape, auth enforcement on API endpoints.  | PR CI, nightly (API apps only)     | `dotnet test --filter "Category=API"`        |

---

## Auth Capture

E2E tests run against an Azure AD-protected app. Playwright needs a valid browser session to access any page. Auth capture is a one-time setup per machine (and per CI runner).

### One-time setup

From the repo root:

```bash
node qa-save-auth.js --url https://testdirectordashboard.servicenet.org
```

A browser window opens. Sign in with your ServiceNet credentials. The script writes `auth.json` to the repo root and closes. All subsequent E2E test runs load this file automatically.

For a different app URL:

```bash
node qa-save-auth.js --url https://yourtestapp.servicenet.org
```

### How long sessions last

Azure AD sessions expire based on tenant policy — typically 24 hours for interactive sessions, up to 90 days with persistent refresh tokens. If E2E tests start failing with unexpected redirects to `microsoftonline.com`, re-run `qa-save-auth.js`.

### How to refresh

Delete `auth.json` and run `qa-save-auth.js` again. The old file is immediately invalidated on next test run if the session has expired.

### CI runners

CI agents use a pre-captured `auth.json` stored as a GitHub Actions secret (`E2E_AUTH_JSON_PATH`). The path secret points to a file on the self-hosted runner. Refresh this file on the runner when the session expires.

> `auth.json` is in `.gitignore` and must never be committed. It contains live session tokens equivalent to a logged-in browser session.

---

## Running Tests

Pick the scenario that matches what you need to verify:

### Is the deploy working?

```bash
dotnet test --filter "Category=Smoke"
```

Runs in under 2 minutes. Covers: app responds, session authenticated, key pages load without error.

### Is my feature complete?

```bash
dotnet test --filter "Category=Extended"
```

Covers all user-facing flows for the feature areas that have Extended tests: filters, drilldowns, edge cases, navigation.

### Is the database healthy?

```bash
dotnet test --filter "Category=Integration|Category=DataQuality"
```

Covers: stored proc schemas return expected columns, snapshot tables are fresh, required fields are non-null.

### Are we compliant?

```bash
dotnet test --filter "Category=Accessibility|Category=Security"
```

Covers: WCAG 2.1 AA violations (critical and serious), auth enforcement, security headers, no secrets in HTML.

### Nightly full check?

```bash
dotnet test --filter "Category=Regression"
```

Runs everything tagged Regression. This is what GitHub Actions runs nightly. Includes Smoke + Extended + Integration + Accessibility + Security + DataQuality + Performance.

### Unit tests only (no I/O, fast feedback loop)?

```bash
dotnet test --filter "Category=Unit"
```

### Watch for changes during development?

```bash
dotnet watch test --project tests/YourApp.Tests --filter "Category=Unit"
```

### Verbose output for debugging a failure?

```bash
dotnet test --filter "Category=Smoke" --logger "console;verbosity=detailed"
```

---

## Quality Report

> Note: `Generate-QualityReport.ps1` is a project-level tool. Not all projects have it yet — check `tools/` in your project. If it's absent, use the GitHub Actions test reporter directly.

### Generating the report

```powershell
.\tools\Generate-QualityReport.ps1
```

This runs all test tiers, collects `.trx` result files, and produces `test-report.html` in the repo root.

To generate and immediately open:

```powershell
.\tools\Generate-QualityReport.ps1 -Open
```

### Reading the report

The HTML report is structured for IS leadership review:

| Section            | What it shows                                                               |
|--------------------|-----------------------------------------------------------------------------|
| **Summary**        | Pass/fail counts by category, overall health status (Green/Yellow/Red)      |
| **Smoke**          | Which pages load successfully; any auth failures                            |
| **Integration**    | Which stored procs return expected schema; snapshot freshness status         |
| **Data Quality**   | Table refresh timestamps, null-check results, row count sanity checks       |
| **Accessibility**  | WCAG violation count and severity breakdown by page                         |
| **Security**       | Auth enforcement status, header presence, secrets exposure check            |
| **Performance**    | Actual vs. threshold load times by page type                                |
| **Failures**       | Full failure messages and stack traces for anything that failed              |

### Sharing with management

`test-report.html` is self-contained (no external assets). Email it directly or drop it on a shared drive. It does not contain PHI/PII — only test pass/fail data and aggregate metrics.

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

Triggers automatically when the deploy workflow completes successfully. Runs `dotnet test --filter "Category=Smoke"`. Results appear in the Actions tab as "Smoke Test Results."

### Regression suite — nightly

```yaml
# .github/workflows/qa-regression.yml
on:
  schedule:
    - cron: '0 6 * * *'   # 6:00 AM UTC — 2:00 AM ET
```

Runs `dotnet test --filter "Category=Regression"` against the test environment. On failure, uploads `.trx` files and screenshots as artifacts (retained 7 days).

### Unit + Integration — on every PR

Add a CI workflow step to the PR build:

```yaml
- name: Run unit and integration tests
  run: dotnet test --filter "Category=Unit|Category=Integration"
  env:
    DIRECTOR_DASHBOARD_TEST_CONNSTR: ${{ secrets.INTEGRATION_TEST_CONNSTR }}
```

Unit tests run without any secrets. Integration tests require the connection string secret — configure this in your repo's Actions secrets.

### Self-hosted runner requirement

All QA workflows use `runs-on: [self-hosted, test-runner]`. The runner must be:
- Domain-joined (for Windows auth to SQL Server)
- Have .NET 10 SDK installed
- Have Node.js installed (for `qa-save-auth.js` and Playwright browser installs)
- Have `auth.json` present at the path stored in `E2E_AUTH_JSON_PATH` secret

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

    // Add page-specific helpers here — selectors, actions, data extractors
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
            "dbo.DirectorDashboard_GetMyNewProc",
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
ai-agent-config/qa-template/
  Infrastructure/
    ServiceNetTestBase.cs      Base class: Playwright browser lifecycle, auth context creation
    BlazorPageBase.cs          Base class: Blazor-specific helpers (WaitForLoad, GetErrorState,
                               GetSummaryStats, GetTableRows, IsAuthenticated)
  TestCategories.cs            Shared category constants (Unit, Smoke, Extended, Integration,
                               Regression, Performance, Accessibility, Security, DataQuality, API)
  workflows/
    qa-smoke.yml               GitHub Actions: smoke tests triggered after every test deploy
    qa-regression.yml          GitHub Actions: nightly full regression suite
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
    Auth/
      AuthStateManager.cs      Loads auth.json into Playwright browser context
    Infrastructure/
      E2ETestBase.cs           Browser lifecycle (copy of ServiceNetTestBase, namespace updated)
      BlazorPageBase.cs        Blazor helpers (copy of template, namespace updated)
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

- [ ] Run `/setup-testing` in Claude Code from the new project's directory
- [ ] Review and approve the plan presented by the skill
- [ ] Run the three `dotnet sln add` commands the skill prints
- [ ] Build the solution: `dotnet build`
- [ ] Install Playwright browsers: `pwsh tests/YourApp.Tests.E2E/bin/Debug/net10.0/playwright.ps1 install chromium`
- [ ] Set `DIRECTOR_DASHBOARD_TEST_CONNSTR` (or equivalent) in your dev environment
- [ ] Run unit tests to confirm build is clean: `dotnet test --filter "Category=Unit"`
- [ ] Run integration tests to confirm DB connectivity: `dotnet test --filter "Category=Integration"`
- [ ] Capture Azure AD auth state: `node qa-save-auth.js --url https://localhost:7052`
- [ ] Run smoke tests: `dotnet test --filter "Category=Smoke"`
- [ ] Commit the test projects (but not `auth.json`)
- [ ] Copy and customize `qa-smoke.yml` and `qa-regression.yml` into `.github/workflows/`
- [ ] Add the `INTEGRATION_TEST_CONNSTR` and `E2E_AUTH_JSON_PATH` secrets to the GitHub repo
- [ ] Verify the smoke workflow triggers after the next test deploy

Once smoke tests are green, add Extended and feature tests incrementally as you build out the app.

---

## PHI/PII Safety Rules

ServiceNet apps are HIPAA-covered. These rules apply to all test code:

**Never put real client or staff data in tests.** This includes:
- Real client names, IDs, dates of birth, addresses, or diagnoses
- Real staff names or email addresses (use `admin@servicenet.org` only for admin-access assertions against the test environment)
- Actual financial figures from production records
- Real program IDs that could be linked to an individual

**What is safe to use:**
- Aggregate counts and totals returned by authenticated API calls (you're asserting shape, not values)
- System-generated IDs that have no standalone meaning
- Column names and schema structure
- Synthetic placeholder data: `Jane Doe`, `PRG001`, `1970-01-01`
- Organization names (`Schools`, `CSS`) — these are program group labels, not individual identifiers

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

**`auth.json` is a credential.** It grants full authenticated access to the app. Treat it like a password — never commit it, never share it outside the development team, refresh it regularly.
