# Requires -Version 5.1
param(
    [string]$ConfigPath = (Join-Path $PSScriptRoot "..\config\settings\backup.json"),
    [switch]$DryRun,
    [switch]$NoZip,
    [switch]$NoWingetExport,
    [switch]$NoRegistryExport
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
        throw "Config non trovata: $resolvedPath"
    }

    return (Get-Content $resolvedPath | ConvertFrom-Json)
}

function Ensure-Dir {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path | Out-Null
    }
}

function Sanitize-FileName {
    param([string]$Value)

    return ($Value -replace '[\\/:*?"<>|]', "_")
}

try {
    $config = Read-Config -Path $ConfigPath
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

    $outputRoot = [Environment]::ExpandEnvironmentVariables($config.outputRoot)
    if ([string]::IsNullOrWhiteSpace($outputRoot)) {
        throw "outputRoot non valido in config"
    }

    $backupDir = Join-Path $outputRoot ("backup-" + $timestamp)

    if ($DryRun) {
        Write-Host "[DryRun] Backup dir: $backupDir"
    } else {
        Ensure-Dir -Path $backupDir
    }

    $includePaths = @($config.includePaths)
    foreach ($rel in $includePaths) {
        $source = Resolve-ConfigPath -Path $rel
        if (-not (Test-Path $source)) {
            Write-Warning "Percorso non trovato: $source"
            continue
        }

        $dest = Join-Path $backupDir (Split-Path $source -Leaf)
        if ($DryRun) {
            Write-Host "[DryRun] Copia: $source -> $dest"
        } else {
            Copy-Item -Path $source -Destination $dest -Recurse -Force
        }
    }

    $wingetExportFile = $null
    if ($config.wingetExport -and -not $NoWingetExport) {
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            $wingetExportFile = Join-Path $backupDir "winget-export.json"
            if ($DryRun) {
                Write-Host "[DryRun] winget export -o $wingetExportFile"
            } else {
                & winget export -o $wingetExportFile --accept-source-agreements
            }
        } else {
            Write-Warning "winget non trovato, export pacchetti saltato"
        }
    }

    $registryFiles = @()
    if ($config.registryExports -and -not $NoRegistryExport) {
        foreach ($key in $config.registryExports) {
            $safeName = Sanitize-FileName -Value $key
            $regFile = Join-Path $backupDir ("reg-" + $safeName + ".reg")
            if ($DryRun) {
                Write-Host "[DryRun] reg export $key -> $regFile"
            } else {
                & reg export $key $regFile /y | Out-Null
            }
            $registryFiles += $regFile
        }
    }

    $reportPath = Join-Path $backupDir "report.md"
    if ($config.reportFormat -eq "markdown") {
        $lines = @(
            "# Backup Standard Ambient",
            "",
            "- Timestamp: $timestamp",
            "- Backup dir: $backupDir",
            "- Include: $($includePaths -join ", ")"
        )
        if ($wingetExportFile) {
            $lines += "- Winget export: $wingetExportFile"
        }
        if ($registryFiles.Count -gt 0) {
            $lines += "- Registry: $($registryFiles -join ", ")"
        }

        if ($DryRun) {
            Write-Host "[DryRun] Report: $reportPath"
        } else {
            $lines | Set-Content -Path $reportPath -Encoding UTF8
        }
    }

    $compress = $config.compress
    if ($compress -and -not $NoZip) {
        $zipPath = Join-Path $outputRoot ("backup-" + $timestamp + ".zip")
        if ($DryRun) {
            Write-Host "[DryRun] Compress-Archive $backupDir -> $zipPath"
        } else {
            Compress-Archive -Path (Join-Path $backupDir "*") -DestinationPath $zipPath -Force
        }
    }

    Write-Host "Backup completato: $backupDir"
} catch {
    Write-Error $_
    exit 1
}
