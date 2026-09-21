# Récupère les dernières modifications du dépôt distant (git pull --rebase).
# Usage : .\tools\pull.ps1
$ErrorActionPreference = "Continue"
Set-Location (Split-Path -Parent $PSScriptRoot)
& (Join-Path $PSScriptRoot "_check.ps1"); if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$branch = git rev-parse --abbrev-ref HEAD
Write-Host "==> Pull de origin/$branch..." -ForegroundColor Cyan

git fetch origin
git show-ref --verify --quiet "refs/remotes/origin/$branch"
if ($LASTEXITCODE -ne 0) {
    Write-Host "    La branche '$branch' n'existe pas encore sur origin : rien à récupérer." -ForegroundColor Yellow
    exit 0
}

# Sauvegarde des modifications locales non commitées pour éviter les conflits de rebase
$dirty = [bool](git status --porcelain)
if ($dirty) {
    Write-Host "    Modifications locales détectées : mise de côté temporaire (stash)." -ForegroundColor Yellow
    git stash push -u -m "auto-pull-$(Get-Date -Format 'yyyyMMdd-HHmmss')" | Out-Null
}

git pull --rebase origin $branch
if ($LASTEXITCODE -ne 0) {
    Write-Host "Erreur pendant le pull. Résous les conflits puis relance." -ForegroundColor Red
    if ($dirty) { Write-Host "Tes modifications sont dans 'git stash list'." -ForegroundColor Yellow }
    exit 1
}

if ($dirty) {
    Write-Host "    Restauration des modifications locales." -ForegroundColor Yellow
    git stash pop
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Conflit en restaurant tes modifications. Vérifie 'git status'." -ForegroundColor Red
        exit 1
    }
}

Write-Host "==> Pull terminé." -ForegroundColor Green
