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
SERVER_ELF="${BOARD_DIR}/build/mimxrt1064_threadx.elf"
CLIENT_ELF="${BOARD_DIR}/build/mimxrt1064_client.elf"

if [ ! -f "${SERVER_ELF}" ]; then
    echo "[ERROR] Binary ${SERVER_ELF} not found. Please build first using ./scripts/build.sh"
    exit 1
fi

if [ -n "$1" ]; then
    RESC_REL_PATH="$1"
    MODE="Custom Script"
elif [ -f "${CLIENT_ELF}" ]; then
    RESC_REL_PATH="renode/mimxrt1064-network-multinode.resc"
    MODE="Multi-Node Network Verification (Server: 192.168.0.100, Client: 192.168.0.101)"
else
    RESC_REL_PATH="renode/mimxrt1064-evk.resc"
    MODE="Single-Node Demo"
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
echo "Mode:       ${MODE}"
echo "Script:     ${BOARD_DIR}/${RESC_REL_PATH}"
echo "Server ELF: ${SERVER_ELF}"
if [ -f "${CLIENT_ELF}" ]; then
    echo "Client ELF: ${CLIENT_ELF}"
fi
echo ""

cd "${BOARD_DIR}"
"${RENODE_CMD}" -e "include @\"${RESC_REL_PATH}\""
