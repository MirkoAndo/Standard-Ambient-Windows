# Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

param(
    [string]$ConfigPath = (Join-Path $PSScriptRoot "..\config\settings\taskbar.json"),
    [ValidateSet("Center", "Left")]
    [string]$Alignment = "Center",
    [switch]$RestartExplorer
)

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
        throw "Impossibile impostare $Path\\$Name: $($_.Exception.Message)"
    }
}

try {
    $config = Read-Config -Path $ConfigPath
    if ($config) {
        if (-not $PSBoundParameters.ContainsKey("Alignment") -and $config.alignment) {
            $Alignment = $config.alignment
        }
        if (-not $PSBoundParameters.ContainsKey("RestartExplorer") -and $null -ne $config.restartExplorer) {
            if ($config.restartExplorer) {
                $RestartExplorer = $true
            }
        }
    }

    $advanced = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    $value = if ($Alignment -eq "Center") { 1 } else { 0 }

    Write-RegistryValue -Path $advanced -Name "TaskbarAl" -Value $value
    Write-Host "Taskbar allineata: $Alignment"

    if ($RestartExplorer) {
        Get-Process explorer -ErrorAction SilentlyContinue | Stop-Process -Force
        Start-Process explorer.exe
    }
} catch {
    Write-Error $_
    exit 1
}
