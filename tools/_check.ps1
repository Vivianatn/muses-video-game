# Vérifie que la synchronisation est activée sur cet ordinateur. Utilisé par pull/push/sync.
Set-Location (Split-Path -Parent $PSScriptRoot)
if ((git config --local --get sync.enabled) -eq "false") {
    Write-Host "==> Synchronisation automatique désactivée sur cet ordinateur." -ForegroundColor Red
    Write-Host "    Active-la avec : .\tools\enable.ps1" -ForegroundColor Yellow
    exit 2
}
