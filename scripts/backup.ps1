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

# SIG # Begin signature block
# MIIb+wYJKoZIhvcNAQcCoIIb7DCCG+gCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUHlJi8JqApYvQ2yW3RFhV+PEs
# mmWgghZeMIIDIDCCAgigAwIBAgIQXBB2paUpbYVHWuvLA+RWZzANBgkqhkiG9w0B
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
# CSqGSIb3DQEJBDEWBBRTkKERsZM1qshrnJAY6QsmxTJzITANBgkqhkiG9w0BAQEF
# AASCAQA2cQLyFC4MnTin5x2p7slHheERQ+IpfcwAPONsEoiYdAMFKXPKQGIuiV16
# 4Jf6a/7sflUVAJaUI1uFlK1VokhQ6wgK4uLA4lswsuqshNmlCkf07FxT7dyMsCdt
# 6IToqqvSTu0W+wYz0fOJMViUWFEI4PSvAAgOJs11zJrWg7OuEAoBzZJ3WA706NbI
# pJGfJlzBk9ooVxQ4Vhht+ZKLEYB8bgLU2sZ1DeAk4DGdxxKWHimemg7t7BOZ0OsC
# XDV7NLzjYB5pshRzIax8f76hKJ4uomca0cXubxAT2sEkEqYwLV1O4eVK8gKJ7t1O
# pX9cPU39PwxbkroHCTSuA9jxp/JFoYIDJjCCAyIGCSqGSIb3DQEJBjGCAxMwggMP
# AgEBMH0waTELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMUEw
# PwYDVQQDEzhEaWdpQ2VydCBUcnVzdGVkIEc0IFRpbWVTdGFtcGluZyBSU0E0MDk2
# IFNIQTI1NiAyMDI1IENBMQIQCoDvGEuN8QWC0cR2p5V0aDANBglghkgBZQMEAgEF
# AKBpMBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEwHAYJKoZIhvcNAQkFMQ8XDTI2
# MDUwMTExMTczMFowLwYJKoZIhvcNAQkEMSIEIAEUb+8KRpNJ4vzuWtzOD4v5aGqL
# KhciByS7pYL7Zgr5MA0GCSqGSIb3DQEBAQUABIICADRYvmSFA1KgRBEOCwAvpJLQ
# BUYyvmZjWyRIizOYXBTjdWztr6vrevCz4OcpT7IW/VDlsLZj5fxlP08VA3M3Wtfx
# STNWYje+KPg1uTp1W3s0TBFltlEeP8wlcS1hOzCtSefxjY37+zvcS4xS2x+TShow
# vyrcFRIIutqZBIjzMTL1e6Pauipl1s56OFhNaJ9bcfEx8unzXhCEoBuLvrUSJCiY
# JCpaC898SrAf0zYtbC1qzp7ueiiRFSBE85uM9fnXKJNSlBdwhqtUfX5Sx/zX0XOD
# gxrbOFez29KVZmy4nYzW6oSqcM/WZBDy9MWRgjuyk6hc90kq1nsWDN/NmB3tD26f
# QAFJ99XBNJLcxNi9WNXfbO6mz8stGbir+6kkPtr+d4IiChK1pgmLsAj6VYrx4aot
# 1sOOUP61aPoy1EaSfvdyeXaNpsOeK5PV4p2onOTZQB+odL79tdWPbcMdMQl1OaVQ
# s4AReVJsgylJFPjcNM1tgsUNHZ4fdKtjSL50W7e6PTJlA+fXVHgxqiiuHzFcXrTb
# YUPgnFbCxMY4qEBQiffapW/hb6xeCJQ/iVdMF0WipXGm5Rh2wZxSH0LpR9BYo1kF
# xEojluEJYIlP3/PWyEFJJLlCJRq2WF7xMmuh6b5gQynxwxCYcvpRsMiZmLOw5V7S
# LI/aOr+8hhJTHInnXDp4
# SIG # End signature block
