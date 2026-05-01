# Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

param(
    [ValidateSet("HighPerformance", "Balanced", "PowerSaver", "UltimatePerformance", "Custom")]
    [string]$Plan = "HighPerformance",
    [string]$PlanGuid
)

function Get-PowerSchemes {
    $output = & powercfg /L 2>$null
    $schemes = @{}
    foreach ($line in $output) {
        if ($line -match "Power Scheme GUID:\s+([a-fA-F0-9-]+)\s+\((.+)\)") {
            $schemes[$matches[2]] = $matches[1]
        }
    }
    return $schemes
}

try {
    $schemeGuid = $null

    switch ($Plan) {
        "HighPerformance" { $schemeGuid = "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c" }
        "Balanced" { $schemeGuid = "381b4222-f694-41f0-9685-ff5bb260df2e" }
        "PowerSaver" { $schemeGuid = "a1841308-3541-4fab-bc81-f71556f20b4a" }
        "UltimatePerformance" { $schemeGuid = "e9a42b02-d5df-448d-aa00-03f14749eb61" }
        "Custom" {
            if (-not $PlanGuid) {
                throw "PlanGuid richiesto per Plan=Custom"
            }
            $schemeGuid = $PlanGuid
        }
    }

    $schemes = Get-PowerSchemes
    if ($Plan -ne "Custom" -and -not ($schemes.Values -contains $schemeGuid)) {
        Write-Warning "Piano non trovato nel sistema: $Plan ($schemeGuid)."
    }

    & powercfg /S $schemeGuid
    if ($LASTEXITCODE -ne 0) {
        throw "Errore powercfg ($LASTEXITCODE)"
    }

    Write-Host "Power plan impostato: $Plan ($schemeGuid)"
} catch {
    Write-Error $_
    exit 1
}
