# Requires -Version 5.1
param(
    [switch]$SkipStartMenu,
    [switch]$SkipSnap,
    [switch]$SkipTerminal,
    [switch]$SkipOhMyPosh,
    [switch]$SkipCleanup,
    [switch]$IncludeAllUsersStartMenu
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

if (-not $SkipStartMenu) {
    Invoke-Step -Name "Start Menu" -Action {
        $script = Join-Path $scriptsRoot "startmenu.ps1"
        if (-not (Test-Path $script)) {
            throw "Script non trovato: $script"
        }
        & $script -IncludeAllUsers:$IncludeAllUsersStartMenu
    }
}

if (-not $SkipSnap) {
    Invoke-Step -Name "Snap Layouts" -Action {
        $script = Join-Path $scriptsRoot "snap.ps1"
        if (-not (Test-Path $script)) {
            throw "Script non trovato: $script"
        }
        & $script -EnableSnap 1
    }
}

if (-not $SkipTerminal) {
    Invoke-Step -Name "Windows Terminal" -Action {
        $script = Join-Path $scriptsRoot "terminal.ps1"
        if (-not (Test-Path $script)) {
            throw "Script non trovato: $script"
        }
        & $script
    }
}

if (-not $SkipOhMyPosh) {
    Invoke-Step -Name "Oh My Posh" -Action {
        $script = Join-Path $scriptsRoot "ohmyposh.ps1"
        if (-not (Test-Path $script)) {
            throw "Script non trovato: $script"
        }
        & $script -Theme "atomicBit" -Shell Both -InstallIfMissing
    }
}

if (-not $SkipCleanup) {
    Invoke-Step -Name "Cleanup temp" -Action {
        $script = Join-Path $scriptsRoot "cleanup.ps1"
        if (-not (Test-Path $script)) {
            throw "Script non trovato: $script"
        }
        & $script
    }
}

Write-Host "Fase 4 completata."
