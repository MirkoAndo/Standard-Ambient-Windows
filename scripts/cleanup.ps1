# Requires -Version 5.1
param(
    [switch]$IncludeSystemTemp
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Clear-Path {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        return
    }

    Get-ChildItem -Path $Path -Force -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            if ($_.PSIsContainer) {
                Remove-Item -Path $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
            } else {
                Remove-Item -Path $_.FullName -Force -ErrorAction SilentlyContinue
            }
        } catch {
            Write-Warning "Impossibile rimuovere: $($_.FullName)"
        }
    }
}

try {
    Clear-Path -Path $env:TEMP
    Clear-Path -Path $env:TMP

    if ($IncludeSystemTemp) {
        Clear-Path -Path (Join-Path $env:WINDIR "Temp")
    }

    Write-Host "Cleanup completato."
} catch {
    Write-Error $_
    exit 1
}
