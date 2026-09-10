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
ELF_PATH="${BOARD_DIR}/build/mimxrt1064_threadx.elf"
RESC_REL_PATH="renode/mimxrt1064-evk.resc"

if [ ! -f "${ELF_PATH}" ]; then
    echo "[ERROR] Binary ${ELF_PATH} not found. Please build first using ./scripts/build.sh"
    exit 1
fi

RENODE_CMD="renode"
if ! command -v renode &> /dev/null; then
    if [ -f "/opt/renode/renode" ]; then
        RENODE_CMD="/opt/renode/renode"
    else
        echo "[ERROR] Renode was not found in PATH."
        exit 1
    fi
fi

echo "=========================================="
echo "Starting Renode Simulation"
echo "=========================================="
echo "Script:     ${BOARD_DIR}/${RESC_REL_PATH}"
echo "Target ELF: ${ELF_PATH}"
echo ""

cd "${BOARD_DIR}"
"${RENODE_CMD}" -e "include @\"${RESC_REL_PATH}\""
