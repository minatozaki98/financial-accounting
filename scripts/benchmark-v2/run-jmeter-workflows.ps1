param(
    [string]$CandidateRoot = ".",
    [ValidateSet("all", "period-close", "journal-import", "reconciliation")]
    [string]$Profile = "all",
    [string]$OutputDir = "Document/experiments/gpt-5.4-vs-gpt-5.5-v2/baseline/jmeter",
    [string]$BaseUrl = "http://localhost:5296",
    [string]$SqlServer = "localhost",
    [string]$DatabaseName = "FinancialBenchmarkV2",
    [string]$BackupPath = "",
    [string]$ExpectedSha256 = "",
    [string]$Image = "justb4/jmeter:5.5",
    [string]$Username = "admin",
    [string]$Password = "Admin@123",
    [string]$ApiVersion = "1.0",
    [int]$Users = 10,
    [int]$RampUp = 60,
    [int]$Loops = 10,
    [int]$Repetitions = 1,
    [int]$JournalRows = 20,
    [string]$OutputTag = "",
    [switch]$SkipRestore,
    [switch]$SkipBuild,
    [switch]$SkipApiStart
)

$ErrorActionPreference = "Stop"

function Resolve-FullPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }

    return [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $Path))
}

function ConvertTo-SafeRunTag {
    param([Parameter(Mandatory = $true)][string]$Value)

    $safe = $Value -replace '[^A-Za-z0-9._-]', '-'
    if ($safe.Length -gt 48) {
        $safe = $safe.Substring(0, 48)
    }

    return $safe.Trim("-")
}

function ConvertTo-SqlLiteral {
    param([AllowNull()][string]$Value)
    if ($null -eq $Value) {
        return "NULL"
    }

    return "N'$($Value.Replace("'", "''"))'"
}

function Invoke-Checked {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [string]$WorkingDirectory = ""
    )

    if ([string]::IsNullOrWhiteSpace($WorkingDirectory)) {
        & $FilePath @Arguments
    }
    else {
        & $FilePath @Arguments
    }

    if ($LASTEXITCODE -ne 0) {
        throw "Command failed with exit code ${LASTEXITCODE}: $FilePath $($Arguments -join ' ')"
    }
}

function Invoke-SqlText {
    param(
        [Parameter(Mandatory = $true)][string]$Query,
        [string]$Database = $DatabaseName
    )

    $output = & sqlcmd -S $SqlServer -E -d $Database -b -h -1 -w 65535 -y 4000 -Y 4000 -Q "SET NOCOUNT ON; $Query"
    if ($LASTEXITCODE -ne 0) {
        throw "sqlcmd query failed: $Query"
    }

    return (($output | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join "").Trim()
}

function Invoke-SqlJson {
    param([Parameter(Mandatory = $true)][string]$Query)

    $raw = Invoke-SqlText -Query $Query
    if ([string]::IsNullOrWhiteSpace($raw)) {
        throw "SQL query returned empty JSON."
    }

    return $raw | ConvertFrom-Json
}

function Convert-ToDockerReachableUrl {
    param([Parameter(Mandatory = $true)][string]$Url)

    $parsed = [Uri]$Url
    if ($parsed.Host -eq "localhost" -or $parsed.Host -eq "127.0.0.1") {
        return $Url -replace [Regex]::Escape($parsed.Host), "host.docker.internal"
    }

    return $Url
}

function Wait-ApiReady {
    param(
        [Parameter(Mandatory = $true)][string]$Url,
        [int]$Seconds = 90
    )

    $probeUrl = $Url
    $probeUri = [Uri]$Url
    if ($probeUri.Host -eq "localhost") {
        $probeUrl = $Url -replace [Regex]::Escape($probeUri.Host), "127.0.0.1"
    }

    $readyUrl = "$($probeUrl.TrimEnd('/'))/health/live"
    for ($attempt = 1; $attempt -le $Seconds; $attempt++) {
        try {
            $response = Invoke-WebRequest -Method GET -Uri $readyUrl -UseBasicParsing -TimeoutSec 2 -MaximumRedirection 0
            if ([int]$response.StatusCode -ge 200 -and [int]$response.StatusCode -lt 400) {
                return
            }
        }
        catch {
            $statusCode = $null
            if ($_.Exception.Response) {
                try {
                    $statusCode = [int]$_.Exception.Response.StatusCode
                }
                catch {
                    $statusCode = $null
                }
            }

            if ($null -ne $statusCode -and $statusCode -ge 200 -and $statusCode -lt 400) {
                return
            }

            Start-Sleep -Seconds 1
        }
    }

    throw "API did not become ready at $readyUrl within $Seconds seconds."
}

function Start-CandidateApi {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$Url,
        [Parameter(Mandatory = $true)][string]$LogDir
    )

    $uri = [Uri]$Url
    $listenUrl = "$($uri.Scheme)://0.0.0.0:$($uri.Port)"
    $stdout = Join-Path $LogDir "api-stdout.log"
    $stderr = Join-Path $LogDir "api-stderr.log"
    $connectionString = "Server=$SqlServer;Database=$DatabaseName;Trusted_Connection=True;TrustServerCertificate=True;Encrypt=false;"

    $oldConnection = $env:AppSettings__ConnectionStrings
    $oldEnvironment = $env:ASPNETCORE_ENVIRONMENT
    try {
        $env:AppSettings__ConnectionStrings = $connectionString
        $env:ASPNETCORE_ENVIRONMENT = "Development"
        $process = Start-Process `
            -FilePath "dotnet" `
            -ArgumentList @("run", "--project", "API\API.csproj", "-c", "Release", "--no-build", "--urls", $listenUrl) `
            -WorkingDirectory $Root `
            -RedirectStandardOutput $stdout `
            -RedirectStandardError $stderr `
            -WindowStyle Hidden `
            -PassThru
    }
    finally {
        $env:AppSettings__ConnectionStrings = $oldConnection
        $env:ASPNETCORE_ENVIRONMENT = $oldEnvironment
    }

    try {
        Wait-ApiReady -Url $Url
        return $process
    }
    catch {
        Stop-CandidateApi -Process $process
        throw
    }
}

function Stop-CandidateApi {
    param([AllowNull()][System.Diagnostics.Process]$Process)

    if ($null -eq $Process) {
        return
    }

    try {
        $current = Get-Process -Id $Process.Id -ErrorAction SilentlyContinue
        if ($null -ne $current) {
            Stop-Process -Id $Process.Id -Force
            $current.WaitForExit(10000) | Out-Null
        }
    }
    catch {
        Write-Warning "Unable to stop candidate API process $($Process.Id): $_"
    }
}

function Restore-BenchmarkDatabase {
    param([Parameter(Mandatory = $true)][string]$Root)

    if ($SkipRestore) {
        return $null
    }

    $restoreScript = Join-Path $Root "scripts\benchmark-v2\restore-benchmark-database.ps1"
    if (-not (Test-Path -LiteralPath $restoreScript)) {
        throw "Restore script not found: $restoreScript"
    }

    $args = @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", $restoreScript,
        "-SqlServer", $SqlServer,
        "-TargetDatabase", $DatabaseName,
        "-Force"
    )
    if (-not [string]::IsNullOrWhiteSpace($BackupPath)) {
        $args += @("-BackupPath", $BackupPath)
    }
    if (-not [string]::IsNullOrWhiteSpace($ExpectedSha256)) {
        $args += @("-ExpectedSha256", $ExpectedSha256)
    }

    $restoreOutput = & powershell @args
    if ($LASTEXITCODE -ne 0) {
        throw "Database restore failed with exit code $LASTEXITCODE."
    }

    return (($restoreOutput | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join "`n")
}

function Get-JournalImportProperties {
    $query = @"
SELECT
    (SELECT TOP (1) AccountCode FROM dbo.ChartOfAccounts WHERE AccountType = N'Asset' AND IsActive = 1 ORDER BY AccountId) AS debitAccountCode,
    (SELECT TOP (1) AccountCode FROM dbo.ChartOfAccounts WHERE AccountType = N'Liability' AND IsActive = 1 ORDER BY AccountId) AS creditAccountCode
FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;
"@

    $props = Invoke-SqlJson -Query $query
    if ([string]::IsNullOrWhiteSpace([string]$props.debitAccountCode) -or
        [string]::IsNullOrWhiteSpace([string]$props.creditAccountCode)) {
        throw "Could not resolve journal-import account-code properties."
    }

    return $props
}

function Initialize-ReconciliationFixtures {
    param([Parameter(Mandatory = $true)][string]$RunTag)

    $runTagLiteral = ConvertTo-SqlLiteral -Value $RunTag
    $query = @"
DECLARE @RunTag nvarchar(80) = $runTagLiteral;
DECLARE @AdminUserId uniqueidentifier = (SELECT TOP (1) UserId FROM dbo.Users WHERE Username = N'admin' ORDER BY CreatedAt);
DECLARE @BankAccountId int = (SELECT TOP (1) AccountId FROM dbo.ChartOfAccounts WHERE AccountType = N'Asset' AND IsActive = 1 ORDER BY AccountId);
DECLARE @OffsetAccountId int = (SELECT TOP (1) AccountId FROM dbo.ChartOfAccounts WHERE AccountType = N'Liability' AND IsActive = 1 ORDER BY AccountId);
DECLARE @ExactRef nvarchar(100) = CONCAT(N'JM-RECON-EXACT-', @RunTag);
DECLARE @AmbiguousRefA nvarchar(100) = CONCAT(N'JM-RECON-AMB-A-', @RunTag);
DECLARE @AmbiguousRefB nvarchar(100) = CONCAT(N'JM-RECON-AMB-B-', @RunTag);
DECLARE @ExactDate date = CONVERT(date, '2026-06-15');
DECLARE @AmbiguousDate date = CONVERT(date, '2026-06-16');
DECLARE @ExactAmount decimal(18,2) = 321.45;
DECLARE @AmbiguousAmount decimal(18,2) = 654.32;
DECLARE @ExactEntryId bigint;
DECLARE @AmbiguousEntryIdA bigint;
DECLARE @AmbiguousEntryIdB bigint;

IF @AdminUserId IS NULL OR @BankAccountId IS NULL OR @OffsetAccountId IS NULL
    THROW 52000, 'Missing reconciliation fixture prerequisites.', 1;

INSERT INTO dbo.JournalEntries (EntryDate, Description, ReferenceNo, Status, CreatedByUserId, CreatedAt, PostedAt, ReversedAt)
VALUES (@ExactDate, CONCAT(N'JMeter exact fixture ', @RunTag), @ExactRef, N'Posted', @AdminUserId, SYSUTCDATETIME(), SYSUTCDATETIME(), NULL);
SET @ExactEntryId = CONVERT(bigint, SCOPE_IDENTITY());

INSERT INTO dbo.JournalEntryLines (JournalEntryId, AccountId, LineDescription, Debit, Credit)
VALUES
(@ExactEntryId, @BankAccountId, N'JMeter exact bank debit', @ExactAmount, 0),
(@ExactEntryId, @OffsetAccountId, N'JMeter exact offset credit', 0, @ExactAmount);

INSERT INTO dbo.JournalEntries (EntryDate, Description, ReferenceNo, Status, CreatedByUserId, CreatedAt, PostedAt, ReversedAt)
VALUES (@AmbiguousDate, CONCAT(N'JMeter ambiguous fixture A ', @RunTag), @AmbiguousRefA, N'Posted', @AdminUserId, SYSUTCDATETIME(), SYSUTCDATETIME(), NULL);
SET @AmbiguousEntryIdA = CONVERT(bigint, SCOPE_IDENTITY());

INSERT INTO dbo.JournalEntryLines (JournalEntryId, AccountId, LineDescription, Debit, Credit)
VALUES
(@AmbiguousEntryIdA, @BankAccountId, N'JMeter ambiguous bank debit A', @AmbiguousAmount, 0),
(@AmbiguousEntryIdA, @OffsetAccountId, N'JMeter ambiguous offset credit A', 0, @AmbiguousAmount);

INSERT INTO dbo.JournalEntries (EntryDate, Description, ReferenceNo, Status, CreatedByUserId, CreatedAt, PostedAt, ReversedAt)
VALUES (@AmbiguousDate, CONCAT(N'JMeter ambiguous fixture B ', @RunTag), @AmbiguousRefB, N'Posted', @AdminUserId, SYSUTCDATETIME(), SYSUTCDATETIME(), NULL);
SET @AmbiguousEntryIdB = CONVERT(bigint, SCOPE_IDENTITY());

INSERT INTO dbo.JournalEntryLines (JournalEntryId, AccountId, LineDescription, Debit, Credit)
VALUES
(@AmbiguousEntryIdB, @BankAccountId, N'JMeter ambiguous bank debit B', @AmbiguousAmount, 0),
(@AmbiguousEntryIdB, @OffsetAccountId, N'JMeter ambiguous offset credit B', 0, @AmbiguousAmount);

SELECT
    @BankAccountId AS bankAccountId,
    @ExactRef AS exactReference,
    CONVERT(nvarchar(10), @ExactDate, 126) AS exactDate,
    CONVERT(nvarchar(32), @ExactAmount) AS exactAmount,
    CONVERT(nvarchar(10), @AmbiguousDate, 126) AS ambiguousDate,
    CONVERT(nvarchar(32), @AmbiguousAmount) AS ambiguousAmount,
    @ExactEntryId AS exactEntryId,
    @AmbiguousEntryIdA AS ambiguousEntryIdA,
    @AmbiguousEntryIdB AS ambiguousEntryIdB
FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;
"@

    return Invoke-SqlJson -Query $query
}

function Get-PostconditionSummary {
    param([Parameter(Mandatory = $true)][string]$RunTag)

    $runTagLiteral = ConvertTo-SqlLiteral -Value $RunTag
    $query = @"
DECLARE @RunTag nvarchar(80) = $runTagLiteral;
DECLARE @ImportPrefix nvarchar(100) = CONCAT(N'JM-IMP-', @RunTag, N'-%');
DECLARE @InvalidPrefix nvarchar(100) = CONCAT(N'JM-BAD-', @RunTag, N'-%');
DECLARE @ReconDescriptionPattern nvarchar(120) = CONCAT(N'JMeter recon%', @RunTag, N'%');

;WITH EntryTotals AS
(
    SELECT
        je.JournalEntryId,
        je.ReferenceNo,
        CAST(SUM(jel.Debit) AS decimal(18,2)) AS DebitTotal,
        CAST(SUM(jel.Credit) AS decimal(18,2)) AS CreditTotal
    FROM dbo.JournalEntries je
    INNER JOIN dbo.JournalEntryLines jel ON jel.JournalEntryId = je.JournalEntryId
    WHERE je.ReferenceNo LIKE @ImportPrefix OR je.ReferenceNo LIKE @InvalidPrefix
    GROUP BY je.JournalEntryId, je.ReferenceNo
),
DuplicateImportReferences AS
(
    SELECT ReferenceNo
    FROM dbo.JournalEntries
    WHERE ReferenceNo LIKE @ImportPrefix
    GROUP BY ReferenceNo
    HAVING COUNT(*) > 1
),
DuplicateMatches AS
(
    SELECT bt.ReconciliationId, bt.MatchedJournalEntryId
    FROM dbo.BankTransactions bt
    WHERE bt.Description LIKE @ReconDescriptionPattern
      AND bt.MatchedJournalEntryId IS NOT NULL
    GROUP BY bt.ReconciliationId, bt.MatchedJournalEntryId
    HAVING COUNT(*) > 1
),
DuplicateFinalizeRequests AS
(
    SELECT FinalizeRequestId
    FROM dbo.BankReconciliations
    WHERE FinalizeRequestId IS NOT NULL
    GROUP BY FinalizeRequestId
    HAVING COUNT(*) > 1
)
SELECT
    (SELECT COUNT(*) FROM EntryTotals WHERE ReferenceNo LIKE @ImportPrefix AND (DebitTotal <> CreditTotal OR DebitTotal <= 0)) AS unbalancedImportedEntries,
    (SELECT COUNT(*) FROM dbo.JournalEntries WHERE ReferenceNo LIKE @InvalidPrefix) AS invalidAtomicCreatedEntries,
    (SELECT COUNT(*) FROM DuplicateImportReferences) AS duplicateImportedReferences,
    (SELECT COUNT(*) FROM dbo.AccountingPeriods WHERE PeriodId >= 203001 AND CloseRequestId IS NOT NULL) AS closedBenchmarkPeriods,
    (SELECT COUNT(*) FROM dbo.AccountingPeriods WHERE PeriodId >= 203001 AND CloseRequestId IS NOT NULL AND (IsClosed <> 1 OR ClosedAt IS NULL OR ClosedByUserId IS NULL)) AS invalidClosedPeriods,
    (SELECT COUNT(*) FROM DuplicateMatches) AS duplicateMatchesWithinReconciliation,
    (SELECT COUNT(*) FROM DuplicateFinalizeRequests) AS duplicateFinalizeRequestIds,
    (SELECT COUNT(*) FROM dbo.BankReconciliations br WHERE br.FinalizeRequestId IS NOT NULL AND br.Status <> N'Finalized') AS unfinalizedWithFinalizeRequest
FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;
"@

    $summary = Invoke-SqlJson -Query $query
    $passed = (
        [int]$summary.unbalancedImportedEntries -eq 0 -and
        [int]$summary.invalidAtomicCreatedEntries -eq 0 -and
        [int]$summary.duplicateImportedReferences -eq 0 -and
        [int]$summary.invalidClosedPeriods -eq 0 -and
        [int]$summary.duplicateMatchesWithinReconciliation -eq 0 -and
        [int]$summary.duplicateFinalizeRequestIds -eq 0 -and
        [int]$summary.unfinalizedWithFinalizeRequest -eq 0
    )

    $summary | Add-Member -NotePropertyName passed -NotePropertyValue $passed -Force
    return $summary
}

function Get-Percentile {
    param(
        [Parameter(Mandatory = $true)][double[]]$Values,
        [Parameter(Mandatory = $true)][double]$Percentile
    )

    if ($Values.Count -eq 0) {
        return 0.0
    }

    $sorted = $Values | Sort-Object
    $index = [Math]::Ceiling(($Percentile / 100.0) * $sorted.Count) - 1
    $index = [Math]::Max(0, [Math]::Min($index, $sorted.Count - 1))
    return [double]$sorted[$index]
}

function Get-CoefficientOfVariation {
    param([double[]]$Values)

    if ($Values.Count -lt 2) {
        return $null
    }

    $average = ($Values | Measure-Object -Average).Average
    if ($average -eq 0) {
        return $null
    }

    $sumSquares = 0.0
    foreach ($value in $Values) {
        $sumSquares += [Math]::Pow($value - $average, 2)
    }

    $stdDev = [Math]::Sqrt($sumSquares / ($Values.Count - 1))
    return [Math]::Round(($stdDev / $average) * 100.0, 4)
}

function Read-JMeterMetrics {
    param(
        [Parameter(Mandatory = $true)][string]$JtlPath,
        [Parameter(Mandatory = $true)][string]$ProfileName
    )

    if (-not (Test-Path -LiteralPath $JtlPath)) {
        throw "JTL file was not produced: $JtlPath"
    }

    $rows = @(Import-Csv -LiteralPath $JtlPath)
    $businessRows = @($rows | Where-Object { $_.label -like "BUSINESS *" })
    if ($businessRows.Count -eq 0) {
        throw "No BUSINESS samples were found in $JtlPath."
    }

    $metrics = foreach ($group in ($businessRows | Group-Object label)) {
        $samples = @($group.Group)
        $elapsed = @($samples | ForEach-Object { [double]$_.elapsed })
        $failed = @($samples | Where-Object { -not [bool]::Parse([string]$_.success) })
        $minStart = ($samples | ForEach-Object { [double]$_.timeStamp } | Measure-Object -Minimum).Minimum
        $maxEnd = ($samples | ForEach-Object { ([double]$_.timeStamp) + ([double]$_.elapsed) } | Measure-Object -Maximum).Maximum
        $durationSeconds = [Math]::Max(0.001, ($maxEnd - $minStart) / 1000.0)

        [pscustomobject][ordered]@{
            profile = $ProfileName
            label = $group.Name
            samples = $samples.Count
            failures = $failed.Count
            errorRatePercent = [Math]::Round(($failed.Count / [double]$samples.Count) * 100.0, 4)
            p50Ms = [Math]::Round((Get-Percentile -Values $elapsed -Percentile 50), 2)
            p95Ms = [Math]::Round((Get-Percentile -Values $elapsed -Percentile 95), 2)
            p99Ms = [Math]::Round((Get-Percentile -Values $elapsed -Percentile 99), 2)
            throughputPerSecond = [Math]::Round($samples.Count / $durationSeconds, 4)
        }
    }

    return @($metrics)
}

function Invoke-JMeterProfile {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$ProfileName,
        [Parameter(Mandatory = $true)][string]$RunLabel,
        [Parameter(Mandatory = $true)][string]$RunTag,
        [Parameter(Mandatory = $true)][string]$RunOutputDir
    )

    $testPlanPath = Join-Path $Root "Document\performance\jmeter\v2-$ProfileName.jmx"
    if (-not (Test-Path -LiteralPath $testPlanPath)) {
        throw "JMeter plan not found: $testPlanPath"
    }

    $restoreSummary = Restore-BenchmarkDatabase -Root $Root
    $profileProperties = [ordered]@{}
    if ($ProfileName -eq "journal-import") {
        $journalProps = Get-JournalImportProperties
        $profileProperties["debitAccountCode"] = [string]$journalProps.debitAccountCode
        $profileProperties["creditAccountCode"] = [string]$journalProps.creditAccountCode
        $profileProperties["journalRows"] = [string]$JournalRows
    }
    elseif ($ProfileName -eq "reconciliation") {
        $reconProps = Initialize-ReconciliationFixtures -RunTag $RunTag
        foreach ($property in $reconProps.PSObject.Properties) {
            $profileProperties[$property.Name] = [string]$property.Value
        }
    }

    New-Item -ItemType Directory -Force $RunOutputDir | Out-Null
    $apiProcess = $null
    $privatePropsDir = $null
    $loadStart = $null
    $cpuStart = 0.0
    $cpuEnd = 0.0
    $workingSetMb = 0.0
    try {
        if (-not $SkipApiStart) {
            $apiProcess = Start-CandidateApi -Root $Root -Url $BaseUrl -LogDir $RunOutputDir
        }
        else {
            Wait-ApiReady -Url $BaseUrl
        }

        $processForMetrics = if ($null -ne $apiProcess) {
            Get-Process -Id $apiProcess.Id -ErrorAction SilentlyContinue
        }
        else {
            $null
        }
        if ($null -ne $processForMetrics) {
            $cpuStart = [double]$processForMetrics.CPU
        }
        $loadStart = Get-Date

        $testDir = Split-Path -Parent $testPlanPath
        $testFile = Split-Path -Leaf $testPlanPath
        $jtlPath = Join-Path $RunOutputDir "results.jtl"
        $htmlDir = Join-Path $RunOutputDir "html"
        $dockerTestMount = "$($testDir -replace '\\','/'):/tests:ro"
        $dockerResultsMount = "$($RunOutputDir -replace '\\','/'):/results"
        $dockerBaseUrl = Convert-ToDockerReachableUrl -Url $BaseUrl
        $privatePropsDir = Join-Path ([System.IO.Path]::GetTempPath()) "financial-accounting-benchmark-v2\jmeter-private\$RunLabel"
        New-Item -ItemType Directory -Force $privatePropsDir | Out-Null
        $privatePropsPath = Join-Path $privatePropsDir "jmeter.properties"
        @(
            "username=$Username",
            "password=$Password",
            "apiVersion=$ApiVersion"
        ) | Set-Content -LiteralPath $privatePropsPath -Encoding ASCII
        $dockerPrivateMount = "$($privatePropsDir -replace '\\','/'):/private:ro"

        $dockerArgs = @(
            "run", "--rm",
            "-v", $dockerTestMount,
            "-v", $dockerResultsMount,
            "-v", $dockerPrivateMount,
            $Image,
            "-q", "/private/jmeter.properties",
            "-n",
            "-t", "/tests/$testFile",
            "-l", "/results/results.jtl",
            "-e",
            "-o", "/results/html",
            "-Jjmeter.save.saveservice.output_format=csv",
            "-Jjmeter.save.saveservice.print_field_names=true",
            "-Jjmeter.save.saveservice.response_data=false",
            "-Jjmeter.save.saveservice.samplerData=false",
            "-Jjmeter.save.saveservice.requestHeaders=false",
            "-Jjmeter.save.saveservice.responseHeaders=false",
            "-JbaseUrl=$dockerBaseUrl",
            "-Jusers=$Users",
            "-Jrampup=$RampUp",
            "-Jloops=$Loops",
            "-JrunTag=$RunTag"
        )

        foreach ($key in $profileProperties.Keys) {
            $dockerArgs += "-J$key=$($profileProperties[$key])"
        }

        docker @dockerArgs | Out-Host
        if ($LASTEXITCODE -ne 0) {
            throw "JMeter execution failed for $ProfileName/$RunLabel with exit code $LASTEXITCODE."
        }

        $loadEnd = Get-Date
        $processForMetrics = if ($null -ne $apiProcess) {
            Get-Process -Id $apiProcess.Id -ErrorAction SilentlyContinue
        }
        else {
            $null
        }
        if ($null -ne $processForMetrics) {
            $cpuEnd = [double]$processForMetrics.CPU
            $workingSetMb = [Math]::Round($processForMetrics.WorkingSet64 / 1MB, 2)
        }

        $postconditions = Get-PostconditionSummary -RunTag $RunTag
        $postconditionPath = Join-Path $RunOutputDir "postconditions.json"
        $postconditions | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $postconditionPath -Encoding UTF8

        $metrics = Read-JMeterMetrics -JtlPath $jtlPath -ProfileName $ProfileName
        $metricsPath = Join-Path $RunOutputDir "metrics.json"
        $metrics | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $metricsPath -Encoding UTF8

        $durationSeconds = [Math]::Max(0.001, ($loadEnd - $loadStart).TotalSeconds)
        $cpuPercent = if ($cpuEnd -gt 0 -and $cpuEnd -ge $cpuStart) {
            [Math]::Round((($cpuEnd - $cpuStart) / $durationSeconds / [Environment]::ProcessorCount) * 100.0, 4)
        }
        else {
            $null
        }

        return [pscustomobject][ordered]@{
            profile = $ProfileName
            runLabel = $RunLabel
            runTag = $RunTag
            users = $Users
            rampUpSeconds = $RampUp
            loops = $Loops
            journalRows = $JournalRows
            jtlPath = $jtlPath
            htmlReportPath = $htmlDir
            metricsPath = $metricsPath
            postconditionPath = $postconditionPath
            metrics = @($metrics)
            postconditions = $postconditions
            processMetrics = [pscustomobject][ordered]@{
                durationSeconds = [Math]::Round($durationSeconds, 3)
                apiCpuPercent = $cpuPercent
                apiWorkingSetMb = $workingSetMb
            }
            restoreSummary = $restoreSummary
            profileProperties = $profileProperties
        }
    }
    finally {
        if ($null -ne $privatePropsDir -and (Test-Path -LiteralPath $privatePropsDir)) {
            Remove-Item -LiteralPath $privatePropsDir -Recurse -Force
        }
        if (-not $SkipApiStart) {
            Stop-CandidateApi -Process $apiProcess
        }
    }
}

function New-AggregateSummary {
    param([object[]]$Runs)

    $aggregate = New-Object System.Collections.Generic.List[object]
    foreach ($profileGroup in ($Runs | Group-Object profile)) {
        $allMetrics = @($profileGroup.Group | ForEach-Object { $_.metrics })
        foreach ($labelGroup in ($allMetrics | Group-Object label)) {
            $p95Values = @($labelGroup.Group | ForEach-Object { [double]$_.p95Ms })
            $throughputValues = @($labelGroup.Group | ForEach-Object { [double]$_.throughputPerSecond })
            $errorValues = @($labelGroup.Group | ForEach-Object { [double]$_.errorRatePercent })
            $aggregate.Add([pscustomobject][ordered]@{
                profile = $profileGroup.Name
                label = $labelGroup.Name
                repetitions = $labelGroup.Group.Count
                medianP95Ms = [Math]::Round((Get-Percentile -Values $p95Values -Percentile 50), 2)
                medianThroughputPerSecond = [Math]::Round((Get-Percentile -Values $throughputValues -Percentile 50), 4)
                maxErrorRatePercent = [Math]::Round(($errorValues | Measure-Object -Maximum).Maximum, 4)
                p95CoefficientOfVariationPercent = Get-CoefficientOfVariation -Values $p95Values
                throughputCoefficientOfVariationPercent = Get-CoefficientOfVariation -Values $throughputValues
            })
        }
    }

    return @($aggregate.ToArray())
}

$candidateRootFull = Resolve-FullPath -Path $CandidateRoot
$outputDirFull = Resolve-FullPath -Path $OutputDir
if (-not (Test-Path -LiteralPath (Join-Path $candidateRootFull "API\API.csproj"))) {
    throw "CandidateRoot does not contain API/API.csproj: $candidateRootFull"
}

if (-not $SkipBuild) {
    dotnet build (Join-Path $candidateRootFull "API\API.csproj") -c Release --nologo
    if ($LASTEXITCODE -ne 0) {
        throw "Release build failed for candidate root: $candidateRootFull"
    }
}

$profiles = if ($Profile -eq "all") {
    @("period-close", "journal-import", "reconciliation")
}
else {
    @($Profile)
}

New-Item -ItemType Directory -Force $outputDirFull | Out-Null
$runs = New-Object System.Collections.Generic.List[object]
$tagBase = if ([string]::IsNullOrWhiteSpace($OutputTag)) {
    "jmeter-v2-{0}" -f (Get-Date -Format "yyyyMMddHHmmss")
}
else {
    $OutputTag
}

foreach ($repetition in 1..$Repetitions) {
    foreach ($profileName in $profiles) {
        $runLabel = ConvertTo-SafeRunTag -Value "$tagBase-$profileName-r$repetition-u$Users"
        $runTag = $runLabel
        $runOutputDir = Join-Path $outputDirFull "raw\$runLabel"
        Write-Host "Running JMeter profile=$profileName repetition=$repetition users=$Users rampUp=$RampUp loops=$Loops output=$runOutputDir"
        $runs.Add((Invoke-JMeterProfile `
            -Root $candidateRootFull `
            -ProfileName $profileName `
            -RunLabel $runLabel `
            -RunTag $runTag `
            -RunOutputDir $runOutputDir))
    }
}

$runsArray = @($runs.ToArray())
$aggregate = New-AggregateSummary -Runs $runsArray
$allSamplesSuccessful = -not [bool]($runsArray | Where-Object {
    [bool]($_.metrics | Where-Object { [double]$_.errorRatePercent -gt 0 })
})
$allPostconditionsPassed = -not [bool]($runsArray | Where-Object { -not [bool]$_.postconditions.passed })
$cvValues = @($aggregate | ForEach-Object {
    $_.p95CoefficientOfVariationPercent
    $_.throughputCoefficientOfVariationPercent
} | Where-Object { $null -ne $_ })
$cvWithinFifteen = if ($cvValues.Count -eq 0) {
    $null
}
else {
    -not [bool]($cvValues | Where-Object { [double]$_ -gt 15.0 })
}

$summary = [pscustomobject][ordered]@{
    candidateRoot = $candidateRootFull
    outputDir = $outputDirFull
    baseUrl = $BaseUrl
    sqlServer = $SqlServer
    databaseName = $DatabaseName
    image = $Image
    users = $Users
    rampUpSeconds = $RampUp
    loops = $Loops
    repetitions = $Repetitions
    journalRows = $JournalRows
    profiles = @($profiles)
    runs = $runsArray
    aggregate = @($aggregate)
    validityGate = [pscustomobject][ordered]@{
        allBusinessSamplesSuccessful = $allSamplesSuccessful
        allPostconditionsPassed = $allPostconditionsPassed
        coefficientOfVariationWithin15Percent = $cvWithinFifteen
    }
    capturedAtUtc = (Get-Date).ToUniversalTime().ToString("o")
}

$summaryPath = Join-Path $outputDirFull "workflow-summary.json"
$summary | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $summaryPath -Encoding UTF8
$summary | ConvertTo-Json -Depth 20
