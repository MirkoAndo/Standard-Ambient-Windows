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
# SIG # Begin signature block
# MIIb+wYJKoZIhvcNAQcCoIIb7DCCG+gCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU0+Tpco0Euey/eeZvkHwwAGWo
# PuKgghZeMIIDIDCCAgigAwIBAgIQXBB2paUpbYVHWuvLA+RWZzANBgkqhkiG9w0B
# AQsFADAoMSYwJAYDVQQDDB1TdGFuZGFyZCBBbWJpZW50IENvZGUgU2lnbmluZzAe
# Fw0yNjA1MDExMTA3MjVaFw0yNzA1MDExMTI3MjVaMCgxJjAkBgNVBAMMHVN0YW5k
# YXJkIEFtYmllbnQgQ29kZSBTaWduaW5nMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8A
# MIIBCgKCAQEAu81BVQ8OttDrzZDhGXdJfBGkrB2tz4VBz9fXqV5MZPlqwObsaRTg
# OAUtZkod82ytePzwsmmG97WulL3L6tiXIG+u+FGhHD1I3Uim4KRk7RjMpR+MSGFM
# mQTywhYYCip8wjhEU5mCwkM1neb6zZfZHY8Ub+4KIzrslZPWxAs+CkJY1lVHKtg/
# C+A9i3y5evpcgCsxuwgQJ1SSurT1AAambbOJ0DNV8OqnvqZ7RA2ASr2qFhmCzGT8
# 5gOKPTtnShtia4Fihgndu8DnYupkA05pToXi+OftbAJEfwvp1OFRI9dp79ULmhRe
# ejZ6PgCc9NmowFbVczYBlj03BPfy8pP1zQIDAQABo0YwRDAOBgNVHQ8BAf8EBAMC
# B4AwEwYDVR0lBAwwCgYIKwYBBQUHAwMwHQYDVR0OBBYEFB1WCcPrU3S+rgZbvcOF
# X5uNtmo9MA0GCSqGSIb3DQEBCwUAA4IBAQADAj4zPAjs4fJ3PzUPldGk0vrmEP8L
# XejLykMCQ15sH0i7LEz2bHYJ+wDD0kiHXLEAvRpAdkPqZJVEPAuieDGScSHqygJr
# t5ikOJFmWUCMBKfKR8F7YXz+jn9gqs8kX3smR1LjvfB5zd3/Q21W8DJU+DmtEzt4
# fDQfb7WeHKYsYTdef04nWaAhRpCFHFqarqxDWrc+SfkLRNRhc8iSsxMJBjJ3UXu/
# 02uVXJSHCOQDVS/CkJsHL3Sbp0m0eIb0w4QWoF/ZZChRU8y8cbuPHroGKxubXFHS
# a/y12aevgjJ0/CLIJ+i4zfPozTMnrm7TwwN0smtejF2gPJjdfp6aDl3MMIIFjTCC
# BHWgAwIBAgIQDpsYjvnQLefv21DiCEAYWjANBgkqhkiG9w0BAQwFADBlMQswCQYD
# VQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGln
# aWNlcnQuY29tMSQwIgYDVQQDExtEaWdpQ2VydCBBc3N1cmVkIElEIFJvb3QgQ0Ew
# HhcNMjIwODAxMDAwMDAwWhcNMzExMTA5MjM1OTU5WjBiMQswCQYDVQQGEwJVUzEV
# MBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29t
# MSEwHwYDVQQDExhEaWdpQ2VydCBUcnVzdGVkIFJvb3QgRzQwggIiMA0GCSqGSIb3
# DQEBAQUAA4ICDwAwggIKAoICAQC/5pBzaN675F1KPDAiMGkz7MKnJS7JIT3yithZ
# wuEppz1Yq3aaza57G4QNxDAf8xukOBbrVsaXbR2rsnnyyhHS5F/WBTxSD1Ifxp4V
# pX6+n6lXFllVcq9ok3DCsrp1mWpzMpTREEQQLt+C8weE5nQ7bXHiLQwb7iDVySAd
# YyktzuxeTsiT+CFhmzTrBcZe7FsavOvJz82sNEBfsXpm7nfISKhmV1efVFiODCu3
# T6cw2Vbuyntd463JT17lNecxy9qTXtyOj4DatpGYQJB5w3jHtrHEtWoYOAMQjdjU
# N6QuBX2I9YI+EJFwq1WCQTLX2wRzKm6RAXwhTNS8rhsDdV14Ztk6MUSaM0C/CNda
# SaTC5qmgZ92kJ7yhTzm1EVgX9yRcRo9k98FpiHaYdj1ZXUJ2h4mXaXpI8OCiEhtm
# mnTK3kse5w5jrubU75KSOp493ADkRSWJtppEGSt+wJS00mFt6zPZxd9LBADMfRyV
# w4/3IbKyEbe7f/LVjHAsQWCqsWMYRJUadmJ+9oCw++hkpjPRiQfhvbfmQ6QYuKZ3
# AeEPlAwhHbJUKSWJbOUOUlFHdL4mrLZBdd56rF+NP8m800ERElvlEFDrMcXKchYi
# Cd98THU/Y+whX8QgUWtvsauGi0/C1kVfnSD8oR7FwI+isX4KJpn15GkvmB0t9dmp
# sh3lGwIDAQABo4IBOjCCATYwDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQU7Nfj
# gtJxXWRM3y5nP+e6mK4cD08wHwYDVR0jBBgwFoAUReuir/SSy4IxLVGLp6chnfNt
# yA8wDgYDVR0PAQH/BAQDAgGGMHkGCCsGAQUFBwEBBG0wazAkBggrBgEFBQcwAYYY
# aHR0cDovL29jc3AuZGlnaWNlcnQuY29tMEMGCCsGAQUFBzAChjdodHRwOi8vY2Fj
# ZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRBc3N1cmVkSURSb290Q0EuY3J0MEUG
# A1UdHwQ+MDwwOqA4oDaGNGh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2Vy
# dEFzc3VyZWRJRFJvb3RDQS5jcmwwEQYDVR0gBAowCDAGBgRVHSAAMA0GCSqGSIb3
# DQEBDAUAA4IBAQBwoL9DXFXnOF+go3QbPbYW1/e/Vwe9mqyhhyzshV6pGrsi+Ica
# aVQi7aSId229GhT0E0p6Ly23OO/0/4C5+KH38nLeJLxSA8hO0Cre+i1Wz/n096ww
# epqLsl7Uz9FDRJtDIeuWcqFItJnLnU+nBgMTdydE1Od/6Fmo8L8vC6bp8jQ87PcD
# x4eo0kxAGTVGamlUsLihVo7spNU96LHc/RzY9HdaXFSMb++hUD38dglohJ9vytsg
# jTVgHAIDyyCwrFigDkBjxZgiwbJZ9VVrzyerbHbObyMt9H5xaiNrIv8SuFQtJ37Y
# OtnwtoeW/VvRXKwYw02fc7cBqZ9Xql4o4rmUMIIGtDCCBJygAwIBAgIQDcesVwX/
# IZkuQEMiDDpJhjANBgkqhkiG9w0BAQsFADBiMQswCQYDVQQGEwJVUzEVMBMGA1UE
# ChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMSEwHwYD
# VQQDExhEaWdpQ2VydCBUcnVzdGVkIFJvb3QgRzQwHhcNMjUwNTA3MDAwMDAwWhcN
# MzgwMTE0MjM1OTU5WjBpMQswCQYDVQQGEwJVUzEXMBUGA1UEChMORGlnaUNlcnQs
# IEluYy4xQTA/BgNVBAMTOERpZ2lDZXJ0IFRydXN0ZWQgRzQgVGltZVN0YW1waW5n
# IFJTQTQwOTYgU0hBMjU2IDIwMjUgQ0ExMIICIjANBgkqhkiG9w0BAQEFAAOCAg8A
# MIICCgKCAgEAtHgx0wqYQXK+PEbAHKx126NGaHS0URedTa2NDZS1mZaDLFTtQ2oR
# jzUXMmxCqvkbsDpz4aH+qbxeLho8I6jY3xL1IusLopuW2qftJYJaDNs1+JH7Z+Qd
# SKWM06qchUP+AbdJgMQB3h2DZ0Mal5kYp77jYMVQXSZH++0trj6Ao+xh/AS7sQRu
# QL37QXbDhAktVJMQbzIBHYJBYgzWIjk8eDrYhXDEpKk7RdoX0M980EpLtlrNyHw0
# Xm+nt5pnYJU3Gmq6bNMI1I7Gb5IBZK4ivbVCiZv7PNBYqHEpNVWC2ZQ8BbfnFRQV
# ESYOszFI2Wv82wnJRfN20VRS3hpLgIR4hjzL0hpoYGk81coWJ+KdPvMvaB0WkE/2
# qHxJ0ucS638ZxqU14lDnki7CcoKCz6eum5A19WZQHkqUJfdkDjHkccpL6uoG8pbF
# 0LJAQQZxst7VvwDDjAmSFTUms+wV/FbWBqi7fTJnjq3hj0XbQcd8hjj/q8d6ylgx
# CZSKi17yVp2NL+cnT6Toy+rN+nM8M7LnLqCrO2JP3oW//1sfuZDKiDEb1AQ8es9X
# r/u6bDTnYCTKIsDq1BtmXUqEG1NqzJKS4kOmxkYp2WyODi7vQTCBZtVFJfVZ3j7O
# gWmnhFr4yUozZtqgPrHRVHhGNKlYzyjlroPxul+bgIspzOwbtmsgY1MCAwEAAaOC
# AV0wggFZMBIGA1UdEwEB/wQIMAYBAf8CAQAwHQYDVR0OBBYEFO9vU0rp5AZ8esri
# kFb2L9RJ7MtOMB8GA1UdIwQYMBaAFOzX44LScV1kTN8uZz/nupiuHA9PMA4GA1Ud
# DwEB/wQEAwIBhjATBgNVHSUEDDAKBggrBgEFBQcDCDB3BggrBgEFBQcBAQRrMGkw
# JAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBBBggrBgEFBQcw
# AoY1aHR0cDovL2NhY2VydHMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZFJv
# b3RHNC5jcnQwQwYDVR0fBDwwOjA4oDagNIYyaHR0cDovL2NybDMuZGlnaWNlcnQu
# Y29tL0RpZ2lDZXJ0VHJ1c3RlZFJvb3RHNC5jcmwwIAYDVR0gBBkwFzAIBgZngQwB
# BAIwCwYJYIZIAYb9bAcBMA0GCSqGSIb3DQEBCwUAA4ICAQAXzvsWgBz+Bz0RdnEw
# vb4LyLU0pn/N0IfFiBowf0/Dm1wGc/Do7oVMY2mhXZXjDNJQa8j00DNqhCT3t+s8
# G0iP5kvN2n7Jd2E4/iEIUBO41P5F448rSYJ59Ib61eoalhnd6ywFLerycvZTAz40
# y8S4F3/a+Z1jEMK/DMm/axFSgoR8n6c3nuZB9BfBwAQYK9FHaoq2e26MHvVY9gCD
# A/JYsq7pGdogP8HRtrYfctSLANEBfHU16r3J05qX3kId+ZOczgj5kjatVB+NdADV
# ZKON/gnZruMvNYY2o1f4MXRJDMdTSlOLh0HCn2cQLwQCqjFbqrXuvTPSegOOzr4E
# Wj7PtspIHBldNE2K9i697cvaiIo2p61Ed2p8xMJb82Yosn0z4y25xUbI7GIN/TpV
# fHIqQ6Ku/qjTY6hc3hsXMrS+U0yy+GWqAXam4ToWd2UQ1KYT70kZjE4YtL8Pbzg0
# c1ugMZyZZd/BdHLiRu7hAWE6bTEm4XYRkA6Tl4KSFLFk43esaUeqGkH/wyW4N7Oi
# gizwJWeukcyIPbAvjSabnf7+Pu0VrFgoiovRDiyx3zEdmcif/sYQsfch28bZeUz2
# rtY/9TCA6TD8dC3JE3rYkrhLULy7Dc90G6e8BlqmyIjlgp2+VqsS9/wQD7yFylIz
# 0scmbKvFoW2jNrbM1pD2T7m3XDCCBu0wggTVoAMCAQICEAqA7xhLjfEFgtHEdqeV
# dGgwDQYJKoZIhvcNAQELBQAwaTELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDkRpZ2lD
# ZXJ0LCBJbmMuMUEwPwYDVQQDEzhEaWdpQ2VydCBUcnVzdGVkIEc0IFRpbWVTdGFt
# cGluZyBSU0E0MDk2IFNIQTI1NiAyMDI1IENBMTAeFw0yNTA2MDQwMDAwMDBaFw0z
# NjA5MDMyMzU5NTlaMGMxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwg
# SW5jLjE7MDkGA1UEAxMyRGlnaUNlcnQgU0hBMjU2IFJTQTQwOTYgVGltZXN0YW1w
# IFJlc3BvbmRlciAyMDI1IDEwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoIC
# AQDQRqwtEsae0OquYFazK1e6b1H/hnAKAd/KN8wZQjBjMqiZ3xTWcfsLwOvRxUwX
# cGx8AUjni6bz52fGTfr6PHRNv6T7zsf1Y/E3IU8kgNkeECqVQ+3bzWYesFtkepEr
# vUSbf+EIYLkrLKd6qJnuzK8Vcn0DvbDMemQFoxQ2Dsw4vEjoT1FpS54dNApZfKY6
# 1HAldytxNM89PZXUP/5wWWURK+IfxiOg8W9lKMqzdIo7VA1R0V3Zp3DjjANwqAf4
# lEkTlCDQ0/fKJLKLkzGBTpx6EYevvOi7XOc4zyh1uSqgr6UnbksIcFJqLbkIXIPb
# cNmA98Oskkkrvt6lPAw/p4oDSRZreiwB7x9ykrjS6GS3NR39iTTFS+ENTqW8m6TH
# uOmHHjQNC3zbJ6nJ6SXiLSvw4Smz8U07hqF+8CTXaETkVWz0dVVZw7knh1WZXOLH
# gDvundrAtuvz0D3T+dYaNcwafsVCGZKUhQPL1naFKBy1p6llN3QgshRta6Eq4B40
# h5avMcpi54wm0i2ePZD5pPIssoszQyF4//3DoK2O65Uck5Wggn8O2klETsJ7u8xE
# ehGifgJYi+6I03UuT1j7FnrqVrOzaQoVJOeeStPeldYRNMmSF3voIgMFtNGh86w3
# ISHNm0IaadCKCkUe2LnwJKa8TIlwCUNVwppwn4D3/Pt5pwIDAQABo4IBlTCCAZEw
# DAYDVR0TAQH/BAIwADAdBgNVHQ4EFgQU5Dv88jHt/f3X85FxYxlQQ89hjOgwHwYD
# VR0jBBgwFoAU729TSunkBnx6yuKQVvYv1Ensy04wDgYDVR0PAQH/BAQDAgeAMBYG
# A1UdJQEB/wQMMAoGCCsGAQUFBwMIMIGVBggrBgEFBQcBAQSBiDCBhTAkBggrBgEF
# BQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29tMF0GCCsGAQUFBzAChlFodHRw
# Oi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRUcnVzdGVkRzRUaW1lU3Rh
# bXBpbmdSU0E0MDk2U0hBMjU2MjAyNUNBMS5jcnQwXwYDVR0fBFgwVjBUoFKgUIZO
# aHR0cDovL2NybDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZEc0VGltZVN0
# YW1waW5nUlNBNDA5NlNIQTI1NjIwMjVDQTEuY3JsMCAGA1UdIAQZMBcwCAYGZ4EM
# AQQCMAsGCWCGSAGG/WwHATANBgkqhkiG9w0BAQsFAAOCAgEAZSqt8RwnBLmuYEHs
# 0QhEnmNAciH45PYiT9s1i6UKtW+FERp8FgXRGQ/YAavXzWjZhY+hIfP2JkQ38U+w
# tJPBVBajYfrbIYG+Dui4I4PCvHpQuPqFgqp1PzC/ZRX4pvP/ciZmUnthfAEP1HSh
# TrY+2DE5qjzvZs7JIIgt0GCFD9ktx0LxxtRQ7vllKluHWiKk6FxRPyUPxAAYH2Vy
# 1lNM4kzekd8oEARzFAWgeW3az2xejEWLNN4eKGxDJ8WDl/FQUSntbjZ80FU3i54t
# px5F/0Kr15zW/mJAxZMVBrTE2oi0fcI8VMbtoRAmaaslNXdCG1+lqvP4FbrQ6IwS
# BXkZagHLhFU9HCrG/syTRLLhAezu/3Lr00GrJzPQFnCEH1Y58678IgmfORBPC1JK
# kYaEt2OdDh4GmO0/5cHelAK2/gTlQJINqDr6JfwyYHXSd+V08X1JUPvB4ILfJdmL
# +66Gp3CSBXG6IwXMZUXBhtCyIaehr0XkBoDIGMUG1dUtwq1qmcwbdUfcSYCn+Own
# cVUXf53VJUNOaMWMts0VlRYxe5nK+At+DI96HAlXHAL5SlfYxJ7La54i71McVWRP
# 66bW+yERNpbJCjyCYG2j+bdpxo/1Cy4uPcU3AWVPGrbn5PhDBf3Froguzzhk++am
# i+r3Qrx5bIbY3TVzgiFI7Gq3zWcxggUHMIIFAwIBATA8MCgxJjAkBgNVBAMMHVN0
# YW5kYXJkIEFtYmllbnQgQ29kZSBTaWduaW5nAhBcEHalpSlthUda68sD5FZnMAkG
# BSsOAwIaBQCgeDAYBgorBgEEAYI3AgEMMQowCKACgAChAoAAMBkGCSqGSIb3DQEJ
# AzEMBgorBgEEAYI3AgEEMBwGCisGAQQBgjcCAQsxDjAMBgorBgEEAYI3AgEVMCMG
# CSqGSIb3DQEJBDEWBBSTNjrslJ97CLaTS/F3VCkU4dvwUzANBgkqhkiG9w0BAQEF
# AASCAQAl9QrQ1qh3y1lwmJ688iQpIY+j17bdZVvAZJCtyv+p3NioK2DZ/o6eON61
# +55ObEWYSt0ZQdfhDjMqrLjlSRwCOTc2iDit/IEnBfeSuIjeba2fUDwTpStcsc2P
# wyvtI9JaNrWw1ay3imYesOyv4w5q/hNFF37xWayP/uMl9MswZI+z+Bf6eqyTGBOu
# F1Qa3M86z6+99JN4IygFlOsifMFwNMiWXobbsiV5LuGCkFov/bx/v/x7ug0u+VrR
# Z2zh2BUySpnIcF1JOIEyoKPBnP3WudfuRRjHmRARHBUG09fGuar84T7G/i6T/p5R
# 9zPbv1LiKc4pnQfBT0YriblqdokxoYIDJjCCAyIGCSqGSIb3DQEJBjGCAxMwggMP
# AgEBMH0waTELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMUEw
# PwYDVQQDEzhEaWdpQ2VydCBUcnVzdGVkIEc0IFRpbWVTdGFtcGluZyBSU0E0MDk2
# IFNIQTI1NiAyMDI1IENBMQIQCoDvGEuN8QWC0cR2p5V0aDANBglghkgBZQMEAgEF
# AKBpMBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEwHAYJKoZIhvcNAQkFMQ8XDTI2
# MDUwMTExMTczNVowLwYJKoZIhvcNAQkEMSIEINnl0a5sEINcAmV7oHrsxONxWz06
# ci1UokUOhZiQvWRYMA0GCSqGSIb3DQEBAQUABIICAEaD1Y9SINZboD58T6r4GSzl
# gatDFIBhOBJj8gKZx2p6lVNh2QFpOrtCH+ax249o/NrsnCLynDiNyNCwdpKcYWk6
# djWeqhy+eDac/zYruWav6PoS/arDBi4NzsJdpRuiGg9lQ5dDXijpIsCji6YKOYA1
# dRkVGD2LnQqkJOgcmFLEhrDgGy08un8rjwLd0YdMkC5E4OhGzjGyqvCaxTCPmoO+
# GX4WzpVHYenIMjPyDgP/hfIOPo0pmJcTxYmOOrm/mDk76DNVlPvlfNe6Vo/s+rcH
# YbnYtGUhG4qLZ/fXByuDxEAF04MTFQ+zB+pq7qWhWaHWThrgSxGFDMzFxRG42wj/
# rstf2rAhhXSgLqVE841p/MJfzaO1397wah4WdPYcVsHUQy+10mr0i02wAlboNb0J
# PUAWKYVhbe/P/sIY7BM/wch4Tu/GkMjAG1YMXa7ULGdAxCGC1LH8p97IxeB2Uib/
# bE7P2otfiGT8AQzEfdi1ZzLVC52+wi0bLrudu3XvnVB1L7m3vhNsWRPAg2VKVh2s
# 3C2DKB24t5yYgKF1mFWLatDqVovla53ybFptAw2c532XimYaox7SegMaumXPuzf8
# Xr+rclx5T2IZ7JBl87Qaf+AlUJeAmG3xwFYF66k1KlTXgPr3fapgilWLPMUR3fno
# GcDYKdyislyRczW4z970
# SIG # End signature block
