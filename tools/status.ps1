# Affiche si la synchronisation automatique est activée sur cet ordinateur.
# Usage : .\tools\status.ps1
Set-Location (Split-Path -Parent $PSScriptRoot)
$state = git config --local --get sync.enabled
if ($state -eq "false") {
    Write-Host "Synchronisation automatique : DÉSACTIVÉE (cet ordinateur)" -ForegroundColor Yellow
} else {
    Write-Host "Synchronisation automatique : ACTIVÉE (cet ordinateur)" -ForegroundColor Green
}
