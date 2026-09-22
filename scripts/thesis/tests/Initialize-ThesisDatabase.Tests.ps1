$scriptPath = Join-Path $PSScriptRoot "../Initialize-ThesisDatabase.ps1"

Describe "Initialize-ThesisDatabase" {
    It "rejects a remote SQL target before any schema action" {
        $message = $null
        try {
            & $scriptPath -ConnectionString "Server=prod.example.com;Database=Financial;User Id=x;Password=secret" -WhatIf
            throw "Expected remote target rejection."
        }
        catch {
            $message = $_.Exception.Message
        }

        $message | Should Match "Refusing non-local SQL target"
        $message | Should Not Match "secret"
    }

    It "allows a remote SQL target only with explicit opt-in and WhatIf" {
        $result = & $scriptPath -ConnectionString "Server=prod.example.com;Database=Financial;User Id=x;Password=secret" -AllowNonLocalDatabase -WhatIf

        $result.Status | Should Be "WHATIF"
        $result.Server | Should Be "prod.example.com"
        $result.Database | Should Be "Financial"
        $result.SchemaApplied | Should Be $false
    }

    It "accepts the default local target in WhatIf mode" {
        $result = & $scriptPath -WhatIf

        $result.Status | Should Be "WHATIF"
        $result.Server | Should Be "localhost"
        $result.Database | Should Be "Financial"
    }

    It "writes a password-free WhatIf record" {
        $outputPath = Join-Path $TestDrive "database-whatif.json"

        $null = & $scriptPath -ConnectionString "Server=localhost;Database=Financial;User Id=x;Password=secret" -OutputPath $outputPath -WhatIf
        $text = Get-Content $outputPath -Raw

        $text | Should Not Match "secret"
        ($text | ConvertFrom-Json).Status | Should Be "WHATIF"
    }
}
