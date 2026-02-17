param(
    [string]$SonarContainerName = "financial-sonarqube",
    [string]$SonarImage = "sonarqube:lts-community",
    [string]$ZapImage = "ghcr.io/zaproxy/zaproxy:stable",
    [string]$JMeterImage = "justb4/jmeter:5.5",
    [int]$SonarPort = 9000,
    [switch]$RecreateSonar,
    [switch]$ResetSonarData
)

$ErrorActionPreference = "Stop"

Write-Host "Pulling SonarQube image: $SonarImage"
docker pull $SonarImage

Write-Host "Pulling OWASP ZAP image: $ZapImage"
docker pull $ZapImage

Write-Host "Pulling Apache JMeter image: $JMeterImage"
docker pull $JMeterImage

function Ensure-DockerVolume {
    param([string]$Name)
    $exists = docker volume ls -q | Where-Object { $_ -eq $Name }
    if (-not $exists) {
        docker volume create $Name | Out-Null
    }
}

$dataVol = "$SonarContainerName-data"
$extensionsVol = "$SonarContainerName-extensions"
$logsVol = "$SonarContainerName-logs"
$volumes = @($dataVol, $extensionsVol, $logsVol)

if ($ResetSonarData) {
    $RecreateSonar = $true
}

$existing = docker ps -a --format "{{.Names}}" | Where-Object { $_ -eq $SonarContainerName }
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

Write-Host "Waiting for SonarQube status to become UP..."
$maxAttempts = 80
for ($i = 0; $i -lt $maxAttempts; $i++) {
    try {
        $status = (Invoke-RestMethod -Uri "http://localhost:$SonarPort/api/system/status" -TimeoutSec 5).status
        Write-Host "Current SonarQube status: $status"
        if ($status -eq "UP") {
            Write-Host "SonarQube is ready at http://localhost:$SonarPort"
            exit 0
        }
    }
    catch {
        Write-Host "Waiting for SonarQube..."
    }

    Start-Sleep -Seconds 3
}

Write-Error "SonarQube did not become ready in time. Check logs with: docker logs $SonarContainerName"
