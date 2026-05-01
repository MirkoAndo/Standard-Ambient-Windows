# Requires -Version 5.1
param(
    [ValidateSet(0, 1)]
    [int]$EnableSnap = 1,
    [switch]$RestartExplorer
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-RegistryValue {
    param(
        [string]$Path,
        [string]$Name,
        [object]$Value,
        [Microsoft.Win32.RegistryValueKind]$Type = [Microsoft.Win32.RegistryValueKind]::DWord
    )

    if (-not (Test-Path $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }

    Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type
}

try {
    $advanced = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"

    Write-RegistryValue -Path $advanced -Name "EnableSnapAssistFlyout" -Value $EnableSnap
    Write-RegistryValue -Path $advanced -Name "EnableSnapBar" -Value $EnableSnap
    Write-RegistryValue -Path $advanced -Name "EnableWindowSnapAssist" -Value $EnableSnap
    Write-RegistryValue -Path $advanced -Name "SnapAssist" -Value $EnableSnap

    Write-Host "Snap Layouts: " + ($(if ($EnableSnap -eq 1) { "abilitato" } else { "disabilitato" }))

    if ($RestartExplorer) {
        Get-Process explorer -ErrorAction SilentlyContinue | Stop-Process -Force
        Start-Process explorer.exe
    }
} catch {
    Write-Error $_
    exit 1
}
