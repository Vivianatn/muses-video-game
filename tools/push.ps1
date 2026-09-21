# Ajoute, commit et pousse toutes les modifications du projet.
# Usage : .\tools\push.ps1 ["message de commit"]
param([string]$Message)
$ErrorActionPreference = "Continue"
Set-Location (Split-Path -Parent $PSScriptRoot)
& (Join-Path $PSScriptRoot "_check.ps1"); if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$branch = git rev-parse --abbrev-ref HEAD

if (-not (git status --porcelain)) {
    Write-Host "==> Rien à commiter." -ForegroundColor Yellow
} else {
    if (-not $Message) {
        $Message = "MAJ $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
    }
    Write-Host "==> Commit : $Message" -ForegroundColor Cyan
    git add -A
    git commit -m $Message
    if ($LASTEXITCODE -ne 0) { exit 1 }
}

Write-Host "==> Push vers origin/$branch..." -ForegroundColor Cyan
git push -u origin $branch
if ($LASTEXITCODE -ne 0) {
    Write-Host "Erreur pendant le push. Essaie d'abord .\tools\pull.ps1" -ForegroundColor Red
    exit 1
}

Write-Host "==> Push terminé." -ForegroundColor Green
