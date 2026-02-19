param(
    [string]$OutputPath = "Document/performance/runtime-metrics.csv",
    [int]$DurationSeconds = 900,
    [int]$IntervalSeconds = 5,
    [string]$ProcessName = "dotnet"
)

$ErrorActionPreference = "Stop"

$directory = Split-Path -Parent $OutputPath
if (-not [string]::IsNullOrWhiteSpace($directory)) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
}

$iterations = [Math]::Max(1, [Math]::Floor($DurationSeconds / $IntervalSeconds))
$sampleCount = 0

"TimestampUtc,CpuTotalPct,AvailableMemoryMb,ProcessName,WorkingSetMb,PrivateMemoryMb" | Set-Content -Path $OutputPath -Encoding UTF8

for ($i = 0; $i -lt $iterations; $i++) {
    $timestamp = Get-Date

    $cpuCounter = Get-Counter "\Processor(_Total)\% Processor Time"
    $memoryCounter = Get-Counter "\Memory\Available MBytes"

    $processes = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
    $workingSetMb = if ($processes) { [math]::Round((($processes | Measure-Object -Property WorkingSet64 -Sum).Sum / 1MB), 2) } else { 0 }
    $privateMb = if ($processes) { [math]::Round((($processes | Measure-Object -Property PrivateMemorySize64 -Sum).Sum / 1MB), 2) } else { 0 }

    $line = "{0},{1},{2},{3},{4},{5}" -f `
        $timestamp.ToUniversalTime().ToString("o"), `
        [math]::Round($cpuCounter.CounterSamples[0].CookedValue, 2), `
        [math]::Round($memoryCounter.CounterSamples[0].CookedValue, 2), `
        $ProcessName, `
        $workingSetMb, `
        $privateMb

    Add-Content -Path $OutputPath -Value $line
    $sampleCount++

    Start-Sleep -Seconds $IntervalSeconds
}

Write-Host "Runtime metrics written: $OutputPath"

[pscustomobject]@{
    OutputPath = [System.IO.Path]::GetFullPath($OutputPath)
    Samples = $sampleCount
}
