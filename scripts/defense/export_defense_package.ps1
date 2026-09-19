param(
    [ValidateSet('All', 'PowerPoint', 'Word')]
    [string]$Mode = 'All'
)

$ErrorActionPreference = 'Stop'

if ($Mode -eq 'All') {
    $pwsh = (Get-Command pwsh -ErrorAction Stop).Source
    & $pwsh -NoProfile -ExecutionPolicy Bypass -File $PSCommandPath -Mode PowerPoint
    if ($LASTEXITCODE -ne 0) { throw 'PowerPoint PDF export failed.' }
    & $pwsh -NoProfile -ExecutionPolicy Bypass -File $PSCommandPath -Mode Word
    if ($LASTEXITCODE -ne 0) { throw 'Word PDF export failed.' }
    return
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$outputDir = (Resolve-Path (Join-Path $repoRoot 'Document\outputs\final-defense')).Path
$pptxPath = Join-Path $outputDir 'G6519692_Zaw_Ye_Htut_Ko_Final_Thesis_Defense.pptx'
$pptPdfPath = Join-Path $outputDir 'G6519692_Zaw_Ye_Htut_Ko_Final_Thesis_Defense.pdf'
$guidePath = Join-Path $outputDir 'G6519692_Zaw_Ye_Htut_Ko_Defense_Preparation_Guide.docx'
$guidePdfPath = Join-Path $outputDir 'G6519692_Zaw_Ye_Htut_Ko_Defense_Preparation_Guide.pdf'

function Assert-OutputPath([string]$Path) {
    $parent = (Resolve-Path (Split-Path -Parent $Path)).Path
    if ($parent -ne $outputDir) {
        throw "Refusing to modify an output outside $outputDir`: $Path"
    }
}

function Remove-ExistingOutput([string]$Path) {
    Assert-OutputPath $Path
    if (Test-Path -LiteralPath $Path) {
        Remove-Item -LiteralPath $Path -Force
    }
}

foreach ($required in @($pptxPath, $guidePath)) {
    if (-not (Test-Path -LiteralPath $required)) {
        throw "Missing source Office document: $required"
    }
}

$powerPoint = $null
$presentation = $null
$word = $null
$document = $null

try {
    if ($Mode -eq 'PowerPoint') {
        Remove-ExistingOutput $pptPdfPath
        $powerPoint = New-Object -ComObject PowerPoint.Application
        if ($powerPoint.Presentations.Count -ne 0) {
            throw 'The new PowerPoint instance already contains presentations; refusing to continue.'
        }
        $presentation = $powerPoint.Presentations.Open($pptxPath, $true, $false, $false)
        $presentation.SaveAs($pptPdfPath, 32)
        Write-Output "Exported PowerPoint PDF: $pptPdfPath"
    }

    if ($Mode -eq 'Word') {
        Remove-ExistingOutput $guidePdfPath
        $temporaryRoot = 'C:\Temp'
        if (-not (Test-Path -LiteralPath $temporaryRoot)) {
            New-Item -ItemType Directory -Path $temporaryRoot | Out-Null
        }
        $temporaryGuidePdf = Join-Path $temporaryRoot ("defense-guide-" + [guid]::NewGuid().ToString('N') + '.pdf')
        Write-Output 'Starting Word COM instance.'
        $word = New-Object -ComObject Word.Application
        Write-Output 'Word COM instance started.'
        if ($word.Documents.Count -ne 0) {
            throw 'The new Word instance already contains documents; refusing to continue.'
        }
        $word.Visible = $false
        $word.DisplayAlerts = 0
        $word.AutomationSecurity = 3
        Write-Output "Opening guide: $guidePath"
        $document = $word.Documents.Open($guidePath, $false, $true, $false)
        Write-Output 'Guide opened; exporting PDF.'
        $document.ExportAsFixedFormat($temporaryGuidePdf, 17)
        Write-Output "Temporary guide PDF exported: $temporaryGuidePdf"
        Copy-Item -LiteralPath $temporaryGuidePdf -Destination $guidePdfPath -Force
        Remove-Item -LiteralPath $temporaryGuidePdf -Force
        $guidePages = $document.ComputeStatistics(2)
        Write-Output "Exported Word PDF: $guidePdfPath"
        [pscustomobject]@{ GuidePdf = $guidePdfPath; GuidePages = $guidePages } | Format-List
    }
}
finally {
    if ($null -ne $document) {
        $document.Close(0)
        [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($document)
    }
    if ($null -ne $word) {
        if ($word.Documents.Count -eq 0) { $word.Quit(0) }
        [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($word)
    }
    if ($null -ne $presentation) {
        $presentation.Close()
        [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($presentation)
    }
    if ($null -ne $powerPoint) {
        if ($powerPoint.Presentations.Count -eq 0) { $powerPoint.Quit() }
        [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($powerPoint)
    }
    [GC]::Collect()
    [GC]::WaitForPendingFinalizers()
}
