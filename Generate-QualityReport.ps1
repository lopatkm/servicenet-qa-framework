<#
.SYNOPSIS
    Generates an HTML quality report from xUnit TRX test result files.

.DESCRIPTION
    Run after `dotnet test --logger "trx;LogFileName=results.trx"`.
    Parses all *.trx files in the repository, groups results by category,
    and generates a single HTML dashboard readable by developers and management.

.PARAMETER OutputPath
    Path for the generated HTML file. Default: test-report.html

.PARAMETER ResultsPattern
    Glob pattern for TRX files. Default: **\TestResults\*.trx

.EXAMPLE
    .\tools\Generate-QualityReport.ps1
    .\tools\Generate-QualityReport.ps1 -OutputPath C:\Reports\qa-$(Get-Date -f yyyyMMdd).html

.NOTES
    Designed for ServiceNet IS QA framework. PHI-safe: no test data appears in output.
#>
param(
    [string]$OutputPath      = "test-report.html",
    [string]$ResultsPattern  = "**\TestResults\*.trx"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ── Collect TRX files ─────────────────────────────────────────────────────────
$trxFiles = Get-ChildItem -Path $PSScriptRoot\.. -Filter "*.trx" -Recurse -ErrorAction SilentlyContinue

if (-not $trxFiles) {
    Write-Warning "No TRX files found. Run: dotnet test --logger `"trx;LogFileName=results.trx`" first."
    exit 1
}

# ── Parse results ─────────────────────────────────────────────────────────────
$allTests = [System.Collections.Generic.List[PSCustomObject]]::new()

foreach ($file in $trxFiles) {
    [xml]$trx = Get-Content $file.FullName -Raw

    $ns = @{ t = "http://microsoft.com/schemas/VisualStudio/TeamTest/2010" }

    $trx.SelectNodes("//t:UnitTestResult", (New-Object System.Xml.XmlNamespaceManager($trx.NameTable)) | ForEach-Object {
        $_.AddNamespace("t", "http://microsoft.com/schemas/VisualStudio/TeamTest/2010"); $_
    }) | ForEach-Object {
        # Extract category from test name or properties
        $outcome  = $_.outcome
        $name     = $_.testName
        $duration = $_.duration

        # Try to extract category from trait annotations (baked into test name or description)
        $category = "Uncategorized"
        if ($name -match "Smoke|smoke")             { $category = "Smoke" }
        elseif ($name -match "Perf|perf|load|Load") { $category = "Performance" }
        elseif ($name -match "Access|a11y|axe")     { $category = "Accessibility" }
        elseif ($name -match "Security|security|Auth|auth|Header") { $category = "Security" }
        elseif ($name -match "Data|Quality|Schema|Null|Refresh") { $category = "DataQuality" }
        elseif ($name -match "Integration|integration|Proc|proc")  { $category = "Integration" }
        elseif ($name -match "Unit|unit")            { $category = "Unit" }

        $allTests.Add([PSCustomObject]@{
            Name     = $name
            Outcome  = $outcome
            Category = $category
            Duration = $duration
            File     = $file.Name
        })
    }
}

# ── Aggregate by category ──────────────────────────────────────────────────────
$categories = $allTests | Group-Object Category | ForEach-Object {
    $passed  = ($_.Group | Where-Object Outcome -eq "Passed").Count
    $failed  = ($_.Group | Where-Object Outcome -eq "Failed").Count
    $skipped = ($_.Group | Where-Object Outcome -in @("NotExecuted","Skipped")).Count
    $total   = $_.Count
    $pct     = if ($total -gt 0) { [math]::Round($passed / $total * 100) } else { 0 }
    [PSCustomObject]@{
        Category = $_.Name
        Total    = $total
        Passed   = $passed
        Failed   = $failed
        Skipped  = $skipped
        Pct      = $pct
    }
}

$grandTotal  = $allTests.Count
$grandPassed = ($allTests | Where-Object Outcome -eq "Passed").Count
$grandFailed = ($allTests | Where-Object Outcome -eq "Failed").Count
$overallPct  = if ($grandTotal -gt 0) { [math]::Round($grandPassed / $grandTotal * 100) } else { 0 }
$runDate     = Get-Date -Format "yyyy-MM-dd HH:mm"
$statusColor = if ($grandFailed -eq 0) { "#16a34a" } else { "#dc2626" }
$statusLabel = if ($grandFailed -eq 0) { "PASSING" } else { "FAILING" }

# ── Category row HTML ──────────────────────────────────────────────────────────
function Get-CategoryIcon($cat) {
    switch ($cat) {
        "Smoke"         { return "🟢" }
        "Unit"          { return "🔵" }
        "Integration"   { return "🟣" }
        "Performance"   { return "⚡" }
        "Accessibility" { return "♿" }
        "Security"      { return "🔒" }
        "DataQuality"   { return "📊" }
        "Extended"      { return "🔄" }
        "Regression"    { return "🧪" }
        default         { return "⬜" }
    }
}

$categoryRows = ($categories | Sort-Object Category | ForEach-Object {
    $barColor = if ($_.Failed -gt 0) { "#dc2626" } elseif ($_.Pct -ge 80) { "#16a34a" } else { "#ca8a04" }
    $icon = Get-CategoryIcon $_.Category
    "<tr>
        <td>$icon $($_.Category)</td>
        <td>$($_.Total)</td>
        <td style='color:#16a34a;font-weight:600'>$($_.Passed)</td>
        <td style='color:$(if($_.Failed -gt 0){"#dc2626"}else{"#6b7280"});font-weight:600'>$($_.Failed)</td>
        <td style='color:#6b7280'>$($_.Skipped)</td>
        <td>
            <div style='display:flex;align-items:center;gap:8px'>
                <div style='flex:1;background:#f3f4f6;border-radius:4px;height:8px'>
                    <div style='width:$($_.Pct)%;background:$barColor;border-radius:4px;height:8px'></div>
                </div>
                <span style='font-size:0.8rem;font-weight:600;color:$barColor;min-width:3ch'>$($_.Pct)%</span>
            </div>
        </td>
    </tr>"
}) -join "`n"

$failedRows = ""
$failedTests = $allTests | Where-Object Outcome -eq "Failed"
if ($failedTests) {
    $failedRows = ($failedTests | ForEach-Object {
        "<tr><td style='color:#dc2626;font-weight:500'>$($_.Name)</td><td>$($_.Category)</td><td>$($_.File)</td></tr>"
    }) -join "`n"
}

# ── Generate HTML ──────────────────────────────────────────────────────────────
$html = @"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>ServiceNet QA Report — $runDate</title>
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body { font-family: -apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif; background: #f9fafb; color: #111827; padding: 2rem; }
  .header { background: #1e1b4b; color: white; border-radius: 12px; padding: 2rem; margin-bottom: 2rem; display: flex; justify-content: space-between; align-items: center; }
  .header h1 { font-size: 1.5rem; font-weight: 700; }
  .header .meta { font-size: 0.85rem; opacity: 0.7; margin-top: 0.25rem; }
  .status-badge { background: $statusColor; color: white; border-radius: 8px; padding: 0.5rem 1.25rem; font-weight: 700; font-size: 1.1rem; }
  .stats { display: grid; grid-template-columns: repeat(4,1fr); gap: 1rem; margin-bottom: 2rem; }
  .stat-card { background: white; border-radius: 10px; padding: 1.5rem; box-shadow: 0 1px 3px rgba(0,0,0,0.08); text-align: center; }
  .stat-card .value { font-size: 2.2rem; font-weight: 700; }
  .stat-card .label { font-size: 0.8rem; color: #6b7280; text-transform: uppercase; letter-spacing: 0.05em; margin-top: 0.25rem; }
  .card { background: white; border-radius: 10px; padding: 1.5rem; box-shadow: 0 1px 3px rgba(0,0,0,0.08); margin-bottom: 1.5rem; }
  .card h2 { font-size: 1rem; font-weight: 700; margin-bottom: 1rem; color: #374151; }
  table { width: 100%; border-collapse: collapse; font-size: 0.9rem; }
  th { text-align: left; padding: 0.6rem 0.75rem; background: #f9fafb; color: #6b7280; font-size: 0.75rem; text-transform: uppercase; letter-spacing: 0.05em; border-bottom: 1px solid #e5e7eb; }
  td { padding: 0.65rem 0.75rem; border-bottom: 1px solid #f3f4f6; }
  tr:last-child td { border-bottom: none; }
  .no-failures { color: #16a34a; font-style: italic; padding: 1rem 0; }
  footer { text-align: center; color: #9ca3af; font-size: 0.8rem; margin-top: 2rem; }
</style>
</head>
<body>

<div class="header">
  <div>
    <h1>ServiceNet QA Report</h1>
    <div class="meta">Generated: $runDate &nbsp;·&nbsp; $grandTotal tests across $(($categories | Measure-Object).Count) categories</div>
  </div>
  <div class="status-badge">$statusLabel</div>
</div>

<div class="stats">
  <div class="stat-card"><div class="value">$grandTotal</div><div class="label">Total Tests</div></div>
  <div class="stat-card"><div class="value" style="color:#16a34a">$grandPassed</div><div class="label">Passing</div></div>
  <div class="stat-card"><div class="value" style="color:#dc2626">$grandFailed</div><div class="label">Failing</div></div>
  <div class="stat-card"><div class="value" style="color:$statusColor">$overallPct%</div><div class="label">Pass Rate</div></div>
</div>

<div class="card">
  <h2>Results by Category</h2>
  <table>
    <thead><tr><th>Category</th><th>Total</th><th>Passed</th><th>Failed</th><th>Skipped</th><th>Pass Rate</th></tr></thead>
    <tbody>$categoryRows</tbody>
  </table>
</div>

$(if ($grandFailed -gt 0) {
"<div class='card'>
  <h2 style='color:#dc2626'>⚠ Failing Tests ($grandFailed)</h2>
  <table>
    <thead><tr><th>Test Name</th><th>Category</th><th>Result File</th></tr></thead>
    <tbody>$failedRows</tbody>
  </table>
</div>"
} else {
"<div class='card'><p class='no-failures'>✓ All tests passing — no failures to report.</p></div>"
})

<footer>ServiceNet IS · QA Framework · PHI-safe report (no client data) · $runDate</footer>
</body>
</html>
"@

$html | Out-File -FilePath $OutputPath -Encoding utf8
Write-Output "Report generated: $OutputPath ($grandTotal tests, $grandFailed failures)"
if ($grandFailed -gt 0) { exit 1 } else { exit 0 }
