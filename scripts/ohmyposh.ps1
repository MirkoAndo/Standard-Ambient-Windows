# Requires -Version 5.1
param(
    [string]$Theme = "atomicBit",
    [ValidateSet("WindowsPowerShell", "PowerShell7", "Both")]
    [string]$Shell = "Both",
    [switch]$InstallIfMissing,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Ensure-OhMyPosh {
    if (Get-Command "oh-my-posh" -ErrorAction SilentlyContinue) {
        return $true
    }

    if (-not $InstallIfMissing) {
        return $false
    }

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw "winget non trovato. Impossibile installare Oh My Posh."
    }

    if ($DryRun) {
        Write-Host "[DryRun] winget install --id JanDeDobbeleer.OhMyPosh"
        return $true
    }

    & winget install --id JanDeDobbeleer.OhMyPosh -e --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -ne 0) {
        throw "Installazione Oh My Posh fallita ($LASTEXITCODE)"
    }

    return $true
}

function Get-ProfilePath {
    param([string]$ShellName)

    switch ($ShellName) {
        "WindowsPowerShell" { return Join-Path $env:USERPROFILE "Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1" }
        "PowerShell7" { return Join-Path $env:USERPROFILE "Documents\PowerShell\Microsoft.PowerShell_profile.ps1" }
    }
}

function Ensure-ProfileLine {
    param(
        [string]$ProfilePath,
        [string]$Line
    )

    $dir = Split-Path -Parent $ProfilePath
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    if (-not (Test-Path $ProfilePath)) {
        New-Item -ItemType File -Path $ProfilePath -Force | Out-Null
    }

    $content = Get-Content $ProfilePath -Raw
    if ($content -match [regex]::Escape($Line)) {
        return $false
    }

    if ($DryRun) {
        Write-Host "[DryRun] Aggiorna profilo: $ProfilePath"
        return $true
    }

    Add-Content -Path $ProfilePath -Value ("`n" + $Line)
    return $true
}

try {
    $installed = Ensure-OhMyPosh
    if (-not $installed) {
        throw "Oh My Posh non installato. Usa -InstallIfMissing per installare."
    }

    $themePath = Join-Path $env:POSH_THEMES_PATH ("$Theme.omp.json")
    $configLine = "oh-my-posh init pwsh --config `"$themePath`" | Invoke-Expression"
    $targets = @()

    switch ($Shell) {
        "WindowsPowerShell" { $targets += "WindowsPowerShell" }
        "PowerShell7" { $targets += "PowerShell7" }
        "Both" { $targets += "WindowsPowerShell", "PowerShell7" }
    }

    foreach ($target in $targets) {
        $profilePath = Get-ProfilePath -ShellName $target
        $changed = Ensure-ProfileLine -ProfilePath $profilePath -Line $configLine
        if ($changed) {
            Write-Host "Profilo aggiornato: $profilePath"
        } else {
            Write-Host "Profilo gia configurato: $profilePath"
        }
    }
} catch {
    Write-Error $_
    exit 1
}
