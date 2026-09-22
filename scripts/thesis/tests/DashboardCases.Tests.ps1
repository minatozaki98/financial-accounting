$scriptPath = Join-Path $PSScriptRoot '../New-DashboardCaptureCases.ps1'
$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))

Describe "New-DashboardCaptureCases" {
    It "generates reusable cases for all required dashboards" {
        $output = Join-Path $TestDrive 'cases.json'
        & $scriptPath -OutputPath $output -JMeterDashboardBaseUrl 'http://127.0.0.1:8765'
        $cases = Get-Content $output -Raw | ConvertFrom-Json

        @($cases).Count | Should Be 18
        @($cases | Where-Object { $_.tool -eq 'jmeter' -and $_.captureSelector -ne '#statisticsTable' }).Count | Should Be 0
        @($cases | ForEach-Object { $_.metrics } | Where-Object { [string]::IsNullOrWhiteSpace($_.pagePattern) }).Count | Should Be 0
    }
}
