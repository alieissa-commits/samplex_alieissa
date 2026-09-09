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
BUILD_DIR="${BOARD_DIR}/build"
NUM_JOBS=4

CLEAN=0
REBUILD=0

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --clean) CLEAN=1 ;;
        --rebuild) REBUILD=1 ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

echo "=========================================="
echo "NXP MIMXRT1064-EVK - Build Script (POSIX)"
echo "=========================================="
echo "Board Dir: ${BOARD_DIR}"
echo "Build Dir: ${BUILD_DIR}"
echo ""

# Check for ARM GCC compiler
if ! command -v arm-none-eabi-gcc &> /dev/null && [ -z "${ARM_GCC_PATH}" ]; then
    echo "[WARNING] arm-none-eabi-gcc not found on PATH and ARM_GCC_PATH not set."
    echo ""
fi

if [ "${CLEAN}" -eq 1 ] || [ "${REBUILD}" -eq 1 ]; then
    echo "[INFO] Cleaning build directory..."
    rm -rf "${BUILD_DIR}"
    mkdir -p "${BUILD_DIR}"
    echo "[OK] Build directory cleaned"
    echo ""
fi

mkdir -p "${BUILD_DIR}"
cd "${BUILD_DIR}"

# Reconfigure if CMakeCache.txt or build.ninja is missing, or if forced
if [ ! -f "CMakeCache.txt" ] || [ ! -f "build.ninja" ] || [ "${REBUILD}" -eq 1 ]; then
    echo "[INFO] Configuring CMake..."
    cmake -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        ..
    echo "[OK] CMake configured"
    echo ""
fi

echo "[INFO] Building with ${NUM_JOBS} parallel jobs..."
if command -v ninja &> /dev/null; then
    ninja -j "${NUM_JOBS}"
else
    cmake --build . --parallel "${NUM_JOBS}" --config Release
fi

echo ""
echo "=========================================="
echo "[OK] Build completed successfully!"
echo "=========================================="
