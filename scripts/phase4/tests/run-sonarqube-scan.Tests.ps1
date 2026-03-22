Describe "run-sonarqube-scan.ps1" {
    $scriptPath = Join-Path $PSScriptRoot "..\run-sonarqube-scan.ps1"
    $scriptContent = Get-Content -Path $scriptPath -Raw

    It "disables scanAll to avoid repo-wide multi-language noise" {
        $scriptContent | Should Match "sonar\.scanner\.scanAll=false"
    }

    It "configures Sonar to import .NET coverage reports" {
        $scriptContent | Should Match "sonar\.cs\.vscoveragexml\.reportsPaths="
    }

    It "runs dotnet-coverage to collect unit and integration coverage" {
        $scriptContent | Should Match "dotnet-coverage"
        $scriptContent | Should Match "FinancialAccounting\.UnitTests\.csproj"
        $scriptContent | Should Match "FinancialAccounting\.IntegrationTests\.csproj"
    }
}
