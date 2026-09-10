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

$BoardDir = Resolve-Path "$PSScriptRoot/.."
$ElfPath = Join-Path $BoardDir "build/mimxrt1064_threadx.elf"
$RescRelPath = "renode/mimxrt1064-evk.resc"
$RescFullPath = Join-Path $BoardDir $RescRelPath

if (-not (Test-Path $ElfPath)) {
    Write-Error "Binary $ElfPath not found. Please build the project first using .\scripts\build.ps1"
    exit 1
}

# Find Renode executable
$RenodeExe = (Get-Command renode -ErrorAction SilentlyContinue).Source
if (-not $RenodeExe -and (Test-Path "C:\Program Files\Renode\renode.exe")) {
    $RenodeExe = "C:\Program Files\Renode\renode.exe"
}

if (-not $RenodeExe) {
    Write-Error "Renode was not found in PATH or at 'C:\Program Files\Renode\renode.exe'."
    exit 1
}

Write-Host "=========================================="
Write-Host "Starting Renode Simulation"
Write-Host "=========================================="
Write-Host "Renode:     $RenodeExe"
Write-Host "Script:     $RescFullPath"
Write-Host "Target ELF: $ElfPath"
Write-Host ""
Write-Host "Opening Renode Monitor and LPUART1 terminal analyzer..."
Write-Host "To exit Renode, type 'quit' in the Renode Monitor or close the window."
Write-Host "=========================================="

Set-Location $BoardDir

# Pass relative script path with quotes to avoid tokenization errors when workspace contains spaces
& $RenodeExe -e "include @`"$RescRelPath`""
