# Requires -Version 5.1
param(
    [string]$LogPath = (Join-Path $PSScriptRoot "..\log.txt")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Initialize-Log {
    param([string]$Path)

    if (-not $Path) {
        return
    }

    Set-Content -Path $Path -Value "" -Encoding UTF8
}

function Write-Log {
    param([string]$Message)

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$timestamp] $Message"
    Write-Host $line
    if ($LogPath) {
        Add-Content -Path $LogPath -Value $line
    }
}

function Write-Section {
    param([string]$Title)
    Write-Log ""
    Write-Log "=== $Title ==="
}

function Ask-YesNo {
    param([string]$Prompt, [bool]$Default = $true)

    $suffix = if ($Default) { "[Y/n]" } else { "[y/N]" }
    $answer = Read-Host "$Prompt $suffix"
    if ([string]::IsNullOrWhiteSpace($answer)) {
        return $Default
    }
    return $answer.Trim().ToLower() -in @("y", "yes")
}

function Ask-List {
    param([string]$Prompt, [string]$Default)

    $answer = Read-Host "$Prompt (default: $Default)"
    if ([string]::IsNullOrWhiteSpace($answer)) {
        return $Default
    }
    return $answer
}

function Ask-Choice {
    param(
        [string]$Prompt,
        [string[]]$Options,
        [int]$DefaultIndex = 0
    )

    $list = ($Options | ForEach-Object { "- $_" }) -join "`n"
    Write-Host $list
    $defaultValue = $Options[$DefaultIndex]
    $answer = Read-Host "$Prompt (default: $defaultValue)"
    if ([string]::IsNullOrWhiteSpace($answer)) {
        return $defaultValue
    }

    return $answer
}

function Assert-Admin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Assert-Prerequisites {
    param(
        [bool]$NeedsWinget,
        [bool]$NeedsAdmin
    )

    if ($NeedsWinget -and -not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw "winget non trovato. Installa App Installer dal Microsoft Store."
    }

    if ($NeedsAdmin -and -not (Assert-Admin)) {
        throw "Questo wizard richiede PowerShell avviato come amministratore per le fasi selezionate."
    }
}

$root = Split-Path -Parent $PSScriptRoot

Initialize-Log -Path $LogPath
Write-Log "Wizard avviato"

Write-Section -Title "Standard Ambient Wizard"

$runPhase1 = Ask-YesNo -Prompt "Eseguire Fase 1 (UI/comfort)?" -Default $true
$runPhase2 = Ask-YesNo -Prompt "Eseguire Fase 2 (installazioni)?" -Default $true
$runPhase3 = Ask-YesNo -Prompt "Eseguire Fase 3 (sistema)?" -Default $false
$runPhase4 = Ask-YesNo -Prompt "Eseguire Fase 4 (produttivita)?" -Default $false
$runPhase5 = Ask-YesNo -Prompt "Eseguire Fase 5 (backup)?" -Default $false

$dryRun = Ask-YesNo -Prompt "Eseguire in modalita DryRun?" -Default $false

$profiles = "base"
$interactive = $true
if ($runPhase2) {
    $preset = Ask-Choice -Prompt "Preset fase 2 (Base/Dev/Gaming/Custom)" -Options @("Base", "Dev", "Gaming", "Custom") -DefaultIndex 0
    switch ($preset.ToLower()) {
        "base" { $profiles = "base" }
        "dev" { $profiles = "base,dev" }
        "gaming" { $profiles = "base,gaming" }
        default { $profiles = Ask-List -Prompt "Profili fase 2 (separati da virgola)" -Default "base,dev" }
    }
    $interactive = Ask-YesNo -Prompt "Installer interattivi (finestre visibili)?" -Default $true
}

$includeAllUsersStartMenu = $false
if ($runPhase4) {
    $includeAllUsersStartMenu = Ask-YesNo -Prompt "Organizzare Start Menu per tutti gli utenti?" -Default $false
}

Write-Log ("Scelte: F1=$runPhase1 F2=$runPhase2 F3=$runPhase3 F4=$runPhase4 F5=$runPhase5 DryRun=$dryRun")
if ($runPhase2) {
    Write-Log ("Profili fase 2: $profiles | Interattivo=$interactive")
}
if ($runPhase4) {
    Write-Log ("Start Menu all users: $includeAllUsersStartMenu")
}

Write-Section -Title "Esecuzione"

$needsWinget = $runPhase2 -or $runPhase4
$needsAdmin = $runPhase3
Assert-Prerequisites -NeedsWinget:$needsWinget -NeedsAdmin:$needsAdmin

try {
    if ($runPhase1) {
        & (Join-Path $PSScriptRoot "phases\phase1.ps1")
    }

    if ($runPhase2) {
        $profileList = $profiles.Split(",") | ForEach-Object { $_.Trim() } | Where-Object { $_ }
        $args = @("-Profiles", ($profileList -join ","))
        if ($dryRun) { $args += "-DryRun" }
        if ($interactive) { $args += "-Interactive" } else { $args += "-Silent" }
        & (Join-Path $PSScriptRoot "phases\phase2.ps1") @args
    }

    if ($runPhase3) {
        & (Join-Path $PSScriptRoot "phases\phase3.ps1")
    }

    if ($runPhase4) {
        $args = @()
        if ($includeAllUsersStartMenu) { $args += "-IncludeAllUsersStartMenu" }
        & (Join-Path $PSScriptRoot "phases\phase4.ps1") @args
    }

    if ($runPhase5) {
        $args = @()
        if ($dryRun) { $args += "-DryRun" }
        & (Join-Path $PSScriptRoot "phases\phase5.ps1") @args
    }

    Write-Log "Wizard completato"
} catch {
    Write-Log ("Errore: " + $_.Exception.Message)
    throw
}