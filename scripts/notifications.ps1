# Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

param(
    [string]$ConfigPath = (Join-Path $PSScriptRoot "..\config\settings\notifications.json"),
    [string[]]$AllowedApps,
    [switch]$DisableAllOthers,
    [switch]$EnableGlobalToasts
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

    if (-not (Test-Path $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }

    Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type
}

try {
    $config = Read-Config -Path $ConfigPath
    if ($config) {
        if (-not $PSBoundParameters.ContainsKey("AllowedApps") -and $config.allowedApps) {
            $AllowedApps = @($config.allowedApps)
        }
        if (-not $PSBoundParameters.ContainsKey("DisableAllOthers") -and $null -ne $config.disableAllOthers) {
            if ($config.disableAllOthers) {
                $DisableAllOthers = $true
            }
        }
        if (-not $PSBoundParameters.ContainsKey("EnableGlobalToasts") -and $null -ne $config.enableGlobalToasts) {
            if ($config.enableGlobalToasts) {
                $EnableGlobalToasts = $true
            }
        }
    }

    if (-not $AllowedApps -or $AllowedApps.Count -eq 0) {
        throw "AllowedApps e vuoto. Specifica almeno Windows Defender."
    }

    if ($EnableGlobalToasts) {
        $push = "HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications"
        Write-RegistryValue -Path $push -Name "ToastEnabled" -Value 1

        $notifications = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings"
        Write-RegistryValue -Path $notifications -Name "NOC_GLOBAL_SETTING_TOASTS_ENABLED" -Value 1
    }

    $settingsPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings"
    if (-not (Test-Path $settingsPath)) {
        New-Item -Path $settingsPath -Force | Out-Null
    }

    $allowedSet = @{}
    foreach ($name in $AllowedApps) {
        $allowedSet[$name] = $true
    }

    if ($DisableAllOthers) {
        $subkeys = Get-ChildItem -Path $settingsPath -ErrorAction SilentlyContinue
        foreach ($key in $subkeys) {
            if (-not $allowedSet.ContainsKey($key.PSChildName)) {
                Write-RegistryValue -Path $key.PSPath -Name "Enabled" -Value 0
            }
        }
    }

    foreach ($name in $AllowedApps) {
        $appKey = Join-Path $settingsPath $name
        if (-not (Test-Path $appKey)) {
            Write-Warning "Chiave notifica non trovata: $name"
            continue
        }
        Write-RegistryValue -Path $appKey -Name "Enabled" -Value 1
    }

    Write-Host "Notifiche aggiornate. Consentite: $($AllowedApps -join ", ")"
} catch {
    Write-Error $_
    exit 1
}
