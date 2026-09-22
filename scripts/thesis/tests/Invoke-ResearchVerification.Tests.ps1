$scriptPath = Join-Path $PSScriptRoot "../Invoke-ResearchVerification.ps1"
$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "../../.."))
$currentCommit = (git -C $repositoryRoot rev-parse HEAD).Trim()

Describe "Invoke-ResearchVerification" {
    It "rejects an exact-ref mismatch" {
        $message = $null
        try {
            & $scriptPath -Role baseline -WorkingDirectory $repositoryRoot -ExpectedCommit ('0' * 40) -DryRun
            throw 'Expected an exact-ref rejection.'
        }
        catch { $message = $_.Exception.Message }

        $message | Should Match "Expected $([regex]::Escape('0' * 40))"
        $message | Should Match $currentCommit
    }

    It "uses distinct SonarQube project keys for baseline and remediation" {
        $baseline = & $scriptPath -Role baseline -WorkingDirectory $repositoryRoot -ExpectedCommit $currentCommit -DryRun
        $remediation = & $scriptPath -Role sonarqube-remediation -WorkingDirectory $repositoryRoot -ExpectedCommit $currentCommit -DryRun

        $baseline.Sonar.ProjectKey | Should Be 'financial-accounting-thesis-baseline-v01'
        $remediation.Sonar.ProjectKey | Should Be 'financial-accounting-thesis-sonarqube-v1'
    }

    It "skips SonarQube without a token instead of reporting a pass" {
        $oldToken = $env:SONAR_TOKEN
        try {
            Remove-Item Env:SONAR_TOKEN -ErrorAction SilentlyContinue
            $result = & $scriptPath -Role sonarqube-remediation -WorkingDirectory $repositoryRoot -ExpectedCommit $currentCommit -OutputDirectory $TestDrive

            $result.Status | Should Be 'SKIPPED'
            $result.Sonar.Status | Should Be 'SKIPPED'
        }
        finally {
            if ($null -ne $oldToken) { $env:SONAR_TOKEN = $oldToken }
        }
    }

    It "returns ENVIRONMENT_BLOCKED when Docker is unavailable" {
        $dockerCommand = Get-Command docker -ErrorAction SilentlyContinue
        $oldPath = $env:PATH
        try {
            if ($dockerCommand) {
                $dockerDirectory = Split-Path -Parent $dockerCommand.Source
                $env:PATH = (($oldPath -split ';') | Where-Object { $_ -and $_ -ne $dockerDirectory }) -join ';'
            }
            $result = & $scriptPath -Role zap-remediation -WorkingDirectory $repositoryRoot -ExpectedCommit $currentCommit -OutputDirectory $TestDrive

            $result.Status | Should Be 'ENVIRONMENT_BLOCKED'
        }
        finally { $env:PATH = $oldPath }
    }

    It "propagates a phase-4 tool failure" {
        $fakeBin = Join-Path $TestDrive 'bin'
        $phase4 = Join-Path $TestDrive 'phase4'
        $null = New-Item -ItemType Directory -Path $fakeBin,$phase4 -Force
        Set-Content -LiteralPath (Join-Path $fakeBin 'docker.cmd') -Value '@echo 1.0.0'
        Set-Content -LiteralPath (Join-Path $phase4 'run-zap-baseline.ps1') -Value "throw 'synthetic tool failure'"
        Set-Content -LiteralPath (Join-Path $phase4 'run-zap-api.ps1') -Value "[pscustomobject]@{ JsonReportPath='unused.json' }"
        $oldPath = $env:PATH
        try {
            $env:PATH = "$fakeBin;$oldPath"
            $result = & $scriptPath -Role zap-remediation -WorkingDirectory $repositoryRoot -ExpectedCommit $currentCommit -Phase4Root $phase4 -OutputDirectory $TestDrive

            $result.Status | Should Be 'FAIL'
            $result.Failure | Should Match 'synthetic tool failure'
        }
        finally { $env:PATH = $oldPath }
    }

    It "labels a dry run as fresh reproduction evidence" {
        $result = & $scriptPath -Role jmeter-remediation -WorkingDirectory $repositoryRoot -ExpectedCommit $currentCommit -DryRun

        $result.Status | Should Be 'DRY_RUN'
        $result.EvidenceClassification | Should Be 'fresh-reproduction'
    }

    It "exposes Sonar project and evidence classification parameters on the full suite" {
        $command = Get-Command (Join-Path $repositoryRoot 'scripts/phase4/run-thesis-suite.ps1')

        ($command.Parameters.Keys -contains 'SonarProjectKey') | Should Be $true
        ($command.Parameters.Keys -contains 'EvidenceClassification') | Should Be $true
    }

    It "does not commit a default demo password in the research wrapper" {
        $tokens = $null
        $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$tokens, [ref]$errors)
        $parameter = $ast.ParamBlock.Parameters | Where-Object { $_.Name.VariablePath.UserPath -eq 'Password' } | Select-Object -First 1

        [string]$parameter.DefaultValue.SafeGetValue() | Should Be ''
    }
}
