# Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script = Join-Path $PSScriptRoot "scripts\wizard.ps1"
if (-not (Test-Path $script)) {
    throw "Wizard non trovato: $script"
}

& $script
