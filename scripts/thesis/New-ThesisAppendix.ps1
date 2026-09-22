[CmdletBinding()]
param(
    [string]$EvidenceManifest = 'docs/appendix/thesis-evidence-manifest.json',
    [string]$DashboardManifest = 'docs/appendix/dashboard-capture-manifest.json',
    [string]$OutputPath = 'docs/appendix/thesis-appendix-source-code-and-results.md'
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Thesis.Common.psm1') -Force
$repositoryRoot = Get-ThesisRepositoryRoot -StartPath $PSScriptRoot

function Resolve-RepositoryPath {
    param([string]$Path)
    if ([System.IO.Path]::IsPathRooted($Path)) { return [System.IO.Path]::GetFullPath($Path) }
    return [System.IO.Path]::GetFullPath((Join-Path $repositoryRoot $Path))
}

function Escape-MarkdownCell {
    param([AllowNull()][string]$Text)
    if ($null -eq $Text) { return '' }
    return ($Text -replace '\|', '\|' -replace "`r?`n", '<br>')
}

function Get-LatestRun {
    param([string]$Pattern)
    $runDirectory = Join-Path $repositoryRoot 'docs/appendix/verification-runs'
    $file = Get-ChildItem -Path $runDirectory -Filter $Pattern -File -Recurse -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
    if (-not $file) { return $null }
    return Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json
}

$evidencePath = Resolve-RepositoryPath $EvidenceManifest
$dashboardPath = Resolve-RepositoryPath $DashboardManifest
$outputFullPath = Resolve-RepositoryPath $OutputPath
$evidence = Get-Content -LiteralPath $evidencePath -Raw | ConvertFrom-Json
$dashboards = Get-Content -LiteralPath $dashboardPath -Raw | ConvertFrom-Json

$fastRun = Get-LatestRun 'verification-fast-*.json'
$databaseRun = Get-LatestRun 'database-initialization.json'
$demoRun = Get-LatestRun 'demo-live.json'
$researchRuns = @{}
foreach ($role in @('baseline','sonarqube-remediation','zap-remediation','jmeter-remediation')) {
    $researchRuns[$role] = Get-LatestRun "research-$role-*.json"
}

function Get-FreshClaimStatus {
    param($Claim)
    switch ($Claim.claimId) {
        'deterministic-data' { if ($databaseRun) { return $databaseRun.Status }; return 'Not yet reproduced' }
        'automated-regression' { if ($fastRun) { return $fastRun.Status }; return 'Not yet reproduced' }
        'working-application' { if ($demoRun) { return $demoRun.Status }; return 'Not yet reproduced' }
        'sonarqube-primary' {
            if ($researchRuns['baseline'] -and $researchRuns['sonarqube-remediation']) {
                return "$($researchRuns['baseline'].Status) / $($researchRuns['sonarqube-remediation'].Status)"
            }
            return 'Not yet reproduced'
        }
        'zap-primary' {
            if ($researchRuns['baseline'] -and $researchRuns['zap-remediation']) {
                return "$($researchRuns['baseline'].Status) / $($researchRuns['zap-remediation'].Status)"
            }
            return 'Not yet reproduced'
        }
        'jmeter-primary' {
            if ($researchRuns['baseline'] -and $researchRuns['jmeter-remediation']) {
                return "$($researchRuns['baseline'].Status) / $($researchRuns['jmeter-remediation'].Status)"
            }
            return 'Not yet reproduced'
        }
        default { return 'Not yet reproduced' }
    }
}

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add('# Thesis Appendix Source: Code, Tools, Dashboards, and Results')
$lines.Add('')
$lines.Add('This Markdown file is the controlled source for later insertion into the thesis DOCX. It does not modify the current paper. Historical measurements and fresh reproduction results are deliberately separated.')
$lines.Add('')
$lines.Add('## Appendix A - Repository and Environment')
$lines.Add('')
$lines.Add('- Repository: `https://github.com/minatozaki98/financial-accounting`')
$lines.Add('- Canonical branch: `codex/thesis-reproducibility-v1`')
$lines.Add(('- Thesis model identity: `{0}`' -f $evidence.thesisModel))
$lines.Add('- Current paper source: `Document/outputs/final-report-gpt55-comparison.docx`')
$lines.Add('- Required platform: Windows, PowerShell, .NET, Node.js/npm, local SQL Server; Docker for the full research-tool gate')
$lines.Add('')
$lines.Add('Quick start:')
$lines.Add('')
$lines.Add('```powershell')
$lines.Add('./scripts/thesis/Test-ThesisEnvironment.ps1 -Mode Fast')
$lines.Add('./scripts/thesis/Initialize-ThesisDatabase.ps1')
$lines.Add('./scripts/thesis/Invoke-ThesisVerification.ps1 -Mode Fast')
$lines.Add('./scripts/thesis/Invoke-ThesisDemo.ps1 -KeepRunning')
$lines.Add('```')
$lines.Add('')

$lines.Add('## Appendix B - Branch and Commit Provenance')
$lines.Add('')
$lines.Add('| Evidence role | Reference | Exact commit |')
$lines.Add('|---|---|---|')
foreach ($ref in $evidence.evidenceRefs) {
    $detail = if ($ref.testedCodeCommit) { "$($ref.commit) (tested code: $($ref.testedCodeCommit))" } else { $ref.commit }
    $lines.Add(('| {0} | `{1}` | `{2}` |' -f (Escape-MarkdownCell $ref.role), $ref.ref, $detail))
}
$lines.Add('')

$lines.Add('## Appendix C - Selected Source-Code Evidence')
$lines.Add('')
foreach ($claim in $evidence.claims) {
    $lines.Add("### $($claim.paperLocation): $($claim.claimId)")
    $lines.Add('')
    $lines.Add("Historical result: $($claim.historicalResult)")
    $lines.Add('')
    $lines.Add('Source files:')
    foreach ($source in $claim.sourceFiles) { $lines.Add(('- [`{0}`](../../{0})' -f $source)) }
    $lines.Add('')
    $lines.Add('Historical artifacts:')
    foreach ($artifact in $claim.historicalArtifacts) { $lines.Add(('- [`{0}`](../../{0})' -f $artifact)) }
    $lines.Add('')
}

$lines.Add('## Appendix D - Reproduction Commands and Profiles')
$lines.Add('')
$lines.Add('```powershell')
$lines.Add('# SonarQube (use a secure process-local SONAR_TOKEN)')
$lines.Add('./scripts/phase4/run-sonarqube-scan.ps1 -SonarToken $env:SONAR_TOKEN -ProjectKey <role-specific-key> -SolutionPath API/API.csproj')
$lines.Add('# OWASP ZAP baseline and authenticated API scans')
$lines.Add('./scripts/phase4/run-zap-baseline.ps1 -TargetUrl http://localhost:5296/health/live -OutputPrefix <run-id>')
$lines.Add('./scripts/phase4/run-zap-api.ps1 -OpenApiUrl http://localhost:5296/swagger/v1/swagger.json -BaseUrl http://localhost:5296 -Username admin -Password <process-local-demo-password> -OutputPrefix <run-id>')
$lines.Add('# JMeter p50, p100, p500, soak, and spike')
$lines.Add('./scripts/phase4/run-jmeter-thesis-matrix.ps1 -BaseUrl http://localhost:5296 -Username admin -Password <process-local-demo-password> -PeriodId 202601 -AccountId 1')
$lines.Add('```')
$lines.Add('')

$lines.Add('## Appendix E - Result Traceability')
$lines.Add('')
$lines.Add('| Claim | Paper location | Historical result | Fresh reproduction result |')
$lines.Add('|---|---|---|---|')
foreach ($claim in $evidence.claims) {
    $lines.Add("| $(Escape-MarkdownCell $claim.claimId) | $(Escape-MarkdownCell $claim.paperLocation) | $(Escape-MarkdownCell $claim.historicalResult) | $(Escape-MarkdownCell (Get-FreshClaimStatus $claim)) |")
}
$lines.Add('')

$lines.Add('## Appendix F - Research-Tool Dashboards and Results')
$lines.Add('')
$toolHeadings = [ordered]@{
    sonarqube = 'SonarQube Dashboards'
    zap = 'OWASP ZAP Dashboards'
    jmeter = 'Apache JMeter Dashboards'
}
foreach ($tool in $toolHeadings.Keys) {
    $lines.Add("### $($toolHeadings[$tool])")
    $lines.Add('')
    $required = @($dashboards.requiredCaptures | Where-Object { $_ -like "$tool/*" })
    foreach ($requiredPath in $required) {
        $capture = $dashboards.captures | Where-Object { $_.imagePath -eq $requiredPath } | Select-Object -First 1
        if ($capture) {
            $shortCommit = $capture.commit.Substring(0, 8)
            $lines.Add("#### $($capture.view)")
            $lines.Add('')
            $lines.Add("![Dashboard: $($capture.view)](dashboards/$($capture.imagePath))")
            $lines.Add('')
            $lines.Add(('Classification: `{0}`; role: `{1}`; branch: `{2}`; commit: `{3}`; run: `{4}`; tool version: `{5}`; source: [`{6}`](../../{6}).' -f $capture.evidenceClassification, $capture.evidenceRole, $capture.branch, $shortCommit, $capture.runId, $capture.toolVersion, $capture.sourceArtifact))
        }
        else {
            $lines.Add(('- `{0}`: **Not yet reproduced**; required before the final DOCX appendix update.' -f $requiredPath))
        }
        $lines.Add('')
    }
}

$lines.Add('## Appendix G - Working Application Demonstration')
$lines.Add('')
$lines.Add("- API live and ready endpoints: $(if ($demoRun) { "$($demoRun.Health.Live) / $($demoRun.Health.Ready)" } else { 'Not yet reproduced' })")
$lines.Add("- Frontend smoke result: $(if ($demoRun) { $demoRun.Smoke.WebRoot } else { 'Not yet reproduced' })")
$lines.Add('- Demonstrated areas: login, role-aware navigation, accounts, journal lines, periods, reports, audit logs, user administration, and research evidence.')
$lines.Add('- Demo credentials are local-only and intentionally omitted from this appendix source.')
$lines.Add('')

$lines.Add('## Appendix H - Known Limitations')
$lines.Add('')
$lines.Add('- The current paper evaluates one ASP.NET Core financial-accounting API and attributes remediation evidence to GPT-5.4.')
$lines.Add('- GPT-5.5 and new-API v2 work is supplemental and is not current-paper evidence.')
$lines.Add('- Fresh SonarQube, ZAP, and JMeter values can differ because of tool versions, host load, database state, and runtime conditions.')
$lines.Add('- The current local database exceeds the paper minimum dataset, so performance reruns must record their actual counts or use an isolated clean local database.')
$lines.Add('- Mixed-workload soak/spike drift remains a documented limitation.')
$lines.Add('- A dashboard screenshot is accepted only when its manifest links it to the same run and machine-readable source artifact.')

$parent = Split-Path -Parent $outputFullPath
if (-not (Test-Path -LiteralPath $parent)) { $null = New-Item -ItemType Directory -Path $parent -Force }
[System.IO.File]::WriteAllLines($outputFullPath, $lines, (New-Object System.Text.UTF8Encoding($false)))
return $outputFullPath
