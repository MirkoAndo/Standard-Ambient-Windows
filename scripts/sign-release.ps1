# Requires -Version 5.1
param(
    [string]$PfxPath,
    [string]$PfxPassword,
    [string]$TimestampUrl = "http://timestamp.digicert.com",
    [string]$TargetPath = (Join-Path $PSScriptRoot ".."),
    [switch]$NoTimestamp
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] $Message"
}

function Get-CodeSigningCert {
    param([string]$Path, [string]$Password)

    if (-not (Test-Path $Path)) {
        throw "PFX non trovato: $Path"
    }

    if ([string]::IsNullOrWhiteSpace($Password)) {
        throw "PfxPassword mancante"
    }

    return New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($Path, $Password, "Exportable")
}

try {
    if (-not $PfxPath) {
        throw "PfxPath mancante"
    }

    $cert = Get-CodeSigningCert -Path $PfxPath -Password $PfxPassword
    if (-not $cert.HasPrivateKey) {
        throw "Il certificato non contiene una private key"
    }

    $eku = $cert.EnhancedKeyUsageList | ForEach-Object { $_.ObjectId }
    if ($eku -notcontains "1.3.6.1.5.5.7.3.3") {
        Write-Log "Attenzione: il certificato non sembra Code Signing"
    }

    if (-not (Test-Path $TargetPath)) {
        throw "TargetPath non valido: $TargetPath"
    }

    $files = Get-ChildItem -Path $TargetPath -Recurse -Filter *.ps1 -File | Where-Object {
        $_.FullName -notmatch "\\.git\\"
    }

    foreach ($file in $files) {
        if ($NoTimestamp) {
            $result = Set-AuthenticodeSignature -FilePath $file.FullName -Certificate $cert
        } else {
            $result = Set-AuthenticodeSignature -FilePath $file.FullName -Certificate $cert -TimestampServer $TimestampUrl
        }

        if ($result.Status -ne "Valid") {
            Write-Log "Firma fallita: $($file.FullName) -> $($result.Status)"
            throw "Firma non valida"
        } else {
            Write-Log "Firmato: $($file.FullName)"
        }
    }

    Write-Log "Firma completata"
} catch {
    Write-Error $_
    exit 1
}
