#  Copyright (c) 2026 Eclipse ThreadX contributors
# 
#  This program and the accompanying materials are made available 
#  under the terms of the MIT license which is available at
#  https://opensource.org/license/mit.
# 
#  SPDX-License-Identifier: MIT
# 
#  Contributors: 
#     Ali Eissa - 2026 NXP i.MX RT1064 port.

param(
    [string]$Demo,
    [int]$TimeoutSeconds = 24,
    [Nullable[int]]$Seed = 12345
)

$BoardDir = Resolve-Path "$PSScriptRoot/.."
$BuildDir = Join-Path $BoardDir "build"

# Optional build if Demo parameter is supplied (incremental, no clean rebuild)
if ($Demo) {
    Write-Host "[INFO] Ensuring demo '$Demo' is active and built..."
    & "$PSScriptRoot/build.ps1" -Demo $Demo
    if ($LASTEXITCODE -ne 0) {
        Write-Error "[FAIL] Build failed for demo '$Demo'"
        exit 1
    }
}

# Determine active demo
if ($Demo) {
    $cachedDemo = $Demo
} else {
    $cachedDemo = "netx_trng_console"
    $cacheFile = Join-Path $BuildDir "CMakeCache.txt"
    if (Test-Path $cacheFile) {
        $match = Select-String -Path $cacheFile -Pattern "^ACTIVE_DEMO:STRING=(.*)$"
        if ($match) {
            $val = $match.Matches.Groups[1].Value.Trim()
            if ($val -and $val -ne "all") {
                $cachedDemo = $val
            }
        }
    }
}

$serverElfRel = "build/app/demos/$cachedDemo/mimxrt1064_threadx.elf"
$clientElfRel = "build/app/demos/$cachedDemo/mimxrt1064_client.elf"

if (-not (Test-Path (Join-Path $BoardDir $serverElfRel)) -and (Test-Path (Join-Path $BoardDir "build/mimxrt1064_threadx.elf"))) {
    $serverElfRel = "build/mimxrt1064_threadx.elf"
    $clientElfRel = "build/mimxrt1064_client.elf"
}

$ServerElf = Join-Path $BoardDir $serverElfRel
$ClientElf = Join-Path $BoardDir $clientElfRel

if (-not (Test-Path $ServerElf)) {
    Write-Error "[FAIL] Binary $ServerElf not found. Please build first using .\scripts\build.ps1 -Demo $cachedDemo"
    exit 1
}

# Configure test mode, script, and pass marker
if ($cachedDemo -eq "threadx_basic") {
    $RescRelPath = "renode/mimxrt1064-headless-single.resc"
    $TargetLog = Join-Path $BuildDir "server_uart.log"
    $SuccessMarker = "Executing periodic task"
    $TestDescription = "ThreadX Core Basic Demo (Task Scheduling & GPIO LED)"
} else {
    $RescRelPath = "renode/mimxrt1064-headless-multinode.resc"
    $TargetLog = Join-Path $BuildDir "client_uart.log"
    $SuccessMarker = "VERIFICATION SUCCESS"
    $TestDescription = "NetX Duo Multi-Node Networking Demo ($cachedDemo)"
}

# Find Renode executable
$RenodeExe = (Get-Command renode -ErrorAction SilentlyContinue).Source
if (-not $RenodeExe -and (Test-Path "C:\Program Files\Renode\renode.exe")) {
    $RenodeExe = "C:\Program Files\Renode\renode.exe"
}
if (-not $RenodeExe) {
    Write-Error "[FAIL] Renode was not found in PATH or at 'C:\Program Files\Renode\renode.exe'."
    exit 1
}

# Remove stale log files
Remove-Item (Join-Path $BuildDir "server_uart.log") -Force -ErrorAction SilentlyContinue
Remove-Item (Join-Path $BuildDir "client_uart.log") -Force -ErrorAction SilentlyContinue

Write-Host "=========================================="
Write-Host "Renode Headless CI Automated Test Runner"
Write-Host "=========================================="
Write-Host "Active Demo: $cachedDemo"
Write-Host "Test Suite:  $TestDescription"
Write-Host "Script:      $RescRelPath"
if ($null -ne $Seed) {
    Write-Host "Seed:        $Seed (Deterministic)"
}
Write-Host "Timeout:     ${TimeoutSeconds}s"
Write-Host "Log Target:  $TargetLog"
Write-Host ""
Write-Host "[INFO] Launching Renode in headless mode..."

# Build argument list for Renode: pass explicit binary paths, include script, sleep for duration, and quit
# Build argument list for Renode: pass clean relative paths, include script, sleep for duration, and quit
$initCmd = ""
if ($null -ne $Seed) {
    $initCmd += "emulation SetSeed $Seed; "
}
$initCmd += "`$bin = @`"$serverElfRel`"; `$bin_server = @`"$serverElfRel`"; "
if (Test-Path $ClientElf) {
    $initCmd += "`$bin_client = @`"$clientElfRel`"; "
}
$initCmd += "include @$RescRelPath; sleep $TimeoutSeconds; quit"

Push-Location $BoardDir

# Execute Renode directly with clean argument quoting
& $RenodeExe --plain --disable-xwt -e "$initCmd"

Pop-Location

# Verify success marker in target log
$pass = $false
if (Test-Path $TargetLog) {
    $content = Get-Content $TargetLog -Raw -ErrorAction SilentlyContinue
    if ($content -and $content.Contains($SuccessMarker)) {
        $pass = $true
    }
}

Write-Host ""
Write-Host "=========================================="
if ($pass) {
    Write-Host "[PASS] CI Automated Verification Succeeded!" -ForegroundColor Green
    if (Test-Path $TargetLog) {
        Write-Host ""
        Write-Host "Captured UART Output:"
        Get-Content $TargetLog | Select-Object -Last 20 | ForEach-Object { Write-Host "  $_" }
    }
    Write-Host "=========================================="
    exit 0
} else {
    Write-Host "[FAIL] CI Automated Verification Failed or Timed Out!" -ForegroundColor Red
    if (Test-Path $TargetLog) {
        Write-Host ""
        Write-Host "Captured Log Output:"
        Get-Content $TargetLog | ForEach-Object { Write-Host "  $_" }
    }
    Write-Host "=========================================="
    exit 1
}
