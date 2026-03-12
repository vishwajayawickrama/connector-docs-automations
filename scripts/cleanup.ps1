# Cleanup script: removes all generated artifacts and build output
# Removes: artifacts/ (screenshots, execution-prompt, workflow-docs) and target/

param(
    [switch]$Force  # Skip confirmation prompt
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $ScriptDir

$dirsToClean = @(
    @{ Name = "Generated artifacts"; Path = Join-Path $projectRoot "artifacts" },
    @{ Name = "Build artifacts"; Path = Join-Path $projectRoot "target" }
)

Write-Host "=== Workflow Cleanup ===" -ForegroundColor Cyan
Write-Host ""

# Collect what will be deleted
$toDelete = @()

foreach ($dir in $dirsToClean) {
    if (Test-Path $dir.Path) {
        $fileCount = (Get-ChildItem -Path $dir.Path -File -Recurse -ErrorAction SilentlyContinue).Count
        $relativePath = $dir.Path.Replace($projectRoot + "\", "")
        $toDelete += "  $($dir.Name.PadRight(20)) $relativePath/  ($fileCount file(s))"
    }
}

if ($toDelete.Count -eq 0) {
    Write-Host "Nothing to clean up. All directories are already removed." -ForegroundColor Green
    exit 0
}

Write-Host "The following directories will be deleted:" -ForegroundColor Yellow
foreach ($item in $toDelete) {
    Write-Host $item -ForegroundColor Yellow
}
Write-Host ""

# Confirm unless -Force
if (-not $Force) {
    $confirm = Read-Host "Proceed with cleanup? (y/N)"
    if ($confirm -ne "y" -and $confirm -ne "Y") {
        Write-Host "Cleanup cancelled." -ForegroundColor Red
        exit 0
    }
}

Write-Host ""

# Delete each directory entirely
foreach ($dir in $dirsToClean) {
    if (Test-Path $dir.Path) {
        Remove-Item -Path $dir.Path -Recurse -Force
        $relativePath = $dir.Path.Replace($projectRoot + "\", "")
        Write-Host "  Removed: $relativePath/" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "=== Cleanup Complete ===" -ForegroundColor Cyan