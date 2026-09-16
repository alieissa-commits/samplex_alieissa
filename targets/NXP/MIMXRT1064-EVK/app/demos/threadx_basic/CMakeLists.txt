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

set(DEMO_TARGET "demo_threadx_basic")
add_executable(${DEMO_TARGET}
    main.c
)
set_target_properties(${DEMO_TARGET} PROPERTIES OUTPUT_NAME "mimxrt1064_threadx")

# Set compile definitions for our executable
target_compile_definitions(${DEMO_TARGET}
    PRIVATE
        CPU_MIMXRT1064DVL6A
        XIP_EXTERNAL_FLASH=1
        XIP_BOOT_HEADER_ENABLE=1
        XIP_BOOT_HEADER_DCD_ENABLE=1
        FSL_SDK_DRIVER_QUICK_ACCESS_ENABLE=1
        SDK_DEBUGCONSOLE=1
        SKIP_SYSCLK_INIT=1
        __STARTUP_INITIALIZE_NONCACHEDATA=1
)

# Include paths for the executable target
target_include_directories(${DEMO_TARGET}
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}
        ${CMAKE_CURRENT_SOURCE_DIR}/../..
        ${SDK_DIR}/CMSIS/Include
        ${SDK_DIR}/devices/MIMXRT1064
        ${SDK_DIR}/drivers
        ${SDK_DIR}/board
        ${SDK_DIR}/utilities
        ${SDK_DIR}/components/uart
        ${TX_USER_FILE_DIR}
)

# Link libraries
target_link_libraries(${DEMO_TARGET}
    PRIVATE
        board_bsp
        threadx
        mcux_sdk
)

# Apply GCC linker script and print memory usage (utilities.cmake function)
set_target_linker(${DEMO_TARGET} "${CMAKE_CURRENT_SOURCE_DIR}/../../startup/MIMXRT1064xxxxx_flexspi_nor.ld")

# Post-build commands to generate raw .bin and .hex files
post_build(${DEMO_TARGET})
