namespace ServiceNet.Tests.Infrastructure;

/// <summary>
/// Standard test category constants for all ServiceNet QA suites.
/// Apply with [Trait("Category", TestCategories.Smoke)] etc.
/// Combine categories freely: [Trait("Category", "Smoke")] [Trait("Category", "Regression")]
/// </summary>
public static class TestCategories
{
    /// <summary>Fast health checks. Run on every deploy. Must complete under 2 minutes.
    /// Covers: app responds, auth works, key pages load without error.</summary>
    public const string Smoke = "Smoke";

    /// <summary>Full feature coverage. Run before releases. ~10 minutes.
    /// Covers: all user-facing flows, filters, drilldowns, edge cases.</summary>
    public const string Extended = "Extended";

    /// <summary>Requires live SQL Server access. Run in CI with DB connectivity.
    /// Covers: stored proc schemas, security scoping, data shape validation.</summary>
    public const string Integration = "Integration";

    /// <summary>Full nightly suite. Tags tests that belong in the end-to-end regression pass.
    /// Typically combined with Smoke + Extended + Integration.</summary>
    public const string Regression = "Regression";

    /// <summary>Pure logic tests. No I/O, no database, no browser. Always fast.
    /// Covers: helper methods, formatters, state machines, DTO logic.</summary>
    public const string Unit = "Unit";

    /// <summary>Page load time and SQL query benchmarks.
    /// Covers: key pages load under threshold, heavy procs run under SLA.</summary>
    public const string Performance = "Performance";

    /// <summary>WCAG 2.1 accessibility compliance via axe-core.
    /// Covers: missing labels, low contrast, keyboard nav, ARIA roles.
    /// ServiceNet obligation: staff-facing tools must be accessible.</summary>
    public const string Accessibility = "Accessibility";

    /// <summary>Security posture checks.
    /// Covers: auth enforcement, security response headers, no PHI/PII in page source.</summary>
    public const string Security = "Security";

    /// <summary>Data completeness and integrity checks against live database.
    /// Covers: required fields are non-null, totals are in expected ranges, no orphaned records.</summary>
    public const string DataQuality = "DataQuality";

    /// <summary>HTTP API contract tests (status codes, response shape, auth enforcement).
    /// Use for apps that expose REST endpoints or Blazor API controllers.</summary>
    public const string Api = "API";
}
