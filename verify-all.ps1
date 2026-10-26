# verify-all.ps1 - DevOps Assignment Verification Script
$ErrorActionPreference = "Continue"

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " DevOps Laboratory Assignment - All 10 Exercises Audit " -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

$results = @()

1..10 | ForEach-Object {
    $num = "{0:D2}" -f $_
    $folderName = "exercise-$num"
    $folderPath = Join-Path $PSScriptRoot $folderName

    $dirExists = Test-Path $folderPath
    $readmeExists = Test-Path (Join-Path $folderPath "README.md")
    $evidenceDir = Join-Path $folderPath "evidence"
    $evidenceExists = Test-Path $evidenceDir
    $evidenceCount = if ($evidenceExists) { (Get-ChildItem -Path $evidenceDir -Filter "*.txt").Count } else { 0 }

    $status = if ($dirExists -and $readmeExists -and ($evidenceCount -gt 0)) { "PASS" } else { "FAIL" }

    $results += [PSCustomObject]@{
        Exercise = "EX-$num"
        Directory = $folderName
        README = if ($readmeExists) { "YES" } else { "NO" }
        EvidenceLogs = $evidenceCount
        Status = $status
    }
}

$results | Format-Table -AutoSize

$allPass = -not ($results | Where-Object { $_.Status -ne "PASS" })

if ($allPass) {
    Write-Host "`nAll 10 DevOps exercises verified successfully! Status: PASS" -ForegroundColor Green
} else {
    Write-Host "`nSome exercises require attention." -ForegroundColor Yellow
}
