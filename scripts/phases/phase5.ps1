# Requires -Version 5.1
param(
    [switch]$SkipBackup,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptsRoot = Split-Path -Parent $PSScriptRoot

function Invoke-Step {
    param(
        [string]$Name,
        [scriptblock]$Action
    )

    try {
        Write-Host "==> $Name"
        & $Action
    } catch {
        Write-Error "Errore in '$Name': $($_.Exception.Message)"
        throw
    }
}

if (-not $SkipBackup) {
    Invoke-Step -Name "Backup ed export" -Action {
        $script = Join-Path $scriptsRoot "backup.ps1"
        if (-not (Test-Path $script)) {
            throw "Script non trovato: $script"
        }
        & $script -DryRun:$DryRun
    }
}

Write-Host "Fase 5 completata."
