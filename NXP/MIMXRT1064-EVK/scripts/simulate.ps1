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
    [string]$Resc
)

$BoardDir = Resolve-Path "$PSScriptRoot/.."
$ServerElf = Join-Path $BoardDir "build/mimxrt1064_threadx.elf"
$ClientElf = Join-Path $BoardDir "build/mimxrt1064_client.elf"

if (-not (Test-Path $ServerElf)) {
    Write-Error "Binary $ServerElf not found. Please build the project first using .\scripts\build.ps1"
    exit 1
}

# Determine RESC script: custom argument, or auto-detect multi-node vs single-node
if ($Resc) {
    $RescRelPath = $Resc
    $Mode = "Custom Script"
} elseif (Test-Path $ClientElf) {
    $RescRelPath = "renode/mimxrt1064-network-multinode.resc"
    $Mode = "Multi-Node Network Verification (Server: 192.168.0.100, Client: 192.168.0.101)"
} else {
    $RescRelPath = "renode/mimxrt1064-evk.resc"
    $Mode = "Single-Node Demo"
}
$RescFullPath = Join-Path $BoardDir $RescRelPath

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
Write-Host "Mode:       $Mode"
Write-Host "Script:     $RescFullPath"
Write-Host "Server ELF: $ServerElf"
if (Test-Path $ClientElf) {
    Write-Host "Client ELF: $ClientElf"
}
Write-Host ""
Write-Host "Opening Renode Monitor and LPUART1 terminal analyzer(s)..."
Write-Host "To exit Renode, type 'quit' in the Renode Monitor or close the window."
Write-Host "=========================================="

Set-Location $BoardDir

# Pass relative script path with quotes to avoid tokenization errors when workspace contains spaces
& $RenodeExe -e "include @`"$RescRelPath`""
