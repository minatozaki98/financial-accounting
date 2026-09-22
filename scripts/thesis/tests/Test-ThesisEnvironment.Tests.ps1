$scriptPath = Join-Path $PSScriptRoot "../Test-ThesisEnvironment.ps1"
$modulePath = Join-Path $PSScriptRoot "../Thesis.Common.psm1"
Import-Module $modulePath -Force

Describe "Test-ThesisEnvironment" {
    It "does not block Fast mode when Docker is unavailable" {
        $dockerCommand = Get-Command docker -ErrorAction SilentlyContinue
        $oldPath = $env:PATH
        try {
            if ($dockerCommand) {
                $dockerDirectory = Split-Path -Parent $dockerCommand.Source
                $env:PATH = (($oldPath -split ';') | Where-Object { $_ -and $_ -ne $dockerDirectory }) -join ';'
            }

            $result = & $scriptPath -Mode Fast -OutputPath (Join-Path $TestDrive "fast.json")

            $result.Status | Should Not Be "ENVIRONMENT_BLOCKED"
            $result.Docker.ServerAvailable | Should Be $false
        }
        finally {
            $env:PATH = $oldPath
        }
    }

    It "blocks Full mode when Docker is unavailable" {
        $dockerCommand = Get-Command docker -ErrorAction SilentlyContinue
        $oldPath = $env:PATH
        try {
            if ($dockerCommand) {
                $dockerDirectory = Split-Path -Parent $dockerCommand.Source
                $env:PATH = (($oldPath -split ';') | Where-Object { $_ -and $_ -ne $dockerDirectory }) -join ';'
            }

            $result = & $scriptPath -Mode Full -OutputPath (Join-Path $TestDrive "full.json")

            $result.Status | Should Be "ENVIRONMENT_BLOCKED"
            (@($result.BlockingReasons) -contains "Docker server is unavailable.") | Should Be $true
        }
        finally {
            $env:PATH = $oldPath
        }
    }

    It "marks SonarQube as skipped when no token is present" {
        $oldToken = $env:SONAR_TOKEN
        try {
            Remove-Item Env:SONAR_TOKEN -ErrorAction SilentlyContinue

            $result = & $scriptPath -Mode Fast -OutputPath (Join-Path $TestDrive "sonar.json")

            $result.SonarTokenPresent | Should Be $false
            $result.SonarStatus | Should Be "SKIPPED"
        }
        finally {
            if ($null -ne $oldToken) { $env:SONAR_TOKEN = $oldToken }
        }
    }

    It "enumerates every required repository file" {
        $result = & $scriptPath -Mode Fast -OutputPath (Join-Path $TestDrive "files.json")
        $paths = @($result.Files | ForEach-Object { $_.Path })

        ($paths -contains "API/API.csproj") | Should Be $true
        ($paths -contains "WEB/package.json") | Should Be $true
        ($paths -contains "Document/sql/financial_accounting_schema.sql") | Should Be $true
        @($result.Files | Where-Object { -not $_.Exists }).Count | Should Be 0
    }

    It "does not persist a local Windows user-profile path" {
        $path = Join-Path $TestDrive "portable.json"

        $null = & $scriptPath -Mode Fast -OutputPath $path

        (Get-Content $path -Raw) | Should Not Match '[A-Za-z]:\\\\Users\\\\[^\\]+'
    }

    It "reports an occupied port and its owning process without stopping it" {
        $listener = New-Object System.Net.Sockets.TcpListener ([System.Net.IPAddress]::Loopback), 0
        $listener.Start()
        try {
            $port = ([System.Net.IPEndPoint]$listener.LocalEndpoint).Port
            $owner = Get-PortOwner -Port $port

            $owner.IsListening | Should Be $true
            $owner.Pid | Should BeGreaterThan 0
            (Get-Process -Id $owner.Pid -ErrorAction SilentlyContinue) | Should Not BeNullOrEmpty
        }
        finally {
            $listener.Stop()
        }
    }
}
