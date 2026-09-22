$scriptPath = Join-Path $PSScriptRoot "../New-ThesisAppendix.ps1"
$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "../../.."))
$evidence = Join-Path $repositoryRoot 'docs/appendix/thesis-evidence-manifest.json'
$dashboards = Join-Path $repositoryRoot 'docs/appendix/dashboard-capture-manifest.json'

Describe "New-ThesisAppendix" {
    It "renders Appendix A through H and all three tool dashboard sections" {
        $output = Join-Path $TestDrive 'appendix.md'
        & $scriptPath -EvidenceManifest $evidence -DashboardManifest $dashboards -OutputPath $output
        $text = Get-Content $output -Raw

        foreach ($letter in 'A','B','C','D','E','F','G','H') { $text | Should Match "Appendix $letter" }
        $text | Should Match 'SonarQube Dashboards'
        $text | Should Match 'OWASP ZAP Dashboards'
        $text | Should Match 'Apache JMeter Dashboards'
    }

    It "keeps historical and fresh results in separately labeled columns" {
        $output = Join-Path $TestDrive 'appendix.md'
        & $scriptPath -EvidenceManifest $evidence -DashboardManifest $dashboards -OutputPath $output

        (Get-Content $output -Raw) | Should Match 'Historical result[^\r\n]*Fresh reproduction result'
    }

    It "links every currently captured dashboard and labels missing required captures" {
        $output = Join-Path $TestDrive 'appendix.md'
        & $scriptPath -EvidenceManifest $evidence -DashboardManifest $dashboards -OutputPath $output
        $text = Get-Content $output -Raw
        $manifest = Get-Content $dashboards -Raw | ConvertFrom-Json

        foreach ($capture in $manifest.captures) { $text | Should Match ([regex]::Escape($capture.imagePath)) }
        if (@($manifest.captures).Count -lt @($manifest.requiredCaptures).Count) {
            $text | Should Match 'Not yet reproduced'
        }
        else {
            $text | Should Not Match 'required before the final DOCX appendix update'
        }
    }

    It "is deterministic and contains no local user-profile path" {
        $first = Join-Path $TestDrive 'first.md'
        $second = Join-Path $TestDrive 'second.md'
        & $scriptPath -EvidenceManifest $evidence -DashboardManifest $dashboards -OutputPath $first
        & $scriptPath -EvidenceManifest $evidence -DashboardManifest $dashboards -OutputPath $second

        (Get-FileHash $first).Hash | Should Be (Get-FileHash $second).Hash
        (Get-Content $first -Raw) | Should Not Match '[A-Za-z]:[\\/]Users[\\/][^\\/]+'
    }

    It "renders completed fresh SonarQube, ZAP, and JMeter summaries" {
        $output = Join-Path $TestDrive 'appendix.md'
        & $scriptPath -EvidenceManifest $evidence -DashboardManifest $dashboards -OutputPath $output
        $text = Get-Content $output -Raw

        $text | Should Match 'sonarqube-primary[^\r\n]*baseline 17 issues[^\r\n]*remediation 0 issues'
        $text | Should Match 'zap-primary[^\r\n]*baseline raw alerts[^\r\n]*remediation raw alerts'
        $text | Should Match 'jmeter-primary[^\r\n]*p50 p95'
    }

    It "emits parseable PowerShell examples without angle-bracket placeholders" {
        $output = Join-Path $TestDrive 'appendix.md'
        & $scriptPath -EvidenceManifest $evidence -DashboardManifest $dashboards -OutputPath $output
        $text = Get-Content $output -Raw

        $text | Should Not Match '<[^>]+>'
        $text | Should Match 'New-DashboardCaptureCases.ps1'
    }
}
