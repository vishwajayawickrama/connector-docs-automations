# Convert workflow-docs markdown files to PDF
# Requires: npm (uses md-to-pdf via npx)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $ScriptDir
$workflowDir = Join-Path $projectRoot "artifacts" "workflow-docs"
$outputDir = Join-Path $workflowDir "pdf"

# Create output directory
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

# Find all markdown files in workflow-docs (exclude pdf subfolder)
$mdFiles = Get-ChildItem -Path $workflowDir -Filter "*.md" -File

if ($mdFiles.Count -eq 0) {
    Write-Host "No markdown files found in $workflowDir" -ForegroundColor Yellow
    exit 0
}

Write-Host "=== Markdown to PDF Converter ===" -ForegroundColor Cyan
Write-Host ""

foreach ($file in $mdFiles) {
    $pdfName = [System.IO.Path]::ChangeExtension($file.Name, ".pdf")
    $generatedPdf = Join-Path $workflowDir $pdfName
    $finalPdf = Join-Path $outputDir $pdfName

    Write-Host "Converting: $($file.Name) -> pdf/$pdfName" -ForegroundColor Green
    
    # md-to-pdf generates PDF next to the source file
    npx --yes md-to-pdf $file.FullName 2>&1 | Out-Null

    if (Test-Path $generatedPdf) {
        # Move PDF to the pdf/ subdirectory
        Move-Item -Path $generatedPdf -Destination $finalPdf -Force
        Write-Host "  Done: $finalPdf" -ForegroundColor Green
    } else {
        Write-Host "  Failed to convert $($file.Name)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "=== Conversion Complete ===" -ForegroundColor Cyan
Write-Host "PDFs saved to: $outputDir"
