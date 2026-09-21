# Fait tout en une commande : pull (avec rebase) puis commit + push.
# Usage : .\tools\sync.ps1 ["message de commit"]
param([string]$Message)
$ErrorActionPreference = "Continue"

& "$PSScriptRoot\pull.ps1"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& "$PSScriptRoot\push.ps1" $Message
exit $LASTEXITCODE
