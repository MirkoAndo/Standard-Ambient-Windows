# Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

param(
    [string]$ConfigPath = (Join-Path $PSScriptRoot "..\config\settings\windhawk.json"),
    [string]$WindhawkModsPath,
    [switch]$DryRun
)

function Resolve-WindhawkModsPath {
    param([string]$ExplicitPath)

    if ($ExplicitPath) {
        return $ExplicitPath
    }

    $candidates = @(
        (Join-Path $env:APPDATA "Windhawk\mods"),
        (Join-Path $env:LOCALAPPDATA "Windhawk\mods"),
        (Join-Path $env:ProgramData "Windhawk\mods")
    )

    foreach ($path in $candidates) {
        if ($path -and (Test-Path $path)) {
            return $path
        }
    }

    throw "Percorso mod Windhawk non trovato. Specifica -WindhawkModsPath."
}

if (-not (Test-Path $ConfigPath)) {
    throw "Config non trovata: $ConfigPath"
}

$windhawkConfig = Get-Content $ConfigPath | ConvertFrom-Json
if (-not $windhawkConfig.mods) {
    throw "Chiave 'mods' mancante nel config: $ConfigPath"
}

$modsPath = Resolve-WindhawkModsPath -ExplicitPath $WindhawkModsPath

foreach ($modName in $windhawkConfig.mods.PSObject.Properties.Name) {
    $modSettings = $windhawkConfig.mods.$modName
    $modDir = Join-Path $modsPath $modName
    $settingsPath = Join-Path $modDir "settings.json"

    if (-not (Test-Path $modDir)) {
        if ($DryRun) {
            Write-Host "[DryRun] Creazione cartella mod: $modDir"
        } else {
            New-Item -ItemType Directory -Path $modDir -Force | Out-Null
        }
    }

    if (Test-Path $settingsPath) {
        $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $backupPath = Join-Path $modDir ("settings.json.bak." + $stamp)
        if ($DryRun) {
            Write-Host "[DryRun] Backup: $settingsPath -> $backupPath"
        } else {
            Copy-Item -Path $settingsPath -Destination $backupPath -Force
        }
    }

    $json = $modSettings | ConvertTo-Json -Depth 12
    if ($DryRun) {
        Write-Host "[DryRun] Scrittura settings per mod: $modName"
    } else {
        $json | Set-Content -Path $settingsPath -Encoding UTF8
        Write-Host "Impostazioni applicate: $modName"
    }
}

Write-Host "Completato. Riavvia Explorer o Windhawk per applicare."