# Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

param(
    [switch]$SkipTheme,
    [switch]$SkipTaskbar,
    [switch]$SkipExplorer,
    [switch]$SkipNotifications,
    [switch]$SkipWallpaper,
    [switch]$SkipWindhawk,
    [switch]$RestartExplorer
)

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

if (-not $SkipTheme) {
    Invoke-Step -Name "Tema e colori" -Action {
        $script = Join-Path $scriptsRoot "theme.ps1"
        if (-not (Test-Path $script)) {
            throw "Script non trovato: $script"
        }
        & $script -RestartExplorer:$RestartExplorer
    }
}

if (-not $SkipTaskbar) {
    Invoke-Step -Name "Taskbar" -Action {
        $script = Join-Path $scriptsRoot "taskbar.ps1"
        if (-not (Test-Path $script)) {
            throw "Script non trovato: $script"
        }
        & $script -RestartExplorer:$RestartExplorer
    }
}

if (-not $SkipExplorer) {
    Invoke-Step -Name "Explorer" -Action {
        $script = Join-Path $scriptsRoot "explorer.ps1"
        if (-not (Test-Path $script)) {
            throw "Script non trovato: $script"
        }
        & $script -RestartExplorer:$RestartExplorer
    }
}

if (-not $SkipNotifications) {
    Invoke-Step -Name "Notifiche" -Action {
        $script = Join-Path $scriptsRoot "notifications.ps1"
        if (-not (Test-Path $script)) {
            throw "Script non trovato: $script"
        }
        & $script
    }
}

if (-not $SkipWallpaper) {
    Invoke-Step -Name "Wallpaper" -Action {
        $script = Join-Path $scriptsRoot "wallpaper.ps1"
        if (-not (Test-Path $script)) {
            throw "Script non trovato: $script"
        }
        & $script
    }
}

if (-not $SkipWindhawk) {
    Invoke-Step -Name "Windhawk" -Action {
        $script = Join-Path $scriptsRoot "windhawk.ps1"
        if (-not (Test-Path $script)) {
            throw "Script non trovato: $script"
        }
        & $script
    }
}

Write-Host "Fase 1 completata. Riavvia Explorer o fai logout/login se necessario."
