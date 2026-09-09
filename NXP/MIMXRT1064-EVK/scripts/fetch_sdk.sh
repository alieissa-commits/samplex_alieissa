#!/usr/bin/env bash
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

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOARD_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

LIB_DIR="${BOARD_DIR}/lib/mcux-sdk"
DEVICE_DIR="${LIB_DIR}/devices/MIMXRT1064"
DRIVERS_DIR="${LIB_DIR}/drivers"
UTILITIES_DIR="${LIB_DIR}/utilities"
COMPONENTS_DIR="${LIB_DIR}/components"
BOARD_FILES_DIR="${LIB_DIR}/board"
CMSIS_INCLUDE_DEST="${LIB_DIR}/CMSIS/Include"
TEMP_DIR="${BOARD_DIR}/temp_fetch"

echo "=========================================="
echo "NXP i.MX RT1064 Standalone Driver Fetcher (POSIX)"
echo "=========================================="
echo "Target Directory: ${LIB_DIR}"
echo ""

# Clean and recreate directories
rm -rf "${LIB_DIR}"
mkdir -p "${DEVICE_DIR}"
mkdir -p "${DRIVERS_DIR}"
mkdir -p "${UTILITIES_DIR}"
mkdir -p "${COMPONENTS_DIR}/uart"
mkdir -p "${BOARD_FILES_DIR}"
mkdir -p "${CMSIS_INCLUDE_DEST}"

rm -rf "${TEMP_DIR}"
mkdir -p "${TEMP_DIR}"

clean_temp() {
    if [ -d "${TEMP_DIR}" ]; then
        rm -rf "${TEMP_DIR}"
    fi
}
trap clean_temp EXIT

# 1. Download official NXP MIMXRT1064 DFP pack from NXP repository
PACK_URL="https://mcuxpresso.nxp.com/cmsis_pack/repo/NXP.MIMXRT1064_DFP.15.1.0.pack"
PACK_ZIP="${TEMP_DIR}/dfp.zip"
PACK_EXTRACT="${TEMP_DIR}/dfp_extracted"

echo "[INFO] Downloading official NXP MIMXRT1064 Device Pack..."
curl -fsSL "${PACK_URL}" -o "${PACK_ZIP}"

echo "[INFO] Extracting Device Pack..."
mkdir -p "${PACK_EXTRACT}"
unzip -q "${PACK_ZIP}" -d "${PACK_EXTRACT}"

# Copy device register headers & system files
for file in MIMXRT1064.h MIMXRT1064_features.h fsl_device_registers.h system_MIMXRT1064.c system_MIMXRT1064.h; do
    if [ -f "${PACK_EXTRACT}/${file}" ]; then
        cp "${PACK_EXTRACT}/${file}" "${DEVICE_DIR}/"
    fi
done

# Copy core peripheral drivers
for file in fsl_clock.c fsl_clock.h fsl_common.c fsl_common.h fsl_common_arm.c fsl_common_arm.h fsl_gpio.c fsl_gpio.h fsl_lpuart.c fsl_lpuart.h fsl_enet.c fsl_enet.h fsl_iomuxc.h; do
    if [ -f "${PACK_EXTRACT}/drivers/${file}" ]; then
        cp "${PACK_EXTRACT}/drivers/${file}" "${DRIVERS_DIR}/"
    fi
done

# Copy utilities (debug console & string formatting)
for file in utilities/debug_console_lite/fsl_debug_console.h utilities/debug_console_lite/fsl_debug_console.c utilities/debug_console_lite/fsl_assert.c utilities/debug_console/fsl_debug_console_conf.h utilities/str/fsl_str.c utilities/str/fsl_str.h; do
    if [ -f "${PACK_EXTRACT}/${file}" ]; then
        cp "${PACK_EXTRACT}/${file}" "${UTILITIES_DIR}/"
    fi
done

# Copy UART component adapter
for file in components/uart/fsl_adapter_uart.h components/uart/fsl_adapter_lpuart.c; do
    if [ -f "${PACK_EXTRACT}/${file}" ]; then
        cp "${PACK_EXTRACT}/${file}" "${COMPONENTS_DIR}/uart/"
    fi
done

# Copy XIP flexspi boot headers
if [ -d "${PACK_EXTRACT}/xip" ]; then
    cp -r "${PACK_EXTRACT}/xip/"* "${DEVICE_DIR}/"
fi
echo "[OK] NXP Device, Driver, Utility, and Component files copied"
echo ""

# 2. Download EVK-MIMXRT1064 Board Support Files from official NXP mcuxsdk-examples
RAW_BASE="https://raw.githubusercontent.com/nxp-mcuxpresso/mcuxsdk-examples/main/_boards/evkmimxrt1064"
echo "[INFO] Downloading EVK-MIMXRT1064 board support files..."

curl -fsSL "${RAW_BASE}/board.c" -o "${BOARD_FILES_DIR}/board.c"
curl -fsSL "${RAW_BASE}/board.h" -o "${BOARD_FILES_DIR}/board.h"
curl -fsSL "${RAW_BASE}/project_template/clock_config.c" -o "${BOARD_FILES_DIR}/clock_config.c"
curl -fsSL "${RAW_BASE}/project_template/clock_config.h" -o "${BOARD_FILES_DIR}/clock_config.h"
curl -fsSL "${RAW_BASE}/project_template/pin_mux.c" -o "${BOARD_FILES_DIR}/pin_mux.c"
curl -fsSL "${RAW_BASE}/project_template/pin_mux.h" -o "${BOARD_FILES_DIR}/pin_mux.h"
curl -fsSL "${RAW_BASE}/dcd.c" -o "${BOARD_FILES_DIR}/dcd.c"
curl -fsSL "${RAW_BASE}/dcd.h" -o "${BOARD_FILES_DIR}/dcd.h"
curl -fsSL "${RAW_BASE}/xip/evkmimxrt1064_flexspi_nor_config.c" -o "${BOARD_FILES_DIR}/evkmimxrt1064_flexspi_nor_config.c"
curl -fsSL "${RAW_BASE}/xip/evkmimxrt1064_flexspi_nor_config.h" -o "${BOARD_FILES_DIR}/evkmimxrt1064_flexspi_nor_config.h"
curl -fsSL "${RAW_BASE}/linker/mcux/MIMXRT1064xxxxx_flexspi_nor.ld" -o "${BOARD_FILES_DIR}/MIMXRT1064xxxxx_flexspi_nor.ld"

echo "[OK] Board support files downloaded"
echo ""

# 3. Fetch CMSIS Core headers
echo "[INFO] Cloning CMSIS Core headers (depth=1)..."
CMSIS_CLONE_DIR="${TEMP_DIR}/cmsis_core_repo"
git clone --depth 1 https://github.com/STMicroelectronics/cmsis-core.git "${CMSIS_CLONE_DIR}"
cp -r "${CMSIS_CLONE_DIR}/CMSIS/Core/Include/"* "${CMSIS_INCLUDE_DEST}/"
echo "[OK] CMSIS Core headers copied"
echo ""

echo "=========================================="
echo "[SUCCESS] NXP i.MX RT1064 drivers successfully fetched!"
echo "=========================================="
