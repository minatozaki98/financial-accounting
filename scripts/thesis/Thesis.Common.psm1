Set-StrictMode -Version Latest

function Get-ThesisRepositoryRoot {
    [CmdletBinding()]
    param([string]$StartPath = (Get-Location).Path)

    $resolvedStart = (Resolve-Path -LiteralPath $StartPath).Path
    $root = (& git -C $resolvedStart rev-parse --show-toplevel 2>$null)
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($root)) {
        throw "Path is not inside a Git repository: $resolvedStart"
    }

    return [System.IO.Path]::GetFullPath($root.Trim())
}

function Get-GitProvenance {
    [CmdletBinding()]
    param([string]$WorkingDirectory = (Get-Location).Path)

    $root = Get-ThesisRepositoryRoot -StartPath $WorkingDirectory
    $commit = (& git -C $root rev-parse HEAD).Trim()
    if ($LASTEXITCODE -ne 0) { throw "Unable to resolve Git commit in $root" }

    $branch = (& git -C $root branch --show-current).Trim()
    if ([string]::IsNullOrWhiteSpace($branch)) { $branch = "(detached)" }
    $dirtyEntries = @(& git -C $root status --porcelain --untracked-files=normal)
    $upstream = (& git -C $root rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>$null)
    $ahead = 0
    $behind = 0
    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($upstream)) {
        $counts = ((& git -C $root rev-list --left-right --count "$($upstream.Trim())...HEAD").Trim() -split '\s+')
        if ($counts.Count -eq 2) {
            $behind = [int]$counts[0]
            $ahead = [int]$counts[1]
        }
    }
    else {
        $upstream = $null
    }

    [pscustomobject]@{
        Root = $root
        Branch = $branch
        Commit = $commit
        Dirty = $dirtyEntries.Count -gt 0
        DirtyEntryCount = $dirtyEntries.Count
        Upstream = if ($upstream) { $upstream.Trim() } else { $null }
        Ahead = $ahead
        Behind = $behind
    }
}

function Test-LocalSqlTarget {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$ConnectionString)

    try {
        $builder = New-Object System.Data.SqlClient.SqlConnectionStringBuilder $ConnectionString
    }
    catch {
        return $false
    }

    $server = ([string]$builder.DataSource).Trim().ToLowerInvariant()
    return $server -eq "." -or
        $server -eq "localhost" -or
        $server -eq "127.0.0.1" -or
        $server -eq "::1" -or
        $server -eq "(local)" -or
        $server.StartsWith(".\") -or
        $server.StartsWith("localhost\") -or
        $server.StartsWith("127.0.0.1\") -or
        $server.StartsWith("(localdb)\")
}

function Protect-LogText {
    [CmdletBinding()]
    param([AllowNull()][string]$Text)

    if ($null -eq $Text) { return $null }
    $protected = [regex]::Replace($Text, '(?i)((?:Password|Pwd)\s*=\s*)[^;\s]+', '$1[REDACTED]')
    $protected = [regex]::Replace($protected, '(?i)(sonar\.token\s*=\s*)[^;\s]+', '$1[REDACTED]')
    $protected = [regex]::Replace($protected, '(?i)(Authorization\s*:\s*Bearer\s+)[^;\s]+', '$1[REDACTED]')
    $protected = [regex]::Replace($protected, '(?i)([A-Z]:\\Users\\)[^\\]+', '$1[USER]')
    $protected = [regex]::Replace($protected, '(?i)([A-Z]:/Users/)[^/]+', '$1[USER]')
    return $protected
}

function Get-PortOwner {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][int]$Port,
        [int[]]$OwnedPids = @()
    )

    $connection = $null
    if (Get-Command Get-NetTCPConnection -ErrorAction SilentlyContinue) {
        $connection = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue |
            Select-Object -First 1
    }

    if (-not $connection) {
        $line = netstat -ano -p tcp 2>$null |
            Where-Object { $_ -match "^\s*TCP\s+\S+:$Port\s+\S+\s+LISTENING\s+(\d+)\s*$" } |
            Select-Object -First 1
        if ($line -and $line -match "LISTENING\s+(\d+)\s*$") {
            $connection = [pscustomobject]@{ OwningProcess = [int]$Matches[1] }
        }
    }

    if (-not $connection) {
        return [pscustomobject]@{ Port = $Port; IsListening = $false; Pid = $null; Owned = $false }
    }

    $processId = [int]$connection.OwningProcess
    [pscustomobject]@{
        Port = $Port
        IsListening = $true
        Pid = $processId
        Owned = $OwnedPids -contains $processId
    }
}

function Invoke-ThesisCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [string[]]$ArgumentList = @(),
        [string]$WorkingDirectory = (Get-Location).Path
    )

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $previous = (Get-Location).Path
    try {
        Set-Location -LiteralPath $WorkingDirectory
        $output = @(& $FilePath @ArgumentList 2>&1 | ForEach-Object { Protect-LogText ([string]$_) })
        $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int]$LASTEXITCODE }
    }
    catch {
        $output = @(Protect-LogText $_.Exception.Message)
        $exitCode = 1
    }
    finally {
        Set-Location -LiteralPath $previous
        $stopwatch.Stop()
    }

    [pscustomobject]@{
        FilePath = $FilePath
        Arguments = @($ArgumentList)
        WorkingDirectory = [System.IO.Path]::GetFullPath($WorkingDirectory)
        ExitCode = $exitCode
        DurationMs = $stopwatch.ElapsedMilliseconds
        Output = @($output)
    }
}

function Write-ThesisJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]$InputObject,
        [Parameter(Mandatory = $true)][string]$Path,
        [int]$Depth = 20
    )

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $parent = Split-Path -Parent $fullPath
    if (-not (Test-Path -LiteralPath $parent)) {
        $null = New-Item -ItemType Directory -Path $parent -Force
    }
    $json = $InputObject | ConvertTo-Json -Depth $Depth
    [System.IO.File]::WriteAllText($fullPath, $json + [Environment]::NewLine, (New-Object System.Text.UTF8Encoding($false)))
    return $fullPath
}

Export-ModuleMember -Function @(
    'Get-ThesisRepositoryRoot',
    'Get-GitProvenance',
    'Test-LocalSqlTarget',
    'Protect-LogText',
    'Get-PortOwner',
    'Invoke-ThesisCommand',
    'Write-ThesisJson'
)
