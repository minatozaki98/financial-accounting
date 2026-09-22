$scriptPath = Join-Path $PSScriptRoot "../Invoke-ThesisDemo.ps1"

function Get-FreeTcpPort {
    $listener = New-Object System.Net.Sockets.TcpListener ([System.Net.IPAddress]::Loopback), 0
    $listener.Start()
    try { return ([System.Net.IPEndPoint]$listener.LocalEndpoint).Port }
    finally { $listener.Stop() }
}

function Stop-TestProcessTree {
    param([int[]]$ProcessIds)
    foreach ($processId in $ProcessIds) {
        if (Get-Process -Id $processId -ErrorAction SilentlyContinue) {
            & taskkill /PID $processId /T /F 2>$null | Out-Null
        }
    }
}

Describe "Invoke-ThesisDemo" {
    It "rejects an occupied unowned port without stopping its owner" {
        $listener = New-Object System.Net.Sockets.TcpListener ([System.Net.IPAddress]::Loopback), 0
        $listener.Start()
        try {
            $apiPort = ([System.Net.IPEndPoint]$listener.LocalEndpoint).Port
            $webPort = Get-FreeTcpPort

            $message = $null
            try {
                & $scriptPath -ApiPort $apiPort -WebPort $webPort -SkipDatabase -WhatIf
                throw 'Expected occupied-port rejection.'
            }
            catch {
                $message = $_.Exception.Message
            }
            $message | Should Match "port $apiPort"
            $listener.Server.IsBound | Should Be $true
        }
        finally {
            $listener.Stop()
        }
    }

    It "returns FAIL on readiness timeout and stops owned child processes" {
        $apiPort = Get-FreeTcpPort
        $webPort = Get-FreeTcpPort
        $sleepArgs = @('-NoProfile', '-Command', 'Start-Sleep -Seconds 30')

        $result = & $scriptPath -ApiPort $apiPort -WebPort $webPort -SkipDatabase -SkipBrowserSmoke -ReturnFailureRecord `
            -ApiExecutable 'powershell.exe' -ApiArgumentList $sleepArgs `
            -WebExecutable 'powershell.exe' -WebArgumentList $sleepArgs `
            -StartupTimeoutSeconds 1

        $result.Status | Should Be "FAIL"
        @($result.OwnedPids).Count | Should Be 2
        foreach ($processId in $result.OwnedPids) {
            (Get-Process -Id $processId -ErrorAction SilentlyContinue) | Should BeNullOrEmpty
        }
    }

    It "returns owned PIDs and leaves them running only with KeepRunning" {
        $apiPort = Get-FreeTcpPort
        $webPort = Get-FreeTcpPort
        $python = (Get-Command python).Source
        $apiArgs = @('-m', 'http.server', "$apiPort", '--bind', '127.0.0.1')
        $webArgs = @('-m', 'http.server', "$webPort", '--bind', '127.0.0.1')
        $result = $null
        try {
            $result = & $scriptPath -ApiPort $apiPort -WebPort $webPort -SkipDatabase -SkipBrowserSmoke -KeepRunning `
                -ApiExecutable $python -ApiArgumentList $apiArgs -ApiProbePaths @('/') `
                -WebExecutable $python -WebArgumentList $webArgs -StartupTimeoutSeconds 10

            $result.Status | Should Be "PASS"
            @($result.OwnedPids).Count | Should Be 2
            foreach ($processId in $result.OwnedPids) {
                (Get-Process -Id $processId -ErrorAction SilentlyContinue) | Should Not BeNullOrEmpty
            }
        }
        finally {
            if ($result) { Stop-TestProcessTree -ProcessIds $result.OwnedPids }
        }
    }

    It "writes a run record without a local user-profile path" {
        $apiPort = Get-FreeTcpPort
        $webPort = Get-FreeTcpPort
        $outputPath = Join-Path $TestDrive 'demo.json'

        $null = & $scriptPath -ApiPort $apiPort -WebPort $webPort -SkipDatabase -WhatIf -OutputPath $outputPath

        (Get-Content $outputPath -Raw) | Should Not Match '[A-Za-z]:\\\\Users\\\\[^\\]+'
        (Get-Content $outputPath -Raw | ConvertFrom-Json).Status | Should Be 'WHATIF'
    }

    It "rejects an inherited remote database override before startup" {
        $oldValue = $env:AppSettings__ConnectionStrings
        try {
            $env:AppSettings__ConnectionStrings = 'Server=remote.example.com;Database=Financial;User Id=x;Password=sentinel'
            { & $scriptPath -ApiPort (Get-FreeTcpPort) -WebPort (Get-FreeTcpPort) -WhatIf } | Should Throw
        }
        finally {
            if ($null -eq $oldValue) { Remove-Item Env:AppSettings__ConnectionStrings -ErrorAction SilentlyContinue }
            else { $env:AppSettings__ConnectionStrings = $oldValue }
        }
    }

    It "reports matching alternate-port CORS and frontend API settings" {
        $apiPort = Get-FreeTcpPort
        $webPort = Get-FreeTcpPort
        $result = & $scriptPath -ApiPort $apiPort -WebPort $webPort -SkipDatabase -WhatIf

        $result.FrontendApiUrl | Should Be "http://localhost:$apiPort"
        (@($result.AllowedOrigins) -contains "http://localhost:$webPort") | Should Be $true
        (@($result.AllowedOrigins) -contains "http://127.0.0.1:$webPort") | Should Be $true
    }
}
