# Build Release and Debug and run the test suites.
#
#   powershell -ExecutionPolicy Bypass -File TOOLS\build_and_test.ps1 [-Quick]
#
# Release: every ctest suite. Debug (run-time checks): the suites that
# exercise the newest code; -Quick skips Debug.
param([switch]$Quick)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$oneapi = 'C:\Program Files (x86)\Intel\oneAPI'
$env:PATH = "$oneapi\mkl\2025.0\bin;$oneapi\compiler\2025.0\bin;$env:PATH"
Set-Location $root

$configs = @('Release')
if (-not $Quick) { $configs += 'Debug' }
$failed = @()
foreach ($cfg in $configs) {
    Write-Host "=== build $cfg"
    cmake --build BUILD/WINDOWS_IFX --config $cfg | Select-String -Pattern 'error #|MUL2_V3 - ' | ForEach-Object { Write-Host $_.Line }
    if ($LASTEXITCODE -ne 0) { $failed += "build $cfg"; continue }
    Write-Host "=== tests $cfg"
    $args = @('--test-dir', 'BUILD/WINDOWS_IFX', '-C', $cfg, '--output-on-failure')
    if ($cfg -eq 'Debug') { $args += @('-R', 'BASE|NONLINEAR|CURVED|JOIN') }
    ctest @args | Select-Object -Last 6 | ForEach-Object { Write-Host $_ }
    if ($LASTEXITCODE -ne 0) { $failed += "tests $cfg" }
}
if ($failed.Count -gt 0) {
    Write-Host "FAILED: $($failed -join ', ')"
    exit 1
}
Write-Host 'ALL BUILDS AND TESTS PASSED'
