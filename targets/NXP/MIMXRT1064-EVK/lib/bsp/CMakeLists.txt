#  Copyright (c) 2026 Eclipse ThreadX contributors
# 
#  This program and the accompanying materials are made available 
#  under the terms of the MIT license which is available at
#  https://opensource.org/licenses/MIT.
# 
#  SPDX-License-Identifier: MIT

# Board Support Package implementation for NXP MIMXRT1064-EVK
add_library(mimxrt1064_bsp STATIC
    src/bsp_board.c
    src/bsp_led.c
    src/bsp_console.c
    src/bsp_memory.c
    src/bsp_selftest.c
)

target_compile_definitions(mimxrt1064_bsp
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

target_include_directories(mimxrt1064_bsp
    PUBLIC
        include
        ${SHARED_BSP_DIR}/include
        ${SDK_DIR}/CMSIS/Include
        ${SDK_DIR}/devices/MIMXRT1064
        ${SDK_DIR}/drivers
        ${SDK_DIR}/board
        ${SDK_DIR}/utilities
        ${SDK_DIR}/components/uart
        ${CMAKE_CURRENT_SOURCE_DIR}/../../app
        ${TX_USER_FILE_DIR}
)

target_link_libraries(mimxrt1064_bsp
    PUBLIC
        ${SDK_TARGET}
        threadx
)

# Board startup, low-level ThreadX initialization, syscalls, and hardware TRNG
add_library(board_bsp OBJECT
    ${CMAKE_CURRENT_SOURCE_DIR}/../../app/startup/startup_mimxrt1064.S
    ${CMAKE_CURRENT_SOURCE_DIR}/../../app/startup/tx_initialize_low_level.S
    ${CMAKE_CURRENT_SOURCE_DIR}/../../app/sysmem.c
    ${CMAKE_CURRENT_SOURCE_DIR}/../../app/syscalls.c
    ${CMAKE_CURRENT_SOURCE_DIR}/../../app/trng.c
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
        include
        ${SHARED_BSP_DIR}/include
        ${SDK_DIR}/CMSIS/Include
        ${SDK_DIR}/devices/MIMXRT1064
        ${SDK_DIR}/drivers
        ${SDK_DIR}/board
        ${SDK_DIR}/utilities
        ${SDK_DIR}/components/uart
        ${CMAKE_CURRENT_SOURCE_DIR}/../../app
        ${TX_USER_FILE_DIR}
)

target_link_libraries(board_bsp
    PUBLIC
        mimxrt1064_bsp
        ${SDK_TARGET}
        threadx
)
