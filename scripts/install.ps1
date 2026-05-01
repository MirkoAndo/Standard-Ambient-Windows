# Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$configPath = Join-Path $root "config\packages.json"

if (-not (Test-Path $configPath)) {
    throw "Config non trovata: $configPath"
}

$packages = Get-Content $configPath | ConvertFrom-Json

# Placeholder: integra il tuo gestore pacchetti (winget/choco)
Write-Host "Pacchetti da installare:"
$packages.winget | ForEach-Object { Write-Host "- $_" }
