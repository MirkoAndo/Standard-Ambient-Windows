# Requires -Version 5.1
param(
    [string[]]$Profiles = @("base"),
    [switch]$DryRun,
    [switch]$Silent,
    [switch]$Interactive
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

Invoke-Step -Name "Installazioni Fase 2" -Action {
    $script = Join-Path $scriptsRoot "install-phase2.ps1"
    if (-not (Test-Path $script)) {
        throw "Script non trovato: $script"
    }
    & $script -Profiles $Profiles -DryRun:$DryRun -Silent:$Silent -Interactive:$Interactive
}

Write-Host "Fase 2 completata."
