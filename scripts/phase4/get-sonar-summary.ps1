param(
    [Parameter(Mandatory = $true)]
    [string]$SonarToken,
    [string]$SonarUrl = "http://localhost:9000",
    [string]$ProjectKey = "financial-accounting"
)

$ErrorActionPreference = "Stop"

$baseUrl = $SonarUrl.TrimEnd("/")
$authRaw = "{0}:" -f $SonarToken
$authBytes = [System.Text.Encoding]::UTF8.GetBytes($authRaw)
$authHeader = "Basic " + [Convert]::ToBase64String($authBytes)
$headers = @{ Authorization = $authHeader }

$qualityUrl = "$baseUrl/api/qualitygates/project_status?projectKey=$ProjectKey"
$measuresUrl = "$baseUrl/api/measures/component?component=$ProjectKey&metricKeys=bugs,vulnerabilities,code_smells,coverage,duplicated_lines_density,ncloc,complexity,reliability_rating,security_rating,sqale_rating"

$qualityResponse = Invoke-RestMethod -Uri $qualityUrl -Headers $headers -Method Get
$measuresResponse = Invoke-RestMethod -Uri $measuresUrl -Headers $headers -Method Get

$measures = @{}
foreach ($measure in $measuresResponse.component.measures) {
    $measures[$measure.metric] = $measure.value
}

[pscustomobject]@{
    ProjectKey = $ProjectKey
    QualityGate = $qualityResponse.projectStatus.status
    QualityConditions = $qualityResponse.projectStatus.conditions
    Measures = [pscustomobject]$measures
}
