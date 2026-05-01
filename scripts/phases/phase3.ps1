# Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

param(
    [switch]$SkipPrivacy,
    [switch]$SkipPower,
    [switch]$SkipUpdate
)

$scriptsRoot = Split-Path -Parent $PSScriptRoot

function Assert-Admin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Warning "Impossibile continuare: avvia PowerShell come amministratore."
        exit 1
    }
}

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

Assert-Admin

if (-not $SkipPrivacy) {
    Invoke-Step -Name "Privacy e telemetry" -Action {
        $script = Join-Path $scriptsRoot "privacy.ps1"
        if (-not (Test-Path $script)) {
            throw "Script non trovato: $script"
        }
        & $script
    }
}

if (-not $SkipPower) {
    Invoke-Step -Name "Power plan" -Action {
        $script = Join-Path $scriptsRoot "power.ps1"
        if (-not (Test-Path $script)) {
            throw "Script non trovato: $script"
        }
        & $script -Plan HighPerformance
    }
}

if (-not $SkipUpdate) {
    Invoke-Step -Name "Windows Update" -Action {
        $script = Join-Path $scriptsRoot "update.ps1"
        if (-not (Test-Path $script)) {
            throw "Script non trovato: $script"
        }
        & $script -Mode ManualDownload
    }
}

Write-Host "Fase 3 completata."
