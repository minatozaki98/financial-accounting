$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "../../.."))
$evidencePath = Join-Path $repositoryRoot "docs/appendix/thesis-evidence-manifest.json"
$dashboardPath = Join-Path $repositoryRoot "docs/appendix/dashboard-capture-manifest.json"

Describe "Thesis evidence manifests" {
    It "pins the four primary evidence refs to 40-character commits" {
        $manifest = Get-Content $evidencePath -Raw | ConvertFrom-Json

        @($manifest.evidenceRefs).Count | Should Be 4
        @($manifest.evidenceRefs | Where-Object { $_.commit -notmatch '^[0-9a-f]{40}$' }).Count | Should Be 0
    }

    It "labels the thesis model as GPT-5.4" {
        $manifest = Get-Content $evidencePath -Raw | ConvertFrom-Json

        $manifest.thesisModel | Should Be "gpt-5.4"
    }

    It "keeps every primary claim in the current-paper scope" {
        $manifest = Get-Content $evidencePath -Raw | ConvertFrom-Json

        @($manifest.claims).Count | Should Be 6
        @($manifest.claims | Where-Object { $_.scope -ne 'current-paper' }).Count | Should Be 0
    }

    It "assigns source files and historical artifacts to every claim" {
        (Test-Path $evidencePath) | Should Be $true
        $manifest = Get-Content $evidencePath -Raw | ConvertFrom-Json

        @($manifest.claims | Where-Object { @($_.sourceFiles).Count -eq 0 }).Count | Should Be 0
        @($manifest.claims | Where-Object { @($_.historicalArtifacts).Count -eq 0 }).Count | Should Be 0
    }

    It "keeps dashboard captures within the versioned required set" {
        $manifest = Get-Content $dashboardPath -Raw | ConvertFrom-Json

        $manifest.schemaVersion | Should Be 1
        @($manifest.captures).Count | Should Not BeGreaterThan @($manifest.requiredCaptures).Count
        foreach ($capture in $manifest.captures) {
            (@($manifest.requiredCaptures) -contains $capture.imagePath) | Should Be $true
        }
    }
}
