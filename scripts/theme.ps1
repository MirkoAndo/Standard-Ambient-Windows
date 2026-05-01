# Requires -Version 5.1
param(
    [string]$ConfigPath = (Join-Path $PSScriptRoot "..\config\settings\theme.json"),
    [ValidateSet("Light", "Dark")]
    [string]$Theme = "Dark",
    [ValidateSet("Default", "Custom")]
    [string]$AccentMode = "Default",
    [string]$AccentRgb = "0,120,215",
    [ValidateSet(0, 1)]
    [int]$ShowAccentOnTaskbar = 1,
    [ValidateSet(0, 1)]
    [int]$ShowAccentOnTitleBars = 1,
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

function Convert-RgbToBgrDword {
    param([string]$Rgb)

    $parts = $Rgb.Split(",") | ForEach-Object { $_.Trim() }
    if ($parts.Count -ne 3) {
        throw "AccentRgb deve essere nel formato R,G,B (es. 0,120,215)"
    }

    $r = [int]$parts[0]
    $g = [int]$parts[1]
    $b = [int]$parts[2]

    foreach ($value in @($r, $g, $b)) {
        if ($value -lt 0 -or $value -gt 255) {
            throw "AccentRgb valori fuori range 0-255: $Rgb"
        }
    }

    $argb = (0xFF -shl 24) -bor ($b -shl 16) -bor ($g -shl 8) -bor $r
    return [uint32]$argb
}

try {
    $config = Read-Config -Path $ConfigPath

    if ($config) {
        if (-not $PSBoundParameters.ContainsKey("Theme") -and $config.theme) {
            $Theme = $config.theme
        }
        if (-not $PSBoundParameters.ContainsKey("AccentMode") -and $config.accentMode) {
            $AccentMode = $config.accentMode
        }
        if (-not $PSBoundParameters.ContainsKey("AccentRgb") -and $config.accentRgb) {
            $AccentRgb = $config.accentRgb
        }
        if (-not $PSBoundParameters.ContainsKey("ShowAccentOnTaskbar") -and $null -ne $config.showAccentOnTaskbar) {
            $ShowAccentOnTaskbar = [int]$config.showAccentOnTaskbar
        }
        if (-not $PSBoundParameters.ContainsKey("ShowAccentOnTitleBars") -and $null -ne $config.showAccentOnTitleBars) {
            $ShowAccentOnTitleBars = [int]$config.showAccentOnTitleBars
        }
        if (-not $PSBoundParameters.ContainsKey("RestartExplorer") -and $null -ne $config.restartExplorer) {
            if ($config.restartExplorer) {
                $RestartExplorer = $true
            }
        }
    }

    $personalize = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
    $lightValue = if ($Theme -eq "Light") { 1 } else { 0 }

    Write-RegistryValue -Path $personalize -Name "AppsUseLightTheme" -Value $lightValue
    Write-RegistryValue -Path $personalize -Name "SystemUsesLightTheme" -Value $lightValue
    Write-RegistryValue -Path $personalize -Name "ColorPrevalence" -Value $ShowAccentOnTaskbar

    $dwm = "HKCU:\Software\Microsoft\Windows\DWM"
    Write-RegistryValue -Path $dwm -Name "ColorPrevalence" -Value $ShowAccentOnTitleBars

    if ($AccentMode -eq "Custom") {
        $color = Convert-RgbToBgrDword -Rgb $AccentRgb
        Write-RegistryValue -Path $dwm -Name "ColorizationColor" -Value $color

        $accent = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Accent"
        Write-RegistryValue -Path $accent -Name "AccentColorMenu" -Value $color
    }

    Write-Host "Tema applicato: $Theme"
    if ($AccentMode -eq "Custom") {
        Write-Host "Accento personalizzato: $AccentRgb"
    }

    if ($RestartExplorer) {
        Get-Process explorer -ErrorAction SilentlyContinue | Stop-Process -Force
        Start-Process explorer.exe
    }
} catch {
    Write-Error $_
    exit 1
}
