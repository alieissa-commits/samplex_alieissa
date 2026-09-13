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

cmake_minimum_required(VERSION 3.10 FATAL_ERROR)
set(CMAKE_C_STANDARD 99)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# Set the toolchain if not defined
if(NOT CMAKE_TOOLCHAIN_FILE)
    set(CMAKE_TOOLCHAIN_FILE "${CMAKE_CURRENT_LIST_DIR}/cmake/arm-gcc-cortex-m7.cmake")
endif()

list(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_LIST_DIR}/cmake)

include(utilities)

# Define the Project
project(mimxrt1064_threadx C CXX ASM)

# Ensure executable output (elf, bin, hex) goes directly to the top-level build directory
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}")

# Select the active demo to build (default: netx_echo, netx_trng_console, or threadx_basic)
set(ACTIVE_DEMO "netx_echo" CACHE STRING "Active demo name to build: netx_echo, netx_trng_console, threadx_basic")

# Set up paths for MCUXpresso SDK
set(SDK_DIR "${CMAKE_CURRENT_LIST_DIR}/lib/mcux-sdk")
if(NOT EXISTS "${SDK_DIR}/devices/MIMXRT1064/MIMXRT1064.h")
    message(FATAL_ERROR "NXP SDK dependencies missing! Please run 'scripts/fetch_sdk.ps1' or 'scripts/fetch_sdk.sh' first.")
endif()

# Dynamic Middleware Auto-Detection
# Check if the active demo uses NetX Duo by looking for nx_user.h
if(EXISTS "${CMAKE_CURRENT_LIST_DIR}/app/demos/${ACTIVE_DEMO}/nx_user.h")
    set(USE_NETXDUO ON)
    set(NX_USER_FILE "${CMAKE_CURRENT_LIST_DIR}/app/demos/${ACTIVE_DEMO}/nx_user.h" CACHE STRING "Enable NetX Duo user configuration" FORCE)
else()
    set(USE_NETXDUO OFF)
endif()

# Check if the active demo has custom tx_user.h; otherwise fallback to lib/threadx/tx_user.h
if(EXISTS "${CMAKE_CURRENT_LIST_DIR}/app/demos/${ACTIVE_DEMO}/tx_user.h")
    set(TX_USER_FILE "${CMAKE_CURRENT_LIST_DIR}/app/demos/${ACTIVE_DEMO}/tx_user.h" CACHE STRING "Enable TX user configuration" FORCE)
    set(TX_USER_FILE_DIR "${CMAKE_CURRENT_LIST_DIR}/app/demos/${ACTIVE_DEMO}")
else()
    set(TX_USER_FILE "${CMAKE_CURRENT_LIST_DIR}/lib/threadx/tx_user.h" CACHE STRING "Enable TX user configuration" FORCE)
    set(TX_USER_FILE_DIR "${CMAKE_CURRENT_LIST_DIR}/lib/threadx")
endif()

# Compile ThreadX Kernel from root shared libs submodule
set(THREADX_DIR "${CMAKE_CURRENT_LIST_DIR}/../../libs/threadx")
add_subdirectory(${THREADX_DIR} threadx)

if(USE_NETXDUO)
    # Compile NetX Duo TCP/IP Stack from root shared libs submodule
    set(NXD_ENABLE_FILE_SERVERS OFF CACHE BOOL "Disable FileX dependency in NetX Duo" FORCE)
    set(NETXDUO_DIR "${CMAKE_CURRENT_LIST_DIR}/../../libs/netxduo")
    add_subdirectory(${NETXDUO_DIR} netxduo)
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
        __STARTUP_INITIALIZE_NONCACHEDATA=1
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

# 1. Define Board BSP object library
add_library(board_bsp OBJECT
    app/startup/startup_mimxrt1064.S
    app/startup/tx_initialize_low_level.S
    app/board_init.c
    app/console.c
    app/trng.c
    app/sysmem.c
    app/syscalls.c
)

target_compile_definitions(board_bsp
    PUBLIC
        CPU_MIMXRT1064DVL6A
        XIP_EXTERNAL_FLASH=1
        XIP_BOOT_HEADER_ENABLE=1
        XIP_BOOT_HEADER_DCD_ENABLE=1
        FSL_SDK_DRIVER_QUICK_ACCESS_ENABLE=1
        SDK_DEBUGCONSOLE=1
        SKIP_SYSCLK_INIT=1
        __STARTUP_INITIALIZE_NONCACHEDATA=1
)

target_include_directories(board_bsp
    PUBLIC
        ${CMAKE_CURRENT_LIST_DIR}/app
        ${SDK_DIR}/CMSIS/Include
        ${SDK_DIR}/devices/MIMXRT1064
        ${SDK_DIR}/drivers
        ${SDK_DIR}/board
        ${SDK_DIR}/utilities
        ${SDK_DIR}/components/uart
        ${TX_USER_FILE_DIR}
)

target_link_libraries(board_bsp
    PUBLIC
        mcux_sdk
        threadx
)

# 2. Define conditional NetX Duo driver library target
if(USE_NETXDUO)
    add_library(netx_imxrt_driver OBJECT
        ${SDK_DIR}/drivers/netx_driver/nx_driver_imxrt1062.c
        ${SDK_DIR}/drivers/netx_driver/gnu/nx_driver_imxrt1062_low_level.S
        ${SDK_DIR}/components/phy/fsl_phy.c
        ${SDK_DIR}/drivers/fsl_enet.c
    )

    target_compile_definitions(netx_imxrt_driver
        PUBLIC
            CPU_MIMXRT1064DVL6A
            XIP_EXTERNAL_FLASH=1
            XIP_BOOT_HEADER_ENABLE=1
            XIP_BOOT_HEADER_DCD_ENABLE=1
            FSL_SDK_DRIVER_QUICK_ACCESS_ENABLE=1
            SDK_DEBUGCONSOLE=1
            SKIP_SYSCLK_INIT=1
            __STARTUP_INITIALIZE_NONCACHEDATA=1
    )

    target_include_directories(netx_imxrt_driver
        PUBLIC
            ${SDK_DIR}/drivers/netx_driver
            ${SDK_DIR}/components/phy
            ${CMAKE_CURRENT_LIST_DIR}/app
            ${CMAKE_CURRENT_LIST_DIR}/app/demos/${ACTIVE_DEMO}
            ${SDK_DIR}/CMSIS/Include
            ${SDK_DIR}/devices/MIMXRT1064
            ${SDK_DIR}/drivers
            ${SDK_DIR}/board
            ${SDK_DIR}/utilities
            ${SDK_DIR}/components/uart
            ${TX_USER_FILE_DIR}
    )

    target_link_libraries(netx_imxrt_driver
        PUBLIC
            netxduo
            threadx
            mcux_sdk
    )
    target_compile_options(netx_imxrt_driver PRIVATE -Wno-unused-variable)

    add_library(netx_imxrt_driver_client OBJECT
        ${SDK_DIR}/drivers/netx_driver/nx_driver_imxrt1062.c
        ${SDK_DIR}/drivers/netx_driver/gnu/nx_driver_imxrt1062_low_level.S
        ${SDK_DIR}/components/phy/fsl_phy.c
        ${SDK_DIR}/drivers/fsl_enet.c
    )

    target_compile_definitions(netx_imxrt_driver_client
        PUBLIC
            NETX_CLIENT_NODE=1
            CPU_MIMXRT1064DVL6A
            XIP_EXTERNAL_FLASH=1
            XIP_BOOT_HEADER_ENABLE=1
            XIP_BOOT_HEADER_DCD_ENABLE=1
            FSL_SDK_DRIVER_QUICK_ACCESS_ENABLE=1
            SDK_DEBUGCONSOLE=1
            SKIP_SYSCLK_INIT=1
            __STARTUP_INITIALIZE_NONCACHEDATA=1
    )

    target_include_directories(netx_imxrt_driver_client
        PUBLIC
            ${SDK_DIR}/drivers/netx_driver
            ${SDK_DIR}/components/phy
            ${CMAKE_CURRENT_LIST_DIR}/app
            ${CMAKE_CURRENT_LIST_DIR}/app/demos/${ACTIVE_DEMO}
            ${SDK_DIR}/CMSIS/Include
            ${SDK_DIR}/devices/MIMXRT1064
            ${SDK_DIR}/drivers
            ${SDK_DIR}/board
            ${SDK_DIR}/utilities
            ${SDK_DIR}/components/uart
            ${TX_USER_FILE_DIR}
    )

    target_link_libraries(netx_imxrt_driver_client
        PUBLIC
            netxduo
            threadx
            mcux_sdk
    )
    target_compile_options(netx_imxrt_driver_client PRIVATE -Wno-unused-variable)
endif()

# 3. Add the active demo subdirectory to build the executable target
add_subdirectory(app/demos/${ACTIVE_DEMO})
