# Requires -Version 5.1
param(
    [string]$ConfigPath = (Join-Path $PSScriptRoot "..\config\settings\explorer.json"),
    [ValidateSet(0, 1)]
    [int]$ShowFileExtensions = 1,
    [ValidateSet(0, 1)]
    [int]$ShowHiddenFiles = 1,
    [ValidateSet(0, 1)]
    [int]$ShowProtectedOsFiles = 0,
    [switch]$RestartExplorer
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot

function Resolve-ConfigPath {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $Path
    }

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return $Path
    }

    return (Join-Path $root $Path)
}

function Read-Config {
    param([string]$Path)

    $resolvedPath = Resolve-ConfigPath -Path $Path
    if (-not (Test-Path $resolvedPath)) {
        return $null
    }

    return (Get-Content $resolvedPath | ConvertFrom-Json)
}

function Write-RegistryValue {
    param(
        [string]$Path,
        [string]$Name,
        [object]$Value,
        [Microsoft.Win32.RegistryValueKind]$Type = [Microsoft.Win32.RegistryValueKind]::DWord
    )

    try {
        if (-not (Test-Path $Path)) {
            New-Item -Path $Path -Force | Out-Null
        }
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type
    } catch {
        throw "Impossibile impostare $Path\\${Name}: $($_.Exception.Message)"
    }
}

try {
    $config = Read-Config -Path $ConfigPath
    if ($config) {
        if (-not $PSBoundParameters.ContainsKey("ShowFileExtensions") -and $null -ne $config.showFileExtensions) {
            $ShowFileExtensions = [int]$config.showFileExtensions
        }
        if (-not $PSBoundParameters.ContainsKey("ShowHiddenFiles") -and $null -ne $config.showHiddenFiles) {
            $ShowHiddenFiles = [int]$config.showHiddenFiles
        }
        if (-not $PSBoundParameters.ContainsKey("ShowProtectedOsFiles") -and $null -ne $config.showProtectedOsFiles) {
            $ShowProtectedOsFiles = [int]$config.showProtectedOsFiles
        }
        if (-not $PSBoundParameters.ContainsKey("RestartExplorer") -and $null -ne $config.restartExplorer) {
            if ($config.restartExplorer) {
                $RestartExplorer = $true
            }
        }
    }

    $advanced = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"

    $hideExt = if ($ShowFileExtensions -eq 1) { 0 } else { 1 }
    Write-RegistryValue -Path $advanced -Name "HideFileExt" -Value $hideExt

    $hidden = if ($ShowHiddenFiles -eq 1) { 1 } else { 2 }
    Write-RegistryValue -Path $advanced -Name "Hidden" -Value $hidden

    $superHidden = if ($ShowProtectedOsFiles -eq 1) { 1 } else { 0 }
    Write-RegistryValue -Path $advanced -Name "ShowSuperHidden" -Value $superHidden

    Write-Host "Explorer aggiornato: estensioni=$ShowFileExtensions nascosti=$ShowHiddenFiles protetti=$ShowProtectedOsFiles"

    if ($RestartExplorer) {
        Get-Process explorer -ErrorAction SilentlyContinue | Stop-Process -Force
        Start-Process explorer.exe
    }
} catch {
    Write-Error $_
    exit 1
}
