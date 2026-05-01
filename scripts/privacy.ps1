# Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

param(
    [ValidateSet("Disable", "Enable")]
    [string]$AdvertisingId = "Disable",
    [ValidateSet("Disable", "Enable")]
    [string]$ActivityHistory = "Disable",
    [ValidateSet("Required", "Optional", "Full")]
    [string]$DiagnosticData = "Required"
)

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

function Get-TelemetryValue {
    param([string]$Level)

    switch ($Level) {
        "Required" { return 1 }
        "Optional" { return 3 }
        "Full" { return 3 }
        default { return 1 }
    }
}

try {
    Assert-Admin

    if ($AdvertisingId -eq "Disable") {
        Write-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo" -Name "DisabledByGroupPolicy" -Value 1
        Write-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" -Name "Enabled" -Value 0
    } else {
        Write-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo" -Name "DisabledByGroupPolicy" -Value 0
        Write-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" -Name "Enabled" -Value 1
    }

    if ($ActivityHistory -eq "Disable") {
        Write-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "EnableActivityFeed" -Value 0
        Write-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "PublishUserActivities" -Value 0
        Write-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "UploadUserActivities" -Value 0
    } else {
        Write-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "EnableActivityFeed" -Value 1
        Write-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "PublishUserActivities" -Value 1
        Write-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "UploadUserActivities" -Value 1
    }

    $telemetryValue = Get-TelemetryValue -Level $DiagnosticData
    Write-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Value $telemetryValue

    $tailored = if ($DiagnosticData -eq "Required") { 0 } else { 1 }
    Write-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy" -Name "TailoredExperiencesWithDiagnosticDataEnabled" -Value $tailored

    Write-Host "Privacy applicata: AdvertisingId=$AdvertisingId ActivityHistory=$ActivityHistory DiagnosticData=$DiagnosticData"
} catch {
    Write-Error $_
    exit 1
}
