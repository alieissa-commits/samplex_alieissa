#  Copyright (c) 2026 Eclipse ThreadX contributors
# 
#  This program and the accompanying materials are made available 
#  under the terms of the MIT license which is available at
#  https://opensource.org/license/mit.
# 
#  SPDX-License-Identifier: MIT
# 
#  Contributors: 
#     Ali Eissa - 2026 version.

param(
    [switch]$Clean,
    [switch]$Rebuild,
    [string]$Demo = "netx_echo"
)

$BoardDir = Resolve-Path "$PSScriptRoot/.."
$BUILD_DIR = Join-Path $BoardDir "build"
$NUM_JOBS = 4

Write-Host "=========================================="
Write-Host "NXP MIMXRT1064-EVK - Build Script"
Write-Host "=========================================="
Write-Host "Board Dir:   $BoardDir"
Write-Host "Build Dir:   $BUILD_DIR"
Write-Host "Active Demo: $Demo"
Write-Host ""

# Check for ARM GCC compiler
$armGcc = Get-Command "arm-none-eabi-gcc" -ErrorAction SilentlyContinue
if (!$armGcc -and !$env:ARM_GCC_PATH) {
    Write-Host "[WARNING] arm-none-eabi-gcc not found on PATH and ARM_GCC_PATH not set." -ForegroundColor Yellow
    Write-Host ""
}

if ($Clean -or $Rebuild) {
    Write-Host "[INFO] Cleaning build directory..."
    if (Test-Path $BUILD_DIR) {
        Remove-Item -Path $BUILD_DIR -Recurse -Force
    }
    New-Item -ItemType Directory -Path $BUILD_DIR -Force | Out-Null
    Write-Host "[OK] Build directory cleaned"
    Write-Host ""
}

if (!(Test-Path $BUILD_DIR)) {
    New-Item -ItemType Directory -Path $BUILD_DIR -Force | Out-Null
}

Push-Location $BUILD_DIR

# Reconfigure if CMakeCache.txt or build.ninja is missing, or demo changed, or if forced
$needConfig = !(Test-Path "CMakeCache.txt") -or !(Test-Path "build.ninja") -or $Rebuild
if (!$needConfig -and (Test-Path "CMakeCache.txt")) {
    $cachedDemo = (Select-String -Path "CMakeCache.txt" -Pattern "^ACTIVE_DEMO:STRING=(.*)$" | ForEach-Object { $_.Matches.Groups[1].Value.Trim() })
    if ($cachedDemo -ne $Demo) {
        $needConfig = $true
    }
}

if ($needConfig) {
    Write-Host "[INFO] Configuring CMake for demo: $Demo..."
    cmake -G Ninja `
        "-DCMAKE_BUILD_TYPE=Release" `
        "-DACTIVE_DEMO=$Demo" `
        ..
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] CMake configuration failed!" -ForegroundColor Red
        Pop-Location
        exit 1
    }
    Write-Host "[OK] CMake configured"
    Write-Host ""
}

# Run build using Ninja
Write-Host "[INFO] Building target with Ninja ($NUM_JOBS parallel jobs)..."
ninja -j $NUM_JOBS
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Build failed!" -ForegroundColor Red
    Pop-Location
    exit 1
}

Write-Host ""
Write-Host "[SUCCESS] Build finished successfully!" -ForegroundColor Green
Write-Host "Server Firmware ELF: $(Join-Path $BUILD_DIR 'mimxrt1064_threadx.elf')"
Write-Host "Server Firmware BIN: $(Join-Path $BUILD_DIR 'mimxrt1064_threadx.bin')"
Write-Host "Server Firmware HEX: $(Join-Path $BUILD_DIR 'mimxrt1064_threadx.hex')"
if (Test-Path (Join-Path $BUILD_DIR 'mimxrt1064_client.elf')) {
    Write-Host "Client Firmware ELF: $(Join-Path $BUILD_DIR 'mimxrt1064_client.elf')"
    Write-Host "Client Firmware BIN: $(Join-Path $BUILD_DIR 'mimxrt1064_client.bin')"
    Write-Host "Client Firmware HEX: $(Join-Path $BUILD_DIR 'mimxrt1064_client.hex')"
}

Pop-Location
