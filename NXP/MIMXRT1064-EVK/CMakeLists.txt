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

cmake_minimum_required(VERSION 3.5 FATAL_ERROR)
set(CMAKE_C_STANDARD 99)

# Set the toolchain if not defined
if(NOT CMAKE_TOOLCHAIN_FILE)
    set(CMAKE_TOOLCHAIN_FILE "${CMAKE_CURRENT_LIST_DIR}/cmake/arm-gcc-cortex-m7.cmake")
endif()

list(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_LIST_DIR}/cmake)

include(utilities)

# Define the Project
project(mimxrt1064_threadx C CXX ASM)

# Define ThreadX User Configurations
set(TX_USER_FILE "${CMAKE_CURRENT_LIST_DIR}/lib/threadx/tx_user.h" CACHE STRING "Enable TX user configuration")
set(TX_USER_FILE_DIR "${CMAKE_CURRENT_LIST_DIR}/lib/threadx")

# Set up paths for MCUXpresso SDK
set(SDK_DIR "${CMAKE_CURRENT_LIST_DIR}/lib/mcux-sdk")
if(NOT EXISTS "${SDK_DIR}/devices/MIMXRT1064/MIMXRT1064.h")
    message(FATAL_ERROR "NXP SDK dependencies missing! Please run 'scripts/fetch_sdk.ps1' or 'scripts/fetch_sdk.sh' first.")
endif()

# Compile the NXP MCUXpresso Driver & Board Library as an Object Library
set(SDK_TARGET mcux_sdk)

add_library(${SDK_TARGET} OBJECT
    ${SDK_DIR}/devices/MIMXRT1064/system_MIMXRT1064.c
    ${SDK_DIR}/devices/MIMXRT1064/fsl_flexspi_nor_boot.c
    ${SDK_DIR}/drivers/fsl_clock.c
    ${SDK_DIR}/drivers/fsl_common.c
    ${SDK_DIR}/drivers/fsl_common_arm.c
    ${SDK_DIR}/drivers/fsl_gpio.c
    ${SDK_DIR}/drivers/fsl_lpuart.c
    ${SDK_DIR}/board/board.c
    ${SDK_DIR}/board/clock_config.c
    ${SDK_DIR}/board/pin_mux.c
    ${SDK_DIR}/board/dcd.c
    ${SDK_DIR}/board/evkmimxrt1064_flexspi_nor_config.c
    ${SDK_DIR}/utilities/fsl_debug_console.c
    ${SDK_DIR}/utilities/fsl_str.c
    ${SDK_DIR}/utilities/fsl_assert.c
    ${SDK_DIR}/components/uart/fsl_adapter_lpuart.c
)

target_compile_definitions(${SDK_TARGET}
    PUBLIC
        CPU_MIMXRT1064DVL6A
        XIP_EXTERNAL_FLASH=1
        XIP_BOOT_HEADER_ENABLE=1
        XIP_BOOT_HEADER_DCD_ENABLE=1
        FSL_SDK_DRIVER_QUICK_ACCESS_ENABLE=1
        SDK_DEBUGCONSOLE=1
        SKIP_SYSCLK_INIT=1
)

target_include_directories(${SDK_TARGET}
    PUBLIC
        ${SDK_DIR}/CMSIS/Include
        ${SDK_DIR}/devices/MIMXRT1064
        ${SDK_DIR}/drivers
        ${SDK_DIR}/board
        ${SDK_DIR}/utilities
        ${SDK_DIR}/components/uart
        ${CMAKE_CURRENT_LIST_DIR}/app
        ${TX_USER_FILE_DIR}
)

# Compile ThreadX Kernel from root shared libs submodule
set(THREADX_DIR "${CMAKE_CURRENT_LIST_DIR}/../../libs/threadx")
add_subdirectory(${THREADX_DIR} threadx)
