# Désactive la synchronisation automatique sur CET ordinateur uniquement.
# Les scripts pull/push/sync refuseront de s'exécuter tant qu'elle est désactivée.
# Usage : .\tools\disable.ps1
Set-Location (Split-Path -Parent $PSScriptRoot)
git config --local sync.enabled false
Write-Host "==> Synchronisation automatique DÉSACTIVÉE sur cet ordinateur." -ForegroundColor Yellow
Write-Host "    Pour la réactiver : .\tools\enable.ps1" -ForegroundColor Yellow
