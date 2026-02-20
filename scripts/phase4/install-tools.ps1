param(
    [string]$SonarContainerName = "financial-sonarqube",
    [string]$ZapContainerName = "financial-zap",
    [string]$JMeterContainerName = "financial-jmeter",
    # Use community/latest by default to avoid running an EOL "LTS" build that SonarQube flags as inactive.
    [string]$SonarImage = "sonarqube:community",
    [string]$ZapImage = "ghcr.io/zaproxy/zaproxy:stable",
    [string]$JMeterImage = "justb4/jmeter:5.5",
    [string]$JMeterUiImage = "nginx:alpine",
    [int]$SonarPort = 9000,
    [int]$ZapWebPort = 8080,
    [int]$ZapApiPort = 8090,
    [int]$JMeterPort = 8088,
    [string]$JMeterReportsDir = "Document/performance",
    [switch]$RecreateSonar,
    [switch]$RecreateZap,
    [switch]$RecreateJMeter,
    [switch]$DisableZapApiKey,
    [switch]$ResetSonarData
)

$ErrorActionPreference = "Stop"

Write-Host "Pulling SonarQube image: $SonarImage"
docker pull $SonarImage

Write-Host "Pulling OWASP ZAP image: $ZapImage"
docker pull $ZapImage

Write-Host "Pulling Apache JMeter image: $JMeterImage"
docker pull $JMeterImage

Write-Host "Pulling JMeter UI image: $JMeterUiImage"
docker pull $JMeterUiImage

function Ensure-DockerVolume {
    param([string]$Name)
    $exists = docker volume ls -q | Where-Object { $_ -eq $Name }
    if (-not $exists) {
        docker volume create $Name | Out-Null
    }
}

function Test-PortBindingMatches {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ContainerName,
        [Parameter(Mandatory = $true)]
        [string]$ContainerPort,
        [Parameter(Mandatory = $true)]
        [int]$ExpectedHostPort
    )

    try {
        $binding = docker port $ContainerName $ContainerPort 2>$null
        if (-not $binding) {
            return $false
        }

        foreach ($line in @($binding)) {
            if ($line -match ":(\d+)$" -and [int]$Matches[1] -eq $ExpectedHostPort) {
                return $true
            }
        }
    }
    catch {
        return $false
    }

    return $false
}

$dataVol = "$SonarContainerName-data"
$extensionsVol = "$SonarContainerName-extensions"
$logsVol = "$SonarContainerName-logs"
$volumes = @($dataVol, $extensionsVol, $logsVol)

if ($ResetSonarData) {
    $RecreateSonar = $true
}

$existing = docker ps -a --format "{{.Names}}" | Where-Object { $_ -eq $SonarContainerName }

# If the container exists but was created with a different image tag, recreate it so the pulled image is actually used.
if ($existing -and -not $RecreateSonar) {
    try {
        $currentImage = docker inspect $SonarContainerName --format "{{.Config.Image}}"
        if ($currentImage -and $currentImage -ne $SonarImage) {
            Write-Host "Existing SonarQube container '$SonarContainerName' uses image '$currentImage'. Recreating to use '$SonarImage'."
            $RecreateSonar = $true
        }
    }
    catch {
        # If inspect fails, proceed with existing behavior (start container).
    }
}

if ($existing -and $RecreateSonar) {
    Write-Host "Recreating SonarQube container: $SonarContainerName"
    docker rm -f $SonarContainerName | Out-Null
    $existing = $null
}

if ($ResetSonarData) {
    foreach ($v in $volumes) {
        docker volume rm -f $v 2>$null | Out-Null
    }
}

foreach ($v in $volumes) {
    Ensure-DockerVolume -Name $v
}

if ($existing) {
    $running = docker ps --format "{{.Names}}" | Where-Object { $_ -eq $SonarContainerName }
    if (-not $running) {
        Write-Host "Starting existing SonarQube container: $SonarContainerName"
        docker start $SonarContainerName | Out-Null
    }
    else {
        Write-Host "SonarQube container already running: $SonarContainerName"
    }
}
else {
    Write-Host "Starting SonarQube on port $SonarPort"
    docker run -d --name $SonarContainerName -p "${SonarPort}:9000" -e SONAR_ES_BOOTSTRAP_CHECKS_DISABLE=true `
        -v "${dataVol}:/opt/sonarqube/data" `
        -v "${extensionsVol}:/opt/sonarqube/extensions" `
        -v "${logsVol}:/opt/sonarqube/logs" `
        $SonarImage | Out-Null
}

$existingZap = docker ps -a --format "{{.Names}}" | Where-Object { $_ -eq $ZapContainerName }

if ($existingZap -and -not $RecreateZap) {
    try {
        $currentZapImage = docker inspect $ZapContainerName --format "{{.Config.Image}}"
        if ($currentZapImage -and $currentZapImage -ne $ZapImage) {
            Write-Host "Existing ZAP container '$ZapContainerName' uses image '$currentZapImage'. Recreating to use '$ZapImage'."
            $RecreateZap = $true
        }
    }
    catch {
        # If inspect fails, continue with existing behavior.
    }

    if (-not $RecreateZap) {
        $webPortMatch = Test-PortBindingMatches -ContainerName $ZapContainerName -ContainerPort "8080/tcp" -ExpectedHostPort $ZapWebPort
        $apiPortMatch = Test-PortBindingMatches -ContainerName $ZapContainerName -ContainerPort "8090/tcp" -ExpectedHostPort $ZapApiPort
        if (-not $webPortMatch -or -not $apiPortMatch) {
            Write-Host "Existing ZAP container '$ZapContainerName' has different port bindings. Recreating to apply ZapWebPort/ZapApiPort."
            $RecreateZap = $true
        }
    }
}

if ($existingZap -and $RecreateZap) {
    Write-Host "Recreating ZAP container: $ZapContainerName"
    docker rm -f $ZapContainerName | Out-Null
    $existingZap = $null
}

if ($existingZap) {
    $zapRunning = docker ps --format "{{.Names}}" | Where-Object { $_ -eq $ZapContainerName }
    if (-not $zapRunning) {
        Write-Host "Starting existing ZAP container: $ZapContainerName"
        docker start $ZapContainerName | Out-Null
    }
    else {
        Write-Host "ZAP container already running: $ZapContainerName"
    }
}
else {
    Write-Host "Starting ZAP Web UI on port $ZapWebPort (API/proxy port $ZapApiPort)"
    $zapArgs = @(
        "run", "-d",
        "--name", $ZapContainerName,
        "-p", "${ZapWebPort}:8080",
        "-p", "${ZapApiPort}:8090",
        $ZapImage,
        "zap-webswing.sh",
        "-host", "0.0.0.0",
        "-port", "8090",
        "-config", "api.addrs.addr.name=.*",
        "-config", "api.addrs.addr.regex=true"
    )

    if ($DisableZapApiKey) {
        $zapArgs += @("-config", "api.disablekey=true")
    }

    docker @zapArgs | Out-Null
}

$fullJMeterReportsDir = [System.IO.Path]::GetFullPath($JMeterReportsDir)
New-Item -ItemType Directory -Path $fullJMeterReportsDir -Force | Out-Null
$jmeterReportsHostPath = $fullJMeterReportsDir -replace '\\','/'
$jmeterNginxConfigPath = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "jmeter-nginx.conf"))
if (-not (Test-Path $jmeterNginxConfigPath)) {
    throw "JMeter nginx config not found: $jmeterNginxConfigPath"
}
$jmeterNginxConfigHostPath = $jmeterNginxConfigPath -replace '\\','/'

$existingJMeter = docker ps -a --format "{{.Names}}" | Where-Object { $_ -eq $JMeterContainerName }

if ($existingJMeter -and -not $RecreateJMeter) {
    try {
        $currentJMeterImage = docker inspect $JMeterContainerName --format "{{.Config.Image}}"
        if ($currentJMeterImage -and $currentJMeterImage -ne $JMeterUiImage) {
            Write-Host "Existing JMeter container '$JMeterContainerName' uses image '$currentJMeterImage'. Recreating to use '$JMeterUiImage'."
            $RecreateJMeter = $true
        }
    }
    catch {
        # If inspect fails, continue with existing behavior.
    }

    if (-not $RecreateJMeter) {
        $jmeterPortMatch = Test-PortBindingMatches -ContainerName $JMeterContainerName -ContainerPort "80/tcp" -ExpectedHostPort $JMeterPort
        if (-not $jmeterPortMatch) {
            Write-Host "Existing JMeter container '$JMeterContainerName' has different port bindings. Recreating to apply JMeterPort."
            $RecreateJMeter = $true
        }
    }
}

if ($existingJMeter -and $RecreateJMeter) {
    Write-Host "Recreating JMeter container: $JMeterContainerName"
    docker rm -f $JMeterContainerName | Out-Null
    $existingJMeter = $null
}

if ($existingJMeter) {
    $jmeterRunning = docker ps --format "{{.Names}}" | Where-Object { $_ -eq $JMeterContainerName }
    if (-not $jmeterRunning) {
        Write-Host "Starting existing JMeter container: $JMeterContainerName"
        docker start $JMeterContainerName | Out-Null
    }
    else {
        Write-Host "JMeter container already running: $JMeterContainerName"
    }
}
else {
    Write-Host "Starting JMeter report UI on port $JMeterPort (serving '$fullJMeterReportsDir')"
    docker run -d --name $JMeterContainerName -p "${JMeterPort}:80" `
        -v "${jmeterReportsHostPath}:/usr/share/nginx/html:ro" `
        -v "${jmeterNginxConfigHostPath}:/etc/nginx/conf.d/default.conf:ro" `
        $JMeterUiImage | Out-Null
}

Write-Host "Waiting for SonarQube status to become UP..."
$maxAttempts = 80
$sonarReady = $false
for ($i = 0; $i -lt $maxAttempts; $i++) {
    try {
        $status = (Invoke-RestMethod -Uri "http://localhost:$SonarPort/api/system/status" -TimeoutSec 5).status
        Write-Host "Current SonarQube status: $status"
        if ($status -eq "UP") {
            Write-Host "SonarQube is ready at http://localhost:$SonarPort"
            $sonarReady = $true
            break
        }
    }
    catch {
        Write-Host "Waiting for SonarQube..."
    }

    Start-Sleep -Seconds 3
}

if (-not $sonarReady) {
    Write-Error "SonarQube did not become ready in time. Check logs with: docker logs $SonarContainerName"
}

Write-Host "Tool containers are ready:"
Write-Host "  SonarQube: http://localhost:$SonarPort"
Write-Host "  ZAP GUI:   http://localhost:$ZapWebPort/zap"
Write-Host "  ZAP API:   http://localhost:$ZapApiPort"
Write-Host "  JMeter UI: http://localhost:$JMeterPort"
