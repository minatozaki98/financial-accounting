$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "../../.."))
$manifestPath = Join-Path $repositoryRoot 'docs/appendix/dashboard-capture-manifest.json'
$expectedFiles = @(
    'sonarqube/sonarqube-baseline-overview.png',
    'sonarqube/sonarqube-baseline-issues.png',
    'sonarqube/sonarqube-remediation-overview.png',
    'sonarqube/sonarqube-remediation-issues.png',
    'zap/zap-baseline-before-summary.png',
    'zap/zap-baseline-after-summary.png',
    'zap/zap-api-before-summary.png',
    'zap/zap-api-after-summary.png',
    'jmeter/jmeter-baseline-p50-dashboard.png',
    'jmeter/jmeter-baseline-p100-dashboard.png',
    'jmeter/jmeter-baseline-p500-dashboard.png',
    'jmeter/jmeter-baseline-soak-dashboard.png',
    'jmeter/jmeter-baseline-spike-dashboard.png',
    'jmeter/jmeter-remediation-p50-dashboard.png',
    'jmeter/jmeter-remediation-p100-dashboard.png',
    'jmeter/jmeter-remediation-p500-dashboard.png',
    'jmeter/jmeter-remediation-soak-dashboard.png',
    'jmeter/jmeter-remediation-spike-dashboard.png'
)

Describe "Dashboard capture manifest" {
    It "declares all 18 required dashboard filenames" {
        $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json

        @($manifest.requiredCaptures).Count | Should Be 18
        foreach ($expected in $expectedFiles) {
            (@($manifest.requiredCaptures) -contains $expected) | Should Be $true
        }
    }

    It "keeps captures in a versioned array" {
        $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json

        $manifest.schemaVersion | Should Be 1
        $manifest.captures.GetType().Name | Should Match 'Object\[\]'
    }

    It "requires complete, hash-matched evidence at the final dashboard gate" {
        if ($env:THESIS_REQUIRE_COMPLETE_DASHBOARDS -ne '1') { return }
        $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
        $capturePaths = @($manifest.captures | ForEach-Object { $_.imagePath })

        foreach ($expected in $expectedFiles) {
            ($capturePaths -contains $expected) | Should Be $true
        }
        foreach ($capture in $manifest.captures) {
            $capture.commit | Should Match '^[0-9a-f]{40}$'
            @('historical', 'rendered-historical', 'fresh-reproduction') -contains $capture.evidenceClassification | Should Be $true
            $capture.width | Should BeGreaterThan 0
            $capture.height | Should BeGreaterThan 0
            $image = Join-Path $repositoryRoot ("docs/appendix/dashboards/" + $capture.imagePath)
            $source = Join-Path $repositoryRoot $capture.sourceArtifact
            (Test-Path -LiteralPath $image) | Should Be $true
            (Test-Path -LiteralPath $source) | Should Be $true
            (Get-FileHash -Algorithm SHA256 -LiteralPath $image).Hash.ToLowerInvariant() | Should Be $capture.sha256
        }
    }
}
