# Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

param(
    [string]$ConfigPath = (Join-Path $PSScriptRoot "..\config\settings\wallpaper.json"),
    [ValidateSet("Auto", "Light", "Dark")]
    [string]$Mode = "Auto",
    [ValidateSet("Fill", "Fit", "Stretch", "Tile", "Center", "Span")]
    [string]$Style = "Fill",
    [string]$LightPath,
    [string]$DarkPath,
    [string]$LightLockScreenPath,
    [string]$DarkLockScreenPath,
    [switch]$ApplyLockScreen
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

function Get-ThemeMode {
    $personalize = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
    $appsLight = (Get-ItemProperty -Path $personalize -Name "AppsUseLightTheme" -ErrorAction SilentlyContinue).AppsUseLightTheme
    if ($appsLight -eq 0) { return "Dark" }
    return "Light"
}

function Set-WallpaperStyle {
    param([string]$StyleName)

    $desktopKey = "HKCU:\Control Panel\Desktop"
    switch ($StyleName) {
        "Fill" { Set-ItemProperty $desktopKey -Name "WallpaperStyle" -Value "10"; Set-ItemProperty $desktopKey -Name "TileWallpaper" -Value "0" }
        "Fit" { Set-ItemProperty $desktopKey -Name "WallpaperStyle" -Value "6"; Set-ItemProperty $desktopKey -Name "TileWallpaper" -Value "0" }
        "Stretch" { Set-ItemProperty $desktopKey -Name "WallpaperStyle" -Value "2"; Set-ItemProperty $desktopKey -Name "TileWallpaper" -Value "0" }
        "Tile" { Set-ItemProperty $desktopKey -Name "WallpaperStyle" -Value "0"; Set-ItemProperty $desktopKey -Name "TileWallpaper" -Value "1" }
        "Center" { Set-ItemProperty $desktopKey -Name "WallpaperStyle" -Value "0"; Set-ItemProperty $desktopKey -Name "TileWallpaper" -Value "0" }
        "Span" { Set-ItemProperty $desktopKey -Name "WallpaperStyle" -Value "22"; Set-ItemProperty $desktopKey -Name "TileWallpaper" -Value "0" }
    }
}

function Set-Wallpaper {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        throw "Wallpaper non trovato: $Path"
    }

    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class WallpaperNative {
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
"@

    $SPI_SETDESKWALLPAPER = 20
    $SPIF_UPDATEINIFILE = 0x01
    $SPIF_SENDCHANGE = 0x02
    [WallpaperNative]::SystemParametersInfo($SPI_SETDESKWALLPAPER, 0, $Path, $SPIF_UPDATEINIFILE -bor $SPIF_SENDCHANGE) | Out-Null
}

function Set-LockScreenImage {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        throw "Lock screen image non trovata: $Path"
    }

    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Warning "Lock screen richiede privilegi amministrativi. Esegui PowerShell come amministratore."
        return
    }

    $key = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization"
    if (-not (Test-Path $key)) {
        New-Item -Path $key -Force | Out-Null
    }

    Set-ItemProperty -Path $key -Name "LockScreenImage" -Value $Path
    Set-ItemProperty -Path $key -Name "LockScreenImageStatus" -Value 1 -Type DWord
}

$config = Read-Config -Path $ConfigPath

if ($config) {
    if (-not $PSBoundParameters.ContainsKey("Mode") -and $config.mode) {
        $Mode = $config.mode
    }
    if (-not $PSBoundParameters.ContainsKey("Style") -and $config.style) {
        $Style = $config.style
    }
    if (-not $PSBoundParameters.ContainsKey("LightPath") -and $config.light.wallpaper) {
        $LightPath = Resolve-ConfigPath -Path $config.light.wallpaper
    }
    if (-not $PSBoundParameters.ContainsKey("DarkPath") -and $config.dark.wallpaper) {
        $DarkPath = Resolve-ConfigPath -Path $config.dark.wallpaper
    }
    if (-not $PSBoundParameters.ContainsKey("LightLockScreenPath") -and $config.light.lockScreen) {
        $LightLockScreenPath = Resolve-ConfigPath -Path $config.light.lockScreen
    }
    if (-not $PSBoundParameters.ContainsKey("DarkLockScreenPath") -and $config.dark.lockScreen) {
        $DarkLockScreenPath = Resolve-ConfigPath -Path $config.dark.lockScreen
    }
    if (-not $PSBoundParameters.ContainsKey("ApplyLockScreen") -and $null -ne $config.applyLockScreen) {
        if ($config.applyLockScreen) {
            $ApplyLockScreen = $true
        }
    }
}

if (-not $LightPath) {
    $LightPath = Join-Path $PSScriptRoot "..\assets\wallpapers\light.jpg"
}

if (-not $DarkPath) {
    $DarkPath = Join-Path $PSScriptRoot "..\assets\wallpapers\dark.jpg"
}

if ($Mode -eq "Auto") {
    $Mode = Get-ThemeMode
}

$selectedPath = if ($Mode -eq "Dark") { $DarkPath } else { $LightPath }
$selectedLockScreenPath = if ($Mode -eq "Dark") { $DarkLockScreenPath } else { $LightLockScreenPath }

Set-WallpaperStyle -StyleName $Style
Set-Wallpaper -Path $selectedPath

if ($ApplyLockScreen -and $selectedLockScreenPath) {
    Set-LockScreenImage -Path $selectedLockScreenPath
}

Write-Host "Wallpaper applicato: $Mode -> $selectedPath"
