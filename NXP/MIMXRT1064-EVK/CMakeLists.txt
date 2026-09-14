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

# Select demo to build: all (default), threadx_basic, netx_echo, netx_trng_console
set(ACTIVE_DEMO "all" CACHE STRING "Active demo name to build: all, netx_echo, netx_trng_console, threadx_basic")

# Set up paths for MCUXpresso SDK
set(SDK_DIR "${CMAKE_CURRENT_LIST_DIR}/lib/mcux-sdk")
if(NOT EXISTS "${SDK_DIR}/devices/MIMXRT1064/MIMXRT1064.h")
    message(FATAL_ERROR "NXP SDK dependencies missing! Please run 'scripts/fetch_sdk.ps1' or 'scripts/fetch_sdk.sh' first.")
endif()

# Dynamic Middleware Configuration
if(NOT ACTIVE_DEMO STREQUAL "all" AND EXISTS "${CMAKE_CURRENT_LIST_DIR}/app/demos/${ACTIVE_DEMO}/nx_user.h")
    set(NX_USER_FILE "${CMAKE_CURRENT_LIST_DIR}/app/demos/${ACTIVE_DEMO}/nx_user.h" CACHE STRING "Enable NetX Duo user configuration" FORCE)
else()
    set(NX_USER_FILE "${CMAKE_CURRENT_LIST_DIR}/lib/netxduo/nx_user.h" CACHE STRING "Enable NetX Duo user configuration" FORCE)
endif()

if(NOT ACTIVE_DEMO STREQUAL "all" AND EXISTS "${CMAKE_CURRENT_LIST_DIR}/app/demos/${ACTIVE_DEMO}/tx_user.h")
    set(TX_USER_FILE "${CMAKE_CURRENT_LIST_DIR}/app/demos/${ACTIVE_DEMO}/tx_user.h" CACHE STRING "Enable TX user configuration" FORCE)
    set(TX_USER_FILE_DIR "${CMAKE_CURRENT_LIST_DIR}/app/demos/${ACTIVE_DEMO}")
else()
    set(TX_USER_FILE "${CMAKE_CURRENT_LIST_DIR}/lib/threadx/tx_user.h" CACHE STRING "Enable TX user configuration" FORCE)
    set(TX_USER_FILE_DIR "${CMAKE_CURRENT_LIST_DIR}/lib/threadx")
endif()

# Compile ThreadX Kernel from root shared libs submodule
set(THREADX_DIR "${CMAKE_CURRENT_LIST_DIR}/../../libs/threadx")
add_subdirectory(${THREADX_DIR} threadx)

# Compile NetX Duo TCP/IP Stack from root shared libs submodule (cached for networking demos)
set(NXD_ENABLE_FILE_SERVERS OFF CACHE BOOL "Disable FileX dependency in NetX Duo" FORCE)
set(NETXDUO_DIR "${CMAKE_CURRENT_LIST_DIR}/../../libs/netxduo")
add_subdirectory(${NETXDUO_DIR} netxduo)

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

# 2. Define NetX Duo driver library targets (cached for networking demos)
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
            ${CMAKE_CURRENT_LIST_DIR}/lib/netxduo
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
            ${CMAKE_CURRENT_LIST_DIR}/lib/netxduo
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

# 3. Add demo subdirectories to build executable targets
if(ACTIVE_DEMO STREQUAL "all")
    add_subdirectory(app/demos/threadx_basic)
    add_subdirectory(app/demos/netx_echo)
    add_subdirectory(app/demos/netx_trng_console)
else()
    add_subdirectory(app/demos/${ACTIVE_DEMO})
endif()
