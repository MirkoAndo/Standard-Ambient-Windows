# Requires -Version 5.1
param(
    [switch]$DryRun,
    [switch]$SetFont,
    [string]$FontFace = "Cascadia Code",
    [switch]$Backup
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-SettingsPath {
    $paths = @(
        Join-Path $env:LOCALAPPDATA "Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
        Join-Path $env:LOCALAPPDATA "Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json"
    )

    foreach ($path in $paths) {
        if (Test-Path $path) {
            return $path
        }
    }

    return $null
}

try {
    $settingsPath = Get-SettingsPath
    if (-not $settingsPath) {
        throw "settings.json di Windows Terminal non trovato. Avvia Windows Terminal una volta."
    }

    if ($Backup -and (Test-Path $settingsPath)) {
        $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
        Copy-Item -Path $settingsPath -Destination ($settingsPath + ".bak." + $stamp) -Force
    }

    $json = Get-Content $settingsPath -Raw | ConvertFrom-Json

    $json.copyOnSelect = $true
    $json.trimBlockSelection = $true
    $json.alwaysShowTabs = $true

    if ($SetFont) {
        if (-not $json.profiles) {
            $json | Add-Member -MemberType NoteProperty -Name "profiles" -Value ([pscustomobject]@{})
        }
        if (-not $json.profiles.defaults) {
            $json.profiles | Add-Member -MemberType NoteProperty -Name "defaults" -Value ([pscustomobject]@{})
        }
        $json.profiles.defaults.font = [pscustomobject]@{ face = $FontFace }
    }

    if ($DryRun) {
        Write-Host "[DryRun] Aggiornamento settings.json: $settingsPath"
    } else {
        $json | ConvertTo-Json -Depth 12 | Set-Content -Path $settingsPath -Encoding UTF8
        Write-Host "Windows Terminal aggiornato: $settingsPath"
    }
} catch {
    Write-Error $_
    exit 1
}
