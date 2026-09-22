$modulePath = Join-Path $PSScriptRoot "../Thesis.Common.psm1"
$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "../../.."))
Import-Module $modulePath -Force

Describe "Thesis.Common" {
    It "accepts loopback and named local SQL targets" {
        Test-LocalSqlTarget "Server=localhost;Database=Financial;Trusted_Connection=True" | Should Be $true
        Test-LocalSqlTarget "Server=.\SQLEXPRESS;Database=Financial;Trusted_Connection=True" | Should Be $true
        Test-LocalSqlTarget "Server=(localdb)\MSSQLLocalDB;Database=Financial;Trusted_Connection=True" | Should Be $true
        Test-LocalSqlTarget "Server=127.0.0.1;Database=Financial;Trusted_Connection=True" | Should Be $true
    }

    It "rejects a remote SQL target" {
        Test-LocalSqlTarget "Server=db.example.com;Database=Financial;User Id=x;Password=y" | Should Be $false
    }

    It "redacts credential-shaped values" {
        $value = Protect-LogText "Password=secret; sonar.token=abc123 Authorization: Bearer token-value"

        $value | Should Be "Password=[REDACTED]; sonar.token=[REDACTED] Authorization: Bearer [REDACTED]"
    }

    It "redacts quoted password values and Basic authorization" {
        $value = Protect-LogText 'Password="two word sentinel"; Authorization: Basic abc123=='

        $value | Should Be 'Password=[REDACTED]; Authorization: Basic [REDACTED]'
    }

    It "redacts a Windows user-profile segment" {
        $value = Protect-LogText 'Build failed at C:\Users\Researcher\repo\API\Program.cs'

        $value | Should Be 'Build failed at C:\Users\[USER]\repo\API\Program.cs'
    }

    It "redacts a slash-normalized Windows user-profile segment" {
        $value = Protect-LogText 'Test root C:/Users/Researcher/repo/WEB'

        $value | Should Be 'Test root C:/Users/[USER]/repo/WEB'
    }

    It "writes parseable JSON and creates its parent directory" {
        $path = Join-Path $TestDrive "nested/result.json"

        Write-ThesisJson -InputObject ([pscustomobject]@{ Status = "PASS"; Count = 3 }) -Path $path

        $result = Get-Content $path -Raw | ConvertFrom-Json
        $result.Status | Should Be "PASS"
        $result.Count | Should Be 3
    }

    It "resolves the repository root from a nested directory" {
        $root = Get-ThesisRepositoryRoot -StartPath $PSScriptRoot

        (Test-Path (Join-Path $root ".git")) | Should Be $true
        $root | Should Be $repositoryRoot
    }

    It "reports the current Git branch, commit, and Boolean dirty state" {
        $provenance = Get-GitProvenance -WorkingDirectory $PSScriptRoot

        $provenance.Branch | Should Be "codex/thesis-reproducibility-v1"
        $provenance.Commit | Should Match '^[0-9a-f]{40}$'
        $provenance.Dirty.GetType().FullName | Should Be "System.Boolean"
        $provenance.DirtyEntryCount | Should Not BeLessThan 0
    }

    It "runs a command and redacts its captured output" {
        $result = Invoke-ThesisCommand -FilePath "cmd.exe" -ArgumentList @('/c', 'echo Password=secret')

        $result.ExitCode | Should Be 0
        ($result.Output -join "`n") | Should Be "Password=[REDACTED]"
        $result.DurationMs | Should BeGreaterThan -1
    }
}
