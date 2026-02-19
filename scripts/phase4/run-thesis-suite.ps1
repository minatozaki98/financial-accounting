param(
    [string]$BaseUrl = "http://localhost:5296",
    [string]$OpenApiUrl = "http://localhost:5296/swagger/v1/swagger.json",
    [string]$Username = "admin",
    [string]$Password = "Admin@123",
    [string]$ApiVersion = "1.0",
    [int]$PeriodId = 202601,
    [int]$AccountCount = 120,
    [int]$JournalEntryCount = 30000,
    [int]$MinimumPostedEntries = 5000,
    [int]$AccountId = 0,
    [string]$ConnectionString,
    [string]$PerformanceDir = "Document/performance",
    [string]$SecurityDir = "Document/security",
    [string]$BaselineAnchorPath = "Document/performance/thesis-baseline-anchor.json",
    [string]$SonarToken = "",
    [switch]$IgnoreZapWarnings,
    [switch]$SkipSeed
)

$ErrorActionPreference = "Stop"

function Resolve-FullPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    [System.IO.Path]::GetFullPath($Path)
}

function Get-StatValueOrDefault {
    param($Value, [double]$DefaultValue = 0)
    if ($null -eq $Value) {
        return $DefaultValue
    }

    return [double]$Value
}

function Get-ZapFailRuleIds {
    param([Parameter(Mandatory = $true)][string]$RulesPath)

    $ids = New-Object System.Collections.Generic.HashSet[string]
    foreach ($line in Get-Content $RulesPath) {
        if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith("#")) {
            continue
        }

        $parts = $line -split "`t"
        if ($parts.Length -lt 2) {
            continue
        }

        if ($parts[1].Trim().ToUpperInvariant() -eq "FAIL") {
            $null = $ids.Add($parts[0].Trim())
        }
    }

    return @($ids)
}

function Get-ZapBusinessSummary {
    param(
        [Parameter(Mandatory = $true)][string]$JsonPath,
        [string[]]$BusinessPrefixes,
        [string[]]$FailRuleIds
    )

    $content = Get-Content -Path $JsonPath -Raw | ConvertFrom-Json -Depth 100
    $high = 0
    $medium = 0
    $low = 0
    $info = 0
    $failHits = New-Object System.Collections.Generic.HashSet[string]

    foreach ($site in @($content.site)) {
        foreach ($alert in @($site.alerts)) {
            $riskCode = [int]$alert.riskcode
            $pluginId = [string]$alert.pluginid
            $isBusinessAlert = $false

            foreach ($instance in @($alert.instances)) {
                if ($null -eq $instance) {
                    continue
                }

                $uri = [string]$instance.uri
                if ([string]::IsNullOrWhiteSpace($uri)) {
                    continue
                }

                try {
                    $path = ([Uri]$uri).AbsolutePath.ToLowerInvariant()
                    foreach ($prefix in $BusinessPrefixes) {
                        if ($path.StartsWith($prefix)) {
                            $isBusinessAlert = $true
                            break
                        }
                    }
                }
                catch {
                    continue
                }

                if ($isBusinessAlert) {
                    break
                }
            }

            if (-not $isBusinessAlert) {
                continue
            }

            switch ($riskCode) {
                3 { $high++ }
                2 { $medium++ }
                1 { $low++ }
                default { $info++ }
            }

            if ($FailRuleIds -contains $pluginId) {
                $null = $failHits.Add("${pluginId}:$($alert.alert)")
            }
        }
    }

    [pscustomobject]@{
        High = $high
        Medium = $medium
        Low = $low
        Info = $info
        FailRuleHits = @($failHits)
    }
}

function Get-Statistics {
    param([Parameter(Mandatory = $true)][string]$Path)
    Get-Content -Path $Path -Raw | ConvertFrom-Json -Depth 20
}

function Get-P95 {
    param([Parameter(Mandatory = $true)][double[]]$Values)

    if ($Values.Count -eq 0) {
        return 0
    }

    $sorted = $Values | Sort-Object
    $index = [Math]::Ceiling($sorted.Count * 0.95) - 1
    if ($index -lt 0) { $index = 0 }
    $sorted[$index]
}

function Get-JtlDriftSummary {
    param([Parameter(Mandatory = $true)][string]$JtlPath)

    if (-not (Test-Path $JtlPath)) {
        return [pscustomobject]@{ FirstP95 = 0; LastP95 = 0; DriftPct = 0 }
    }

    $rows = Import-Csv -Path $JtlPath | Sort-Object { [long]$_.timeStamp }
    if ($rows.Count -lt 10) {
        return [pscustomobject]@{ FirstP95 = 0; LastP95 = 0; DriftPct = 0 }
    }

    $windowSize = [Math]::Max(1, [Math]::Floor($rows.Count * 0.2))
    $firstWindow = $rows | Select-Object -First $windowSize
    $lastWindow = $rows | Select-Object -Last $windowSize

    $firstP95 = Get-P95 -Values ($firstWindow | ForEach-Object { [double]$_.elapsed })
    $lastP95 = Get-P95 -Values ($lastWindow | ForEach-Object { [double]$_.elapsed })

    $drift = 0
    if ($firstP95 -gt 0) {
        $drift = (($lastP95 - $firstP95) / $firstP95) * 100
    }

    [pscustomobject]@{
        FirstP95 = [Math]::Round($firstP95, 2)
        LastP95 = [Math]::Round($lastP95, 2)
        DriftPct = [Math]::Round($drift, 2)
    }
}

function Get-RuntimeMetricsSummary {
    param([Parameter(Mandatory = $true)][string]$CsvPath)

    if (-not (Test-Path $CsvPath)) {
        return [pscustomobject]@{
            SampleCount = 0
            AvgCpuPct = 0
            MaxCpuPct = 0
            MaxWorkingSetMb = 0
            MemoryGrowthMb = 0
        }
    }

    $rows = Import-Csv -Path $CsvPath
    if ($rows.Count -eq 0) {
        return [pscustomobject]@{
            SampleCount = 0
            AvgCpuPct = 0
            MaxCpuPct = 0
            MaxWorkingSetMb = 0
            MemoryGrowthMb = 0
        }
    }

    $avgCpu = ($rows | Measure-Object -Property CpuTotalPct -Average).Average
    $maxCpu = ($rows | Measure-Object -Property CpuTotalPct -Maximum).Maximum
    $maxWs = ($rows | Measure-Object -Property WorkingSetMb -Maximum).Maximum
    $startMem = [double]$rows[0].WorkingSetMb
    $endMem = [double]$rows[$rows.Count - 1].WorkingSetMb

    [pscustomobject]@{
        SampleCount = $rows.Count
        AvgCpuPct = [Math]::Round($avgCpu, 2)
        MaxCpuPct = [Math]::Round($maxCpu, 2)
        MaxWorkingSetMb = [Math]::Round($maxWs, 2)
        MemoryGrowthMb = [Math]::Round(($endMem - $startMem), 2)
    }
}

function Get-TestResultSummary {
    param([Parameter(Mandatory = $true)][string]$TrxPath)

    if (-not (Test-Path $TrxPath)) {
        return [pscustomobject]@{ Total = 0; Passed = 0; Failed = 0 }
    }

    [xml]$trx = Get-Content -Path $TrxPath
    $summary = $trx.TestRun.ResultSummary.Counters

    [pscustomobject]@{
        Total = [int]$summary.total
        Passed = [int]$summary.passed
        Failed = [int]$summary.failed
    }
}

function Get-RbacResultSummary {
    param([Parameter(Mandatory = $true)][string]$TrxPath)

    if (-not (Test-Path $TrxPath)) {
        return [pscustomobject]@{ Total = 0; Passed = 0; Failed = 0 }
    }

    [xml]$trx = Get-Content -Path $TrxPath
    $rbacResults = @($trx.TestRun.Results.UnitTestResult | Where-Object { $_.testName -like "*RbacMatrixTests*" })

    [pscustomobject]@{
        Total = $rbacResults.Count
        Passed = (@($rbacResults | Where-Object { $_.outcome -eq "Passed" })).Count
        Failed = (@($rbacResults | Where-Object { $_.outcome -eq "Failed" })).Count
    }
}

function Get-CoveragePctFromResults {
    param([Parameter(Mandatory = $true)][string]$ResultsDir)

    if (-not (Test-Path $ResultsDir)) {
        return 0
    }

    $coverageFiles = Get-ChildItem -Path $ResultsDir -Recurse -Filter "coverage.cobertura.xml" -File -ErrorAction SilentlyContinue
    if ($coverageFiles.Count -eq 0) {
        return 0
    }

    $linesCovered = 0.0
    $linesValid = 0.0
    foreach ($file in $coverageFiles) {
        [xml]$coverage = Get-Content -Path $file.FullName
        $linesCovered += [double]$coverage.coverage.'lines-covered'
        $linesValid += [double]$coverage.coverage.'lines-valid'
    }

    if ($linesValid -le 0) {
        return 0
    }

    return [Math]::Round((($linesCovered / $linesValid) * 100), 2)
}

$fullPerformanceDir = Resolve-FullPath -Path $PerformanceDir
$fullSecurityDir = Resolve-FullPath -Path $SecurityDir
$fullBaselineAnchorPath = Resolve-FullPath -Path $BaselineAnchorPath
New-Item -ItemType Directory -Path $fullPerformanceDir -Force | Out-Null
New-Item -ItemType Directory -Path $fullSecurityDir -Force | Out-Null

$runId = Get-Date -Format "yyyyMMdd-HHmmss"
$hardFailures = New-Object System.Collections.Generic.List[string]
$softFlags = New-Object System.Collections.Generic.List[string]

if (-not $SkipSeed) {
    $seedScript = Join-Path $PSScriptRoot "seed-test-data.ps1"
    $seedParams = @{
        AdminUsername = $Username
        AdminPassword = $Password
        PeriodId = $PeriodId
        AccountCount = $AccountCount
        JournalEntryCount = $JournalEntryCount
        MinimumPostedEntries = $MinimumPostedEntries
    }

    if (-not [string]::IsNullOrWhiteSpace($ConnectionString)) {
        $seedParams.ConnectionString = $ConnectionString
    }

    $seedResult = & $seedScript @seedParams
}

$effectiveAccountId = if ($AccountId -gt 0) { $AccountId } elseif ($seedResult -and $seedResult.DefaultAccountId) { [int]$seedResult.DefaultAccountId } else { 1 }

$unitResultsDir = Join-Path $fullPerformanceDir "test-results-unit-$runId"
$integrationResultsDir = Join-Path $fullPerformanceDir "test-results-integration-$runId"
New-Item -ItemType Directory -Force -Path $unitResultsDir | Out-Null
New-Item -ItemType Directory -Force -Path $integrationResultsDir | Out-Null

dotnet test tests/FinancialAccounting.UnitTests/FinancialAccounting.UnitTests.csproj --collect:"XPlat Code Coverage" --logger "trx;LogFileName=unit-$runId.trx" --results-directory $unitResultsDir
dotnet test tests/FinancialAccounting.IntegrationTests/FinancialAccounting.IntegrationTests.csproj --collect:"XPlat Code Coverage" --logger "trx;LogFileName=integration-$runId.trx" --results-directory $integrationResultsDir

$unitTrxPath = Join-Path $unitResultsDir "unit-$runId.trx"
$integrationTrxPath = Join-Path $integrationResultsDir "integration-$runId.trx"
$unitTestResult = Get-TestResultSummary -TrxPath $unitTrxPath
$integrationTestResult = Get-TestResultSummary -TrxPath $integrationTrxPath
$rbacResult = Get-RbacResultSummary -TrxPath $integrationTrxPath

if ($unitTestResult.Failed -gt 0) {
    $hardFailures.Add("Unit tests failed. Failed=$($unitTestResult.Failed) of Total=$($unitTestResult.Total).")
}
if ($integrationTestResult.Failed -gt 0) {
    $hardFailures.Add("Integration tests failed. Failed=$($integrationTestResult.Failed) of Total=$($integrationTestResult.Total).")
}

$unitCoveragePct = Get-CoveragePctFromResults -ResultsDir $unitResultsDir
$integrationCoveragePct = Get-CoveragePctFromResults -ResultsDir $integrationResultsDir
if ($unitCoveragePct -lt 70) {
    $hardFailures.Add("Coverage gate failed: Unit coverage $unitCoveragePct% is below 70%.")
}
if ($integrationCoveragePct -lt 60) {
    $hardFailures.Add("Coverage gate failed: Integration coverage $integrationCoveragePct% is below 60%.")
}
if ($rbacResult.Failed -gt 0) {
    $hardFailures.Add("RBAC matrix tests failed. Failed=$($rbacResult.Failed) of Total=$($rbacResult.Total).")
}

$zapBaselineScript = Join-Path $PSScriptRoot "run-zap-baseline.ps1"
$zapApiScript = Join-Path $PSScriptRoot "run-zap-api.ps1"

$zapBaselineResult = & $zapBaselineScript `
    -TargetUrl "$BaseUrl/swagger" `
    -ReportDir $fullSecurityDir `
    -OutputPrefix "zap-baseline-$runId" `
    -IgnoreWarnings:$IgnoreZapWarnings

$zapApiResult = & $zapApiScript `
    -OpenApiUrl $OpenApiUrl `
    -BaseUrl $BaseUrl `
    -Username $Username `
    -Password $Password `
    -ApiVersion $ApiVersion `
    -ReportDir $fullSecurityDir `
    -OutputPrefix "zap-api-$runId" `
    -IgnoreWarnings:$IgnoreZapWarnings

$businessPrefixes = @("/auth", "/users", "/accounts", "/journal-entries", "/periods", "/reports", "/audit-logs")
$failRuleIds = Get-ZapFailRuleIds -RulesPath (Resolve-FullPath -Path "scripts/phase4/zap-api-rules.tsv")
$baselineSecurity = Get-ZapBusinessSummary -JsonPath $zapBaselineResult.JsonReportPath -BusinessPrefixes $businessPrefixes -FailRuleIds $failRuleIds
$apiSecurity = Get-ZapBusinessSummary -JsonPath $zapApiResult.JsonReportPath -BusinessPrefixes $businessPrefixes -FailRuleIds $failRuleIds

$combinedHigh = $baselineSecurity.High + $apiSecurity.High
$combinedMedium = $baselineSecurity.Medium + $apiSecurity.Medium
$combinedFailHits = @($baselineSecurity.FailRuleHits + $apiSecurity.FailRuleHits | Sort-Object -Unique)
$securityGateStatus = if ($combinedHigh -eq 0 -and $combinedMedium -eq 0 -and $combinedFailHits.Count -eq 0) { "PASS" } else { "FAIL" }

if ($combinedHigh -gt 0) {
    $hardFailures.Add("Security gate failed: High severity business API alerts = $combinedHigh (expected 0).")
}
if ($combinedMedium -gt 0) {
    $hardFailures.Add("Security gate failed: Medium severity business API alerts = $combinedMedium (expected 0).")
}
if ($combinedFailHits.Count -gt 0) {
    $hardFailures.Add("Security gate failed: FAIL-rule alerts detected: $($combinedFailHits -join ', ').")
}

$metricsScript = Join-Path $PSScriptRoot "collect-runtime-metrics.ps1"
$metricsPath = Join-Path $fullPerformanceDir "runtime-metrics-$runId.csv"
$metricsJob = Start-Job -ScriptBlock {
    param($scriptPath, $outputPath)
    & $scriptPath -OutputPath $outputPath -DurationSeconds 7200 -IntervalSeconds 5
} -ArgumentList $metricsScript, $metricsPath

try {
    $matrixScript = Join-Path $PSScriptRoot "run-jmeter-thesis-matrix.ps1"
    $matrixResult = & $matrixScript `
        -BaseUrl $BaseUrl `
        -Username $Username `
        -Password $Password `
        -ApiVersion $ApiVersion `
        -PeriodId $PeriodId `
        -AccountId $effectiveAccountId `
        -ResultsDir $fullPerformanceDir `
        -RunTag $runId
}
finally {
    Stop-Job -Job $metricsJob -ErrorAction SilentlyContinue | Out-Null
    Receive-Job -Job $metricsJob -ErrorAction SilentlyContinue | Out-Null
    Remove-Job -Job $metricsJob -ErrorAction SilentlyContinue
}

$profileThresholds = @{
    "50" = @{ MaxErrorPct = 0.5; MaxP95 = 300 }
    "100" = @{ MaxErrorPct = 1.0; MaxP95 = 500 }
    "500" = @{ MaxErrorPct = 2.0; MaxP95 = 1200 }
}

$profileStats = @{}
foreach ($profile in @("50", "100", "500")) {
    $statsPath = [string]$matrixResult.Profiles.$profile.StatisticsPath
    $stats = Get-Statistics -Path $statsPath
    $profileStats[$profile] = $stats

    $errorPct = Get-StatValueOrDefault -Value $stats.Total.errorPct
    $p95 = Get-StatValueOrDefault -Value $stats.Total.pct2ResTime

    if ($errorPct -gt $profileThresholds[$profile].MaxErrorPct) {
        $hardFailures.Add("Performance gate failed for profile ${profile}: errorPct=$([Math]::Round($errorPct, 2)) > $($profileThresholds[$profile].MaxErrorPct).")
    }
    if ($p95 -gt $profileThresholds[$profile].MaxP95) {
        $hardFailures.Add("Performance gate failed for profile ${profile}: p95=$([Math]::Round($p95, 2))ms > $($profileThresholds[$profile].MaxP95)ms.")
    }
}

$soakStats = Get-Statistics -Path ([string]$matrixResult.Soak.StatisticsPath)
$spikeStats = Get-Statistics -Path ([string]$matrixResult.Spike.StatisticsPath)
$soakDrift = Get-JtlDriftSummary -JtlPath ([string]$matrixResult.Soak.JtlPath)
$spikeDrift = Get-JtlDriftSummary -JtlPath ([string]$matrixResult.Spike.JtlPath)

$soakError = Get-StatValueOrDefault -Value $soakStats.Total.errorPct
if ($soakError -gt 1.0) {
    $hardFailures.Add("Soak gate failed: errorPct=$([Math]::Round($soakError, 2)) > 1.0.")
}
if ($soakDrift.DriftPct -gt 20) {
    $hardFailures.Add("Soak gate failed: p95 drift=$($soakDrift.DriftPct)% > 20%.")
}

$spikeError = Get-StatValueOrDefault -Value $spikeStats.Total.errorPct
if ($spikeError -gt 3.0) {
    $hardFailures.Add("Spike gate failed: errorPct=$([Math]::Round($spikeError, 2)) > 3.0.")
}
if ($spikeDrift.DriftPct -gt 20) {
    $hardFailures.Add("Spike recovery gate failed: p95 drift=$($spikeDrift.DriftPct)% > 20%.")
}

$runtimeSummary = Get-RuntimeMetricsSummary -CsvPath $metricsPath
if ($runtimeSummary.MemoryGrowthMb -gt 1024) {
    $softFlags.Add("Memory growth exceeded 1GB during run ($($runtimeSummary.MemoryGrowthMb) MB).")
}

$performanceGateStatus = if ($hardFailures | Where-Object { $_ -like "Performance gate failed*" -or $_ -like "Soak gate failed*" -or $_ -like "Spike gate failed*" -or $_ -like "Spike recovery gate failed*" }) { "FAIL" } else { "PASS" }

$sonarStatus = "SKIPPED"
$sonarSummary = $null
if (-not [string]::IsNullOrWhiteSpace($SonarToken)) {
    $sonarScript = Join-Path $PSScriptRoot "get-sonar-summary.ps1"
    $sonarSummary = & $sonarScript -SonarToken $SonarToken -ProjectKey "financial-accounting"
    $sonarStatus = [string]$sonarSummary.QualityGate

    if ($sonarStatus -ne "OK") {
        $hardFailures.Add("Sonar quality gate failed with status '$sonarStatus'.")
    }
}
else {
    $softFlags.Add("SonarToken was not provided; Sonar quality gate check was skipped.")
}

$overallStatus = if ($hardFailures.Count -gt 0) { "FAIL" } elseif ($softFlags.Count -gt 0) { "PASS_WITH_SOFT_FLAGS" } else { "PASS" }

$summaryPath = Join-Path $fullPerformanceDir "test-summary-$runId.md"
$summary = New-Object System.Text.StringBuilder
$null = $summary.AppendLine("# Thesis Test Summary ($runId)")
$null = $summary.AppendLine()
$null = $summary.AppendLine("## Overall")
$null = $summary.AppendLine("- OverallStatus: $overallStatus")
$null = $summary.AppendLine("- Unit Tests Total/Passed/Failed: $($unitTestResult.Total)/$($unitTestResult.Passed)/$($unitTestResult.Failed)")
$null = $summary.AppendLine("- Integration Tests Total/Passed/Failed: $($integrationTestResult.Total)/$($integrationTestResult.Passed)/$($integrationTestResult.Failed)")
$null = $summary.AppendLine("- RBAC Tests Total/Passed/Failed: $($rbacResult.Total)/$($rbacResult.Passed)/$($rbacResult.Failed)")
$null = $summary.AppendLine("- Unit Coverage %: $unitCoveragePct")
$null = $summary.AppendLine("- Integration Coverage %: $integrationCoveragePct")
$null = $summary.AppendLine("- SecurityGate: $securityGateStatus")
$null = $summary.AppendLine("- PerformanceGate: $performanceGateStatus")
$null = $summary.AppendLine("- SonarQualityGate: $sonarStatus")
$null = $summary.AppendLine()
$null = $summary.AppendLine("## Security")
$null = $summary.AppendLine("- Business High/Medium: $combinedHigh/$combinedMedium")
$null = $summary.AppendLine("- FailRuleHits: $(if ($combinedFailHits.Count -eq 0) { 'None' } else { $combinedFailHits -join ', ' })")
$null = $summary.AppendLine("- Baseline JSON: $($zapBaselineResult.JsonReportPath)")
$null = $summary.AppendLine("- API JSON: $($zapApiResult.JsonReportPath)")
$null = $summary.AppendLine()
$null = $summary.AppendLine("## Performance")
$null = $summary.AppendLine("| Profile | Error% | p95(ms) | Throughput(tx/s) | StatsPath |")
$null = $summary.AppendLine("| --- | ---: | ---: | ---: | --- |")
foreach ($profile in @("50", "100", "500")) {
    $stats = $profileStats[$profile]
    $null = $summary.AppendLine("| $profile | $([Math]::Round((Get-StatValueOrDefault $stats.Total.errorPct),2)) | $([Math]::Round((Get-StatValueOrDefault $stats.Total.pct2ResTime),2)) | $([Math]::Round((Get-StatValueOrDefault $stats.Total.throughput),2)) | $([string]$matrixResult.Profiles.$profile.StatisticsPath) |")
}
$null = $summary.AppendLine("| soak | $([Math]::Round($soakError,2)) | $([Math]::Round((Get-StatValueOrDefault $soakStats.Total.pct2ResTime),2)) | $([Math]::Round((Get-StatValueOrDefault $soakStats.Total.throughput),2)) | $([string]$matrixResult.Soak.StatisticsPath) |")
$null = $summary.AppendLine("| spike | $([Math]::Round($spikeError,2)) | $([Math]::Round((Get-StatValueOrDefault $spikeStats.Total.pct2ResTime),2)) | $([Math]::Round((Get-StatValueOrDefault $spikeStats.Total.throughput),2)) | $([string]$matrixResult.Spike.StatisticsPath) |")
$null = $summary.AppendLine()
$null = $summary.AppendLine("## Reliability")
$null = $summary.AppendLine("- SoakDriftPct: $($soakDrift.DriftPct)")
$null = $summary.AppendLine("- SpikeDriftPct: $($spikeDrift.DriftPct)")
$null = $summary.AppendLine("- MetricsCsv: $metricsPath")
$null = $summary.AppendLine("- Runtime AvgCpu/MaxCpu: $($runtimeSummary.AvgCpuPct)/$($runtimeSummary.MaxCpuPct)")
$null = $summary.AppendLine("- Runtime MaxWorkingSetMb: $($runtimeSummary.MaxWorkingSetMb)")
$null = $summary.AppendLine("- Runtime MemoryGrowthMb: $($runtimeSummary.MemoryGrowthMb)")
$null = $summary.AppendLine()
$null = $summary.AppendLine("## Hard Failures")
if ($hardFailures.Count -eq 0) {
    $null = $summary.AppendLine("- None")
}
else {
    foreach ($item in $hardFailures) {
        $null = $summary.AppendLine("- $item")
    }
}
$null = $summary.AppendLine()
$null = $summary.AppendLine("## Soft Flags")
if ($softFlags.Count -eq 0) {
    $null = $summary.AppendLine("- None")
}
else {
    foreach ($item in $softFlags) {
        $null = $summary.AppendLine("- $item")
    }
}

[System.IO.File]::WriteAllText($summaryPath, $summary.ToString())

if (-not (Test-Path $fullBaselineAnchorPath)) {
    $anchorParent = Split-Path $fullBaselineAnchorPath -Parent
    if ($anchorParent) {
        New-Item -ItemType Directory -Path $anchorParent -Force | Out-Null
    }

    [pscustomobject]@{
        runId = $runId
        createdAtUtc = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
        performanceByProfile = [pscustomobject]@{
            "50" = $matrixResult.Profiles."50"
            "100" = $matrixResult.Profiles."100"
            "500" = $matrixResult.Profiles."500"
            soak = $matrixResult.Soak
            spike = $matrixResult.Spike
        }
        zapBaselineJsonPath = [string]$zapBaselineResult.JsonReportPath
        zapApiJsonPath = [string]$zapApiResult.JsonReportPath
        summaryPath = $summaryPath
    } | ConvertTo-Json -Depth 20 | Set-Content -Path $fullBaselineAnchorPath -Encoding UTF8
}

$result = [pscustomobject]@{
    RunId = $runId
    SummaryPath = $summaryPath
    BaselineAnchorPath = $fullBaselineAnchorPath
    HardFailureCount = $hardFailures.Count
    SoftFlagCount = $softFlags.Count
    OverallStatus = $overallStatus
    RuntimeMetricsPath = $metricsPath
    SonarQualityGate = $sonarStatus
}

$result

if ($hardFailures.Count -gt 0) {
    throw "Thesis suite failed hard gates. See summary: $summaryPath"
}
