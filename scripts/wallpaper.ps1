# Requires -Version 5.1
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

# SIG # Begin signature block
# MIIb+wYJKoZIhvcNAQcCoIIb7DCCG+gCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUNR9nsdzMa2DDxwPq0GfXBf0V
# 9SmgghZeMIIDIDCCAgigAwIBAgIQXBB2paUpbYVHWuvLA+RWZzANBgkqhkiG9w0B
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
# CSqGSIb3DQEJBDEWBBSveUd9AD3xEqP2WO7QPq4hwR6cpzANBgkqhkiG9w0BAQEF
# AASCAQBXG4FAL25+cQ0L6sVQSoWCrNA6MOFF2a8MFlRDnnnoa510e/iWr6RH4wqA
# vT0JtEcJLgubU/k35Ijm3BVWt6FcSTCWHfAXEFJ3wIL6+qDjMyUILxS7a9h6BfIQ
# Xc6CoZXl+sDEA8Mqi8+qI/LEggviXVwgM34Yy6l0mLgJC/6uaW4YzdYu04Az28BQ
# UVoqDeKBA/qVmSfJa67b0rJZADDhFs95PxDr40jfuYR8YcT7Bh6g0REVZkhMJ1kU
# V81tlYJEY5WdRW7JTCvz398RSnzsFCcc8OHtk0+Cw6CvmpuryHHuPtx6jguEiPxh
# 4VJ+A5k0t+cWPU/M23v29POAgL3QoYIDJjCCAyIGCSqGSIb3DQEJBjGCAxMwggMP
# AgEBMH0waTELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMUEw
# PwYDVQQDEzhEaWdpQ2VydCBUcnVzdGVkIEc0IFRpbWVTdGFtcGluZyBSU0E0MDk2
# IFNIQTI1NiAyMDI1IENBMQIQCoDvGEuN8QWC0cR2p5V0aDANBglghkgBZQMEAgEF
# AKBpMBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEwHAYJKoZIhvcNAQkFMQ8XDTI2
# MDUwMTExMTczNFowLwYJKoZIhvcNAQkEMSIEICpOMxVUViQlizsOEVPoOFxB4eBc
# oEdriQkZIpKKdJwgMA0GCSqGSIb3DQEBAQUABIICAE3rjqSWQETBWe+m1e2AeYAz
# gDpdrdjeYqEX+WMckApKAhppADLdvofOY8QpH0R0h2oVO/mG9JJdFlZ+Osn3QVEY
# ECcioMjXEAFsMZfCnKEGrHvbYne13M4ztOGXkP/yjk5idEWOXPDEulovjqvgXYx7
# 33AzyoRYCVfzptjqer5dICnMCEckH2difwy7nC6Cf7j5QB/weRqNGZOdiYV01e9m
# tevxv60Ji4UTq9Xei+ru/G9U/8pkMVVLSQkZh3cJuxgc5BaLmw0VekZTLz5pklcu
# FGAIizoj9xsK8lBGkFkc4Ty77YETtXme0MmdmCR+qcghHnrWdpAD4iUc43uNLNGi
# EREIOIuPU9yFrNuunEo6o/2qU2syK90QLaVNbFg/cIDch4cjA0a1YF10Ru/H4Ivg
# CHKRvdqIvkWDY+OsSEF4wzrGmk3KTKGYxd06mDm625O8gDew3xVkEsglMDcFXLRa
# lBMKGq0ikZaeR5YK1nJgCj4UfKI5xPPnmkkHKJ5MMMbwwQzn5lDQuKYP4KV5+4a+
# HO6g1DQRB82EeCVDwXWh9eCR3sj7jlcIiOxWieOFv4ldq4oDJLx9I7NqMgRfurtP
# JZHdfy/r5xQECYflYguQ3gABeOQ/kDDWT3HmLR6cuq1HFtmEtYh49L5q6GXl/tQ/
# kEBhi2gM1Fyqn/OjL+IJ
# SIG # End signature block
