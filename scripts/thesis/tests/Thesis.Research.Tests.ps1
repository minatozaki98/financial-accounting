$modulePath = Join-Path $PSScriptRoot '../Thesis.Research.psm1'
Import-Module $modulePath -Force

Describe "Thesis.Research" {
    It "waits for the submitted Sonar task and returns its analysis id" {
        $script:attempt = 0
        $invoker = {
            param($uri, $headers)
            $script:attempt++
            if ($script:attempt -eq 1) { return [pscustomobject]@{ task = [pscustomobject]@{ status='IN_PROGRESS'; analysisId=$null } } }
            return [pscustomobject]@{ task = [pscustomobject]@{ status='SUCCESS'; analysisId='analysis-123' } }
        }

        $task = Wait-SonarComputeTask -TaskUri 'http://sonar/task/1' -Headers @{} -TimeoutSeconds 3 -PollIntervalMilliseconds 1 -Invoker $invoker

        $task.analysisId | Should Be 'analysis-123'
    }

    It "throws when the submitted Sonar task fails" {
        $invoker = { param($uri, $headers) [pscustomobject]@{ task = [pscustomobject]@{ status='FAILED'; errorMessage='synthetic failure' } } }

        { Wait-SonarComputeTask -TaskUri 'http://sonar/task/1' -Headers @{} -TimeoutSeconds 1 -PollIntervalMilliseconds 1 -Invoker $invoker } | Should Throw
    }

    It "fails JMeter core gates when p100 or p500 exceed thresholds" {
        $summary = [pscustomobject]@{ profiles = @(
            [pscustomobject]@{ profile='p50'; errorPct=0; p95Ms=200 },
            [pscustomobject]@{ profile='p100'; errorPct=0; p95Ms=700 },
            [pscustomobject]@{ profile='p500'; errorPct=0; p95Ms=1300 }
        ) }

        $gate = Get-JMeterGateOutcome -Summary $summary

        $gate.Status | Should Be 'FAIL'
        @($gate.Failures).Count | Should Be 2
    }

    It "accepts runtime evidence only for the exact live process and commit" {
        $evidence = [pscustomobject]@{
            Status='PASS'; Commit=('a' * 40); ApiPid=$PID; OwnedPids=@($PID)
            ApiUrl='http://localhost:5296'; WorkingDirectory=(Get-Location).Path
        }

        Test-RuntimeEvidence -Evidence $evidence -ExpectedCommit ('a' * 40) -ExpectedBaseUrl 'http://localhost:5296' -ExpectedWorkingDirectory (Get-Location).Path | Should Be $true
        { Test-RuntimeEvidence -Evidence $evidence -ExpectedCommit ('b' * 40) -ExpectedBaseUrl 'http://localhost:5296' -ExpectedWorkingDirectory (Get-Location).Path } | Should Throw
    }
}
