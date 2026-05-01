# Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

param(
    [string]$ConfigPath = (Join-Path $PSScriptRoot "..\config\packages.json"),
    [string[]]$Profiles = @("base"),
    [switch]$DryRun,
    [switch]$Silent,
    [switch]$Interactive,
    [string]$LogDir = (Join-Path $PSScriptRoot "..\logs")
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
        throw "Config non trovata: $resolvedPath"
    }

    return (Get-Content $resolvedPath | ConvertFrom-Json)
}

function Write-Log {
    param([string]$Message)

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$timestamp] $Message"
    Write-Host $line
    if ($script:LogFile) {
        Add-Content -Path $script:LogFile -Value $line
    }
}

try {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw "winget non trovato. Installa App Installer dal Microsoft Store."
    }

    if (-not (Test-Path $LogDir)) {
        New-Item -ItemType Directory -Path $LogDir | Out-Null
    }
    $script:LogFile = Join-Path $LogDir ("phase2-install-" + (Get-Date -Format "yyyyMMdd-HHmmss") + ".log")

    $config = Read-Config -Path $ConfigPath
    if (-not $config.profiles) {
        throw "Sezione 'profiles' mancante in packages.json"
    }

    $selected = @()
    foreach ($profile in $Profiles) {
        if (-not $config.profiles.PSObject.Properties.Name.Contains($profile)) {
            throw "Profilo non trovato: $profile"
        }
        $selected += $config.profiles.$profile.winget
    }

    $packages = $selected | Where-Object { $_ } | Sort-Object -Unique
    if ($packages.Count -eq 0) {
        Write-Log "Nessun pacchetto da installare"
        exit 0
    }

    Write-Log ("Profili: " + ($Profiles -join ", "))
    Write-Log ("Pacchetti: " + ($packages -join ", "))

    if (-not $Silent -and -not $Interactive) {
        $Interactive = $true
    }

    foreach ($pkg in $packages) {
        if ($DryRun) {
            $modeLabel = if ($Silent) { "--silent" } elseif ($Interactive) { "--interactive" } else { "" }
            Write-Log "[DryRun] winget install --id $pkg $modeLabel"
            continue
        }

        $args = @("install", "--id", $pkg, "-e", "--accept-package-agreements", "--accept-source-agreements")
        if ($Silent) {
            $args += "--silent"
        } elseif ($Interactive) {
            $args += "--interactive"
        }

        Write-Log "Installazione: $pkg"
        & winget @args
        if ($LASTEXITCODE -ne 0) {
            Write-Log "Errore installazione ($LASTEXITCODE): $pkg"
        } else {
            Write-Log "Installato: $pkg"
        }
    }
} catch {
    Write-Error $_
    exit 1
}
