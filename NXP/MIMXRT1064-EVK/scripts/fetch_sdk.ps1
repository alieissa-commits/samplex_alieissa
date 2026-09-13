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
$LibDir = Join-Path $BoardDir "lib/mcux-sdk"
$DeviceDir = Join-Path $LibDir "devices/MIMXRT1064"
$DriversDir = Join-Path $LibDir "drivers"
$UtilitiesDir = Join-Path $LibDir "utilities"
$ComponentsDir = Join-Path $LibDir "components"
$BoardFilesDir = Join-Path $LibDir "board"
$CmsisIncludeDest = Join-Path $LibDir "CMSIS/Include"
$TempDir = Join-Path $BoardDir "temp_fetch"

Write-Host "=========================================="
Write-Host "NXP i.MX RT1064 Standalone Driver Fetcher"
Write-Host "=========================================="
Write-Host "Target Directory: $LibDir"
Write-Host ""

# Clean and create target directories
if (Test-Path $LibDir) { Remove-Item -Path $LibDir -Recurse -Force }
New-Item -ItemType Directory -Path $DeviceDir -Force | Out-Null
New-Item -ItemType Directory -Path $DriversDir -Force | Out-Null
New-Item -ItemType Directory -Path $UtilitiesDir -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $ComponentsDir "uart") -Force | Out-Null
New-Item -ItemType Directory -Path $BoardFilesDir -Force | Out-Null
New-Item -ItemType Directory -Path $CmsisIncludeDest -Force | Out-Null
$AppStartupDir = Join-Path $BoardDir "app/startup"
New-Item -ItemType Directory -Path $AppStartupDir -Force | Out-Null

if (Test-Path $TempDir) { Remove-Item -Path $TempDir -Recurse -Force }
New-Item -ItemType Directory -Path $TempDir -Force | Out-Null

function Clean-Temp {
    if (Test-Path $TempDir) {
        Remove-Item -Path $TempDir -Recurse -Force
    }
}

try {
    # 1. Download official NXP MIMXRT1064 DFP pack from NXP repository
    $packUrl = "https://mcuxpresso.nxp.com/cmsis_pack/repo/NXP.MIMXRT1064_DFP.15.1.0.pack"
    $packZip = Join-Path $TempDir "dfp.zip"
    $packExtract = Join-Path $TempDir "dfp_extracted"

    Write-Host "[INFO] Downloading official NXP MIMXRT1064 Device Pack..."
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $packUrl -OutFile $packZip -UseBasicParsing

    Write-Host "[INFO] Extracting Device Pack..."
    Expand-Archive -Path $packZip -DestinationPath $packExtract -Force

    # Copy device register headers & system files
    $deviceFiles = @(
        "MIMXRT1064.h",
        "MIMXRT1064_features.h",
        "fsl_device_registers.h",
        "system_MIMXRT1064.c",
        "system_MIMXRT1064.h"
    )
    foreach ($file in $deviceFiles) {
        $source = Join-Path $packExtract $file
        if (Test-Path $source) {
            Copy-Item -Path $source -Destination $DeviceDir -Force
        }
    }

    # Copy core peripheral drivers
    $driverList = @(
        "fsl_clock.c", "fsl_clock.h",
        "fsl_common.c", "fsl_common.h",
        "fsl_common_arm.c", "fsl_common_arm.h",
        "fsl_gpio.c", "fsl_gpio.h",
        "fsl_lpuart.c", "fsl_lpuart.h",
        "fsl_enet.c", "fsl_enet.h",
        "fsl_iomuxc.h"
    )
    foreach ($file in $driverList) {
        $source = Join-Path $packExtract "drivers/$file"
        if (Test-Path $source) {
            Copy-Item -Path $source -Destination $DriversDir -Force
        }
    }

    # Copy utilities (debug console & string formatting)
    $utilFiles = @(
        "utilities/debug_console_lite/fsl_debug_console.h",
        "utilities/debug_console_lite/fsl_debug_console.c",
        "utilities/debug_console_lite/fsl_assert.c",
        "utilities/debug_console/fsl_debug_console_conf.h",
        "utilities/str/fsl_str.c",
        "utilities/str/fsl_str.h"
    )
    foreach ($file in $utilFiles) {
        $source = Join-Path $packExtract $file
        if (Test-Path $source) {
            Copy-Item -Path $source -Destination $UtilitiesDir -Force
        }
    }

    # Copy UART component adapter
    $compUartDest = Join-Path $ComponentsDir "uart"
    $compUartFiles = @(
        "components/uart/fsl_adapter_uart.h",
        "components/uart/fsl_adapter_lpuart.c"
    )
    foreach ($file in $compUartFiles) {
        $source = Join-Path $packExtract $file
        if (Test-Path $source) {
            Copy-Item -Path $source -Destination $compUartDest -Force
        }
    }

    # Copy XIP flexspi boot header from pack
    $xipSource = Join-Path $packExtract "xip"
    if (Test-Path $xipSource) {
        Copy-Item -Path "$xipSource/*" -Destination $DeviceDir -Recurse -Force
    }
    Write-Host "[OK] NXP Device, Driver, Utility, and Component files copied"
    Write-Host ""

    # Helper function to download with retries for GitHub CDN resilience
    function Download-WithRetry {
        param([string]$Uri, [string]$OutFile, [int]$MaxAttempts = 4)
        for ($i = 1; $i -le $MaxAttempts; $i++) {
            try {
                if (Get-Command curl.exe -ErrorAction SilentlyContinue) {
                    & curl.exe --retry 3 --retry-delay 2 -fsSL $Uri -o $OutFile
                    if ($LASTEXITCODE -eq 0 -and (Test-Path $OutFile) -and ((Get-Item $OutFile).Length -gt 0)) {
                        return
                    }
                }
                Invoke-WebRequest -Uri $Uri -OutFile $OutFile -UseBasicParsing -TimeoutSec 30
                return
            }
            catch {
                if ($i -eq $MaxAttempts) { throw $_ }
                Start-Sleep -Seconds 2
            }
        }
    }

    # 2. Download EVK-MIMXRT1064 Board Initialization Files from official NXP mcuxsdk-examples
    $rawBase = "https://raw.githubusercontent.com/nxp-mcuxpresso/mcuxsdk-examples/main/_boards/evkmimxrt1064"
    $boardFiles = @(
        @{ Remote = "$rawBase/board.c"; Local = "board.c" },
        @{ Remote = "$rawBase/board.h"; Local = "board.h" },
        @{ Remote = "$rawBase/project_template/clock_config.c"; Local = "clock_config.c" },
        @{ Remote = "$rawBase/project_template/clock_config.h"; Local = "clock_config.h" },
        @{ Remote = "$rawBase/project_template/pin_mux.c"; Local = "pin_mux.c" },
        @{ Remote = "$rawBase/project_template/pin_mux.h"; Local = "pin_mux.h" },
        @{ Remote = "$rawBase/dcd.c"; Local = "dcd.c" },
        @{ Remote = "$rawBase/dcd.h"; Local = "dcd.h" },
        @{ Remote = "$rawBase/xip/evkmimxrt1064_flexspi_nor_config.c"; Local = "evkmimxrt1064_flexspi_nor_config.c" },
        @{ Remote = "$rawBase/xip/evkmimxrt1064_flexspi_nor_config.h"; Local = "evkmimxrt1064_flexspi_nor_config.h" }
    )

    Write-Host "[INFO] Downloading EVK-MIMXRT1064 board support files..."
    foreach ($item in $boardFiles) {
        $dest = Join-Path $BoardFilesDir $item.Local
        Download-WithRetry -Uri $item.Remote -OutFile $dest
    }

    # Copy official GNU GCC Linker Script & Startup File from DFP pack into board directory
    Write-Host "[INFO] Copying official NXP GNU GCC Linker Script and Startup File into board directory..."
    $gccSource = Join-Path $packExtract "gcc"
    if (Test-Path $gccSource) {
        if (Test-Path "$gccSource/MIMXRT1064xxxxx_flexspi_nor.ld") {
            Copy-Item -Path "$gccSource/MIMXRT1064xxxxx_flexspi_nor.ld" -Destination $BoardFilesDir -Force
        }
        if (Test-Path "$gccSource/startup_MIMXRT1064.S") {
            Copy-Item -Path "$gccSource/startup_MIMXRT1064.S" -Destination $BoardFilesDir -Force
        }
    }
    Write-Host "[OK] Board support and official GCC reference files copied"
    Write-Host ""

    # 3. Fetch CMSIS Core headers (standard ARM CMSIS-Core include files)
    Write-Host "[INFO] Cloning CMSIS Core headers (depth=1)..."
    $cmsisCloneDir = Join-Path $TempDir "cmsis_core_repo"
    git clone --depth 1 https://github.com/STMicroelectronics/cmsis-core.git $cmsisCloneDir
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to clone CMSIS Core repository"
    }
    Copy-Item -Path "$cmsisCloneDir/CMSIS/Core/Include/*" -Destination $CmsisIncludeDest -Recurse -Force
    Write-Host "[OK] CMSIS Core headers copied"
    Write-Host ""

    # 4. Fetch official NXP KSZ8081 PHY driver (100% stock upstream)
    Write-Host "[INFO] Downloading official KSZ8081 PHY driver..."
    $phyRawBase = "https://raw.githubusercontent.com/eclipse-threadx/getting-started/master/NXP/MIMXRT1060-EVK/lib/MIMXRT1060-evk/src/components/phyksz8081"
    $phyDestDir = Join-Path $ComponentsDir "phy"
    New-Item -ItemType Directory -Path $phyDestDir -Force | Out-Null
    Download-WithRetry -Uri "$phyRawBase/fsl_phy.c" -OutFile (Join-Path $phyDestDir "fsl_phy.c")
    Download-WithRetry -Uri "$phyRawBase/fsl_phy.h" -OutFile (Join-Path $phyDestDir "fsl_phy.h")
    Write-Host "[OK] Stock KSZ8081 PHY driver downloaded"
    Write-Host ""

    # 5. Fetch official NetX Duo NXP Ethernet driver (100% stock upstream)
    Write-Host "[INFO] Downloading official NetX Duo NXP Ethernet driver..."
    $netxRawBase = "https://raw.githubusercontent.com/eclipse-threadx/getting-started/master/NXP/MIMXRT1060-EVK/lib/netx_driver"
    $netxDriverDestDir = Join-Path $DriversDir "netx_driver"
    $netxDriverGnuDir = Join-Path $netxDriverDestDir "gnu"
    New-Item -ItemType Directory -Path $netxDriverGnuDir -Force | Out-Null
    Download-WithRetry -Uri "$netxRawBase/src/nx_driver_imxrt1062.c" -OutFile (Join-Path $netxDriverDestDir "nx_driver_imxrt1062.c")
    Download-WithRetry -Uri "$netxRawBase/src/nx_driver_imxrt1062.h" -OutFile (Join-Path $netxDriverDestDir "nx_driver_imxrt1062.h")
    Download-WithRetry -Uri "$netxRawBase/src/gnu/nx_driver_imxrt1062_low_level.S" -OutFile (Join-Path $netxDriverGnuDir "nx_driver_imxrt1062_low_level.S")
    Write-Host "[OK] Stock NetX Duo NXP Ethernet driver downloaded"
    Write-Host ""

    Write-Host "=========================================="
    Write-Host "[SUCCESS] NXP i.MX RT1064 drivers successfully fetched!"
    Write-Host "=========================================="
}
finally {
    Clean-Temp
}
