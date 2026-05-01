# Requires -Version 5.1
param(
    [string]$ConfigPath = (Join-Path $PSScriptRoot "..\config\settings\startmenu.json"),
    [switch]$IncludeAllUsers,
    [switch]$DryRun
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

function Get-StartMenuRoots {
    $roots = @()
    $userRoot = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs"
    if (Test-Path $userRoot) {
        $roots += $userRoot
    }

    if ($IncludeAllUsers) {
        $allRoot = Join-Path $env:ProgramData "Microsoft\Windows\Start Menu\Programs"
        if (Test-Path $allRoot) {
            $roots += $allRoot
        }
    }

    return $roots
}

function Get-Category {
    param([string]$Name, [array]$Map, [string]$DefaultCategory)

    foreach ($entry in $Map) {
        if ($Name -match $entry.Pattern) {
            return $entry.Name
        }
    }

    return $DefaultCategory
}

function Get-UniquePath {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        return $Path
    }

    $dir = Split-Path -Parent $Path
    $name = [System.IO.Path]::GetFileNameWithoutExtension($Path)
    $ext = [System.IO.Path]::GetExtension($Path)

    for ($i = 1; $i -lt 1000; $i++) {
        $candidate = Join-Path $dir ("$name-$i$ext")
        if (-not (Test-Path $candidate)) {
            return $candidate
        }
    }

    throw "Impossibile trovare un nome univoco per $Path"
}

try {
    $roots = Get-StartMenuRoots
    if ($roots.Count -eq 0) {
        throw "Nessun percorso Start Menu trovato"
    }

    $config = Read-Config -Path $ConfigPath
    if (-not $config -or -not $config.categories) {
        throw "Config categorie non trovata o vuota: $ConfigPath"
    }
    $map = @()
    foreach ($entry in $config.categories) {
        $map += @{ Name = $entry.name; Pattern = $entry.pattern }
    }
    $defaultCategory = if ($config.defaultCategory) { $config.defaultCategory } else { "Other" }

    foreach ($root in $roots) {
        $links = Get-ChildItem -Path $root -Recurse -Filter "*.lnk" -ErrorAction SilentlyContinue
        foreach ($link in $links) {
            $category = Get-Category -Name $link.Name -Map $map -DefaultCategory $defaultCategory
            $targetDir = Join-Path $root $category

            if ($link.DirectoryName -eq $targetDir) {
                continue
            }

            if (-not (Test-Path $targetDir)) {
                if ($DryRun) {
                    Write-Host "[DryRun] Crea cartella: $targetDir"
                } else {
                    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
                }
            }

            $targetPath = Join-Path $targetDir $link.Name
            $targetPath = Get-UniquePath -Path $targetPath

            if ($DryRun) {
                Write-Host "[DryRun] Sposta: $($link.FullName) -> $targetPath"
            } else {
                Move-Item -Path $link.FullName -Destination $targetPath -Force
            }
        }
    }

    Write-Host "Start Menu organizzato."
} catch {
    Write-Error $_
    exit 1
}
