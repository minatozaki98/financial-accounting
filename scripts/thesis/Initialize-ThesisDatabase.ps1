[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$ConnectionString,
    [switch]$AllowNonLocalDatabase,
    [switch]$SkipSeed,
    [int]$PeriodId = 202601,
    [int]$AccountCount = 120,
    [int]$JournalEntryCount = 30000,
    [int]$MinimumPostedEntries = 5000,
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Thesis.Common.psm1') -Force
$repositoryRoot = Get-ThesisRepositoryRoot -StartPath $PSScriptRoot

if ([string]::IsNullOrWhiteSpace($ConnectionString)) {
    $settingsPath = Join-Path $repositoryRoot 'API/appsettings.json'
    $settings = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
    $ConnectionString = [string]$settings.AppSettings.ConnectionStrings
}
if ([string]::IsNullOrWhiteSpace($ConnectionString)) {
    throw 'A connection string is required.'
}
if (-not (Test-LocalSqlTarget $ConnectionString) -and -not $AllowNonLocalDatabase) {
    throw 'Refusing non-local SQL target without -AllowNonLocalDatabase.'
}

try {
    $builder = New-Object System.Data.SqlClient.SqlConnectionStringBuilder $ConnectionString
}
catch {
    throw 'The connection string is invalid.'
}

$server = [string]$builder.DataSource
$database = [string]$builder.InitialCatalog
if ([string]::IsNullOrWhiteSpace($database)) { $database = 'Financial' }
$runId = Get-Date -Format 'yyyyMMdd-HHmmss'
$schemaPath = Join-Path $repositoryRoot 'Document/sql/financial_accounting_schema.sql'
$seedScript = Join-Path $repositoryRoot 'scripts/phase4/seed-test-data.ps1'
foreach ($requiredPath in @($schemaPath, $seedScript)) {
    if (-not (Test-Path -LiteralPath $requiredPath)) { throw "Required database file is missing: $requiredPath" }
}

$targetLabel = "$server/$database"
if (-not $PSCmdlet.ShouldProcess($targetLabel, 'Apply thesis schema and deterministic seed data')) {
    $whatIfResult = [pscustomobject]@{
        SchemaVersion = 1
        RunId = $runId
        Status = 'WHATIF'
        Server = $server
        Database = $database
        SchemaApplied = $false
        SeedSummary = $null
    }
    if ($OutputPath) { $null = Write-ThesisJson -InputObject $whatIfResult -Path $OutputPath }
    return $whatIfResult
}

$sqlcmd = Get-Command sqlcmd -ErrorAction SilentlyContinue
if (-not $sqlcmd) { throw 'sqlcmd is required to initialize the thesis database.' }
if (-not $builder.IntegratedSecurity) {
    throw 'Database initialization supports integrated security only so credentials are not exposed to child processes.'
}

$schemaResult = Invoke-ThesisCommand -FilePath $sqlcmd.Source -ArgumentList @('-S', $server, '-E', '-C', '-b', '-i', $schemaPath) -WorkingDirectory $repositoryRoot
if ($schemaResult.ExitCode -ne 0) {
    throw "Schema application failed: $($schemaResult.Output -join ' ')"
}

$seedSummary = $null
if (-not $SkipSeed) {
    $seedParameters = @{
        ConnectionString = $ConnectionString
        PeriodId = $PeriodId
        AccountCount = $AccountCount
        JournalEntryCount = $JournalEntryCount
        MinimumPostedEntries = $MinimumPostedEntries
    }
    $seedOutput = @(& $seedScript @seedParameters 6>&1)
    $seedSummary = $seedOutput |
        Where-Object { $_ -and $_.PSObject.Properties['DefaultAccountId'] } |
        Select-Object -Last 1
    if (-not $seedSummary) { throw 'The seed script did not return its summary object.' }
}

$connection = New-Object System.Data.SqlClient.SqlConnection $ConnectionString
$connection.Open()
try {
    $command = $connection.CreateCommand()
    $command.CommandText = @"
SELECT
    (SELECT COUNT(*) FROM dbo.Roles WHERE RoleName IN (N'Admin', N'FinanceManager', N'User', N'Auditor')) AS RoleCount,
    (SELECT COUNT(*) FROM dbo.Users WHERE Username IN (N'admin', N'finance-manager', N'normal-user', N'auditor-user')) AS DemoUserCount,
    (SELECT COUNT(*) FROM dbo.ChartOfAccounts) AS AccountCount,
    (SELECT COUNT(*) FROM dbo.JournalEntries) AS JournalEntryCount,
    (SELECT COUNT(*) FROM dbo.JournalEntries WHERE Status = N'Posted') AS PostedEntryCount;
"@
    $reader = $command.ExecuteReader()
    if (-not $reader.Read()) { throw 'Database verification query returned no rows.' }
    $verified = [pscustomobject]@{
        RoleCount = [int]$reader['RoleCount']
        DemoUserCount = [int]$reader['DemoUserCount']
        AccountCount = [int]$reader['AccountCount']
        JournalEntryCount = [int]$reader['JournalEntryCount']
        PostedEntryCount = [int]$reader['PostedEntryCount']
    }
    $reader.Close()
}
finally {
    $connection.Close()
    $connection.Dispose()
}

$result = [pscustomobject]@{
    SchemaVersion = 1
    RunId = $runId
    Status = 'PASS'
    Server = $server
    Database = $database
    SchemaApplied = $true
    SeedSummary = if ($seedSummary) {
        [pscustomobject]@{
            PeriodId = [int]$seedSummary.PeriodId
            AccountCount = [int]$seedSummary.AccountCount
            TotalJournalEntries = [int]$seedSummary.TotalJournalEntries
            PostedJournalEntries = [int]$seedSummary.PostedJournalEntries
            DefaultAccountId = [int]$seedSummary.DefaultAccountId
        }
    } else { $null }
    Verification = $verified
}
if ($OutputPath) { $null = Write-ThesisJson -InputObject $result -Path $OutputPath }
return $result
