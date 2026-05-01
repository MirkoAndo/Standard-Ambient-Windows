# Requires -Version 5.1
param(
    [ValidateSet("Default", "ManualDownload")]
    [string]$Mode = "ManualDownload"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Assert-Admin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Warning "Impossibile continuare: avvia PowerShell come amministratore."
        exit 1
    }
}

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

function Remove-RegistryValue {
    param(
        [string]$Path,
        [string]$Name
    )

    if (Test-Path $Path) {
        $current = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
        if ($null -ne $current) {
            Remove-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
        }
    }
}

try {
    Assert-Admin

    $wuBase = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
    $au = Join-Path $wuBase "AU"

    if ($Mode -eq "ManualDownload") {
        Write-RegistryValue -Path $au -Name "AUOptions" -Value 2
        Write-RegistryValue -Path $au -Name "NoAutoUpdate" -Value 0
        Write-Host "Windows Update: download manuale"
    } else {
        Remove-RegistryValue -Path $au -Name "AUOptions"
        Remove-RegistryValue -Path $au -Name "NoAutoUpdate"
        Write-Host "Windows Update: default"
    }
} catch {
    Write-Error $_
    exit 1
}
