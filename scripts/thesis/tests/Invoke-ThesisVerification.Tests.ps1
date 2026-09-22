$scriptPath = Join-Path $PSScriptRoot "../Invoke-ThesisVerification.ps1"

Describe "Invoke-ThesisVerification" {
    It "fails when a required command exits non-zero" {
        $plan = @([pscustomobject]@{
            Name = 'required-failure'; Required = $true; File = 'cmd.exe'; Args = @('/c', 'exit 7')
        })

        $result = & $scriptPath -Mode Fast -OutputDirectory $TestDrive -CommandPlan $plan -SkipEnvironmentAudit -ReturnFailureRecord

        $result.Status | Should Be 'FAIL'
        $result.Commands[0].Status | Should Be 'FAIL'
        $result.Commands[0].ExitCode | Should Be 7
    }

    It "throws for a failed required command by default" {
        $plan = @([pscustomobject]@{
            Name = 'required-failure'; Required = $true; File = 'cmd.exe'; Args = @('/c', 'exit 7')
        })

        { & $scriptPath -Mode Fast -OutputDirectory $TestDrive -CommandPlan $plan -SkipEnvironmentAudit } | Should Throw
    }

    It "records but does not fail an optional command" {
        $plan = @(
            [pscustomobject]@{ Name = 'required-pass'; Required = $true; File = 'cmd.exe'; Args = @('/c', 'exit 0') },
            [pscustomobject]@{ Name = 'browser-optional'; Required = $false; File = 'cmd.exe'; Args = @('/c', 'exit 5') }
        )

        $result = & $scriptPath -Mode Fast -OutputDirectory $TestDrive -CommandPlan $plan -SkipEnvironmentAudit

        $result.Status | Should Be 'PASS_WITH_SKIPS'
        $result.Commands[1].Status | Should Be 'SKIPPED'
        $result.Commands[1].ExitCode | Should Be 5
    }

    It "writes JSON and Markdown run records with portable paths" {
        $plan = @([pscustomobject]@{
            Name = 'portable-pass'; Required = $true; File = 'cmd.exe'; Args = @('/c', 'echo C:\Users\Researcher\repo')
        })

        $result = & $scriptPath -Mode Fast -OutputDirectory $TestDrive -CommandPlan $plan -SkipEnvironmentAudit
        $json = Get-Content $result.JsonPath -Raw
        $markdown = Get-Content $result.MarkdownPath -Raw

        $result.Status | Should Be 'PASS'
        $json | Should Not Match 'Researcher'
        $markdown | Should Not Match 'Researcher'
        $markdown | Should Match 'portable-pass'
    }

    It "rejects Full mode instead of reporting the Fast plan as Full" {
        $plan = @([pscustomobject]@{
            Name = 'required-pass'; Required = $true; File = 'cmd.exe'; Args = @('/c', 'exit 0')
        })

        { & $scriptPath -Mode Full -OutputDirectory $TestDrive -CommandPlan $plan -SkipEnvironmentAudit } | Should Throw
    }
}
