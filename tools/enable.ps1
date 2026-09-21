# Active la synchronisation automatique sur CET ordinateur uniquement.
# L'état est stocké dans .git/config (jamais commité, propre à cette machine).
# Usage : .\tools\enable.ps1
Set-Location (Split-Path -Parent $PSScriptRoot)
git config --local sync.enabled true
Write-Host "==> Synchronisation automatique ACTIVÉE sur cet ordinateur." -ForegroundColor Green
