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
#     Ali Eissa - 2026 NXP i.MX RT1064 port.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOARD_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${BOARD_DIR}/build"

TIMEOUT_SECONDS=60
SEED="12345"
DEMO=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--demo)
            DEMO="$2"
            shift 2
            ;;
        -t|--timeout)
            TIMEOUT_SECONDS="$2"
            shift 2
            ;;
        -s|--seed)
            SEED="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done


CACHED_DEMO="netx_trng_console"
if [ -n "${DEMO}" ]; then
    CACHED_DEMO="${DEMO}"
elif [ -f "${BUILD_DIR}/CMakeCache.txt" ]; then
    VAL=$(grep -E "^ACTIVE_DEMO:STRING=" "${BUILD_DIR}/CMakeCache.txt" | cut -d'=' -f2 | tr -d ' \r\n')
    if [ -n "${VAL}" ] && [ "${VAL}" != "all" ]; then
        CACHED_DEMO="${VAL}"
    fi
fi

DEMO_DIR="${BUILD_DIR}/app/demos/${CACHED_DEMO}"
SERVER_ELF="${DEMO_DIR}/mimxrt1064_threadx.elf"
CLIENT_ELF="${DEMO_DIR}/mimxrt1064_client.elf"

if [ ! -f "${SERVER_ELF}" ] && [ -f "${BUILD_DIR}/mimxrt1064_threadx.elf" ]; then
    SERVER_ELF="${BUILD_DIR}/mimxrt1064_threadx.elf"
    CLIENT_ELF="${BUILD_DIR}/mimxrt1064_client.elf"
fi

if [ ! -f "${SERVER_ELF}" ]; then
    echo "[FAIL] Binary ${SERVER_ELF} not found. Please build first using ./scripts/build.sh -d ${CACHED_DEMO}"
    exit 1
fi

if [ "${CACHED_DEMO}" = "threadx_basic" ]; then
    RESC_REL_PATH="renode/mimxrt1064-headless-single.resc"
    TARGET_LOG="${BUILD_DIR}/server_uart.log"
    SUCCESS_MARKER="Executing periodic task"
    TEST_DESC="ThreadX Core Basic Demo (Task Scheduling & GPIO LED)"
else
    RESC_REL_PATH="renode/mimxrt1064-headless-multinode.resc"
    TARGET_LOG="${BUILD_DIR}/client_uart.log"
    SUCCESS_MARKER="VERIFICATION SUCCESS"
    TEST_DESC="NetX Duo Multi-Node Networking Demo (${CACHED_DEMO})"
fi

RENODE_CMD="renode"
if ! command -v renode &> /dev/null; then
    if [ -f "/opt/renode/renode" ]; then
        RENODE_CMD="/opt/renode/renode"
    else
        echo "[FAIL] Renode was not found in PATH."
        exit 1
    fi
fi

rm -f "${BUILD_DIR}/server_uart.log" "${BUILD_DIR}/client_uart.log"

echo "=========================================="
echo "Renode Headless CI Automated Test Runner"
echo "=========================================="
echo "Active Demo: ${CACHED_DEMO}"
echo "Test Suite:  ${TEST_DESC}"
echo "Script:      ${RESC_REL_PATH}"
if [ -n "${SEED}" ]; then
    echo "Seed:        ${SEED} (Deterministic)"
fi
echo "Timeout:     ${TIMEOUT_SECONDS}s"
echo "Log Target:  ${TARGET_LOG}"
echo ""
echo "[INFO] Launching Renode in headless mode..."

cd "${BOARD_DIR}"

SERVER_ELF_REL="build/app/demos/${CACHED_DEMO}/mimxrt1064_threadx.elf"
CLIENT_ELF_REL="build/app/demos/${CACHED_DEMO}/mimxrt1064_client.elf"
if [ ! -f "${BOARD_DIR}/${SERVER_ELF_REL}" ] && [ -f "${BUILD_DIR}/mimxrt1064_threadx.elf" ]; then
    SERVER_ELF_REL="build/mimxrt1064_threadx.elf"
    CLIENT_ELF_REL="build/mimxrt1064_client.elf"
fi

CI_RUNNER="${BUILD_DIR}/ci_runner.resc"
mkdir -p "${BUILD_DIR}"
rm -f "${CI_RUNNER}"

if [ -n "${SEED}" ]; then
    echo "emulation SetSeed ${SEED}" >> "${CI_RUNNER}"
fi
echo "\$bin = @${SERVER_ELF_REL}" >> "${CI_RUNNER}"
echo "\$bin_server = @${SERVER_ELF_REL}" >> "${CI_RUNNER}"
if [ -f "${BOARD_DIR}/${CLIENT_ELF_REL}" ]; then
    echo "\$bin_client = @${CLIENT_ELF_REL}" >> "${CI_RUNNER}"
fi
echo "include @${RESC_REL_PATH}" >> "${CI_RUNNER}"

TIMEOUT_CMD=()
if command -v timeout &> /dev/null; then
    TIMEOUT_CMD=(timeout "${TIMEOUT_SECONDS}s")
fi

"${TIMEOUT_CMD[@]}" "${RENODE_CMD}" --plain --disable-gui --port -1 -e "include @build/ci_runner.resc" < /dev/null || true

PASS=0
if [ -f "${TARGET_LOG}" ]; then
    if grep -q "${SUCCESS_MARKER}" "${TARGET_LOG}" 2>/dev/null; then
        PASS=1
    fi
fi

echo ""
echo "=========================================="
if [ ${PASS} -eq 1 ]; then
    echo "[PASS] CI Automated Verification Succeeded!"
    echo ""
    echo "Captured UART Output:"
    tail -n 20 "${TARGET_LOG}" 2>/dev/null || true
    echo "=========================================="
    exit 0
else
    echo "[FAIL] CI Automated Verification Failed or Timed Out!"
    if [ -f "${TARGET_LOG}" ]; then
        echo ""
        echo "Captured Log Output:"
        cat "${TARGET_LOG}"
    fi
    echo "=========================================="
    exit 1
fi

