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

# Server Executable Target (mimxrt1064_threadx)
add_executable(${PROJECT_NAME}
    main.c
)

# Set compile definitions for server
target_compile_definitions(${PROJECT_NAME}
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

# Include paths for server
target_include_directories(${PROJECT_NAME}
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}
        ${CMAKE_CURRENT_SOURCE_DIR}/../..
        ${SDK_DIR}/drivers/netx_driver
        ${SDK_DIR}/CMSIS/Include
        ${SDK_DIR}/devices/MIMXRT1064
        ${SDK_DIR}/drivers
        ${SDK_DIR}/board
        ${SDK_DIR}/utilities
        ${SDK_DIR}/components/uart
        ${SDK_DIR}/components/phy
        ${TX_USER_FILE_DIR}
)

# Link libraries for server
target_link_libraries(${PROJECT_NAME}
    PRIVATE
        board_bsp
        threadx
        netxduo
        netx_imxrt_driver
        mcux_sdk
)

# Apply GCC linker script and post-build outputs for server
set_target_linker(${PROJECT_NAME} "${CMAKE_CURRENT_SOURCE_DIR}/../../startup/MIMXRT1064xxxxx_flexspi_nor.ld")
post_build(${PROJECT_NAME})

# Automated Verification Client Executable Target (mimxrt1064_client)
set(CLIENT_TARGET "mimxrt1064_client")
add_executable(${CLIENT_TARGET}
    client_main.c
)

# Set compile definitions for client
target_compile_definitions(${CLIENT_TARGET}
    PRIVATE
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

# Include paths for client
target_include_directories(${CLIENT_TARGET}
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}
        ${CMAKE_CURRENT_SOURCE_DIR}/../..
        ${SDK_DIR}/drivers/netx_driver
        ${SDK_DIR}/CMSIS/Include
        ${SDK_DIR}/devices/MIMXRT1064
        ${SDK_DIR}/drivers
        ${SDK_DIR}/board
        ${SDK_DIR}/utilities
        ${SDK_DIR}/components/uart
        ${SDK_DIR}/components/phy
        ${TX_USER_FILE_DIR}
)

# Link libraries for client
target_link_libraries(${CLIENT_TARGET}
    PRIVATE
        board_bsp
        threadx
        netxduo
        netx_imxrt_driver_client
        mcux_sdk
)

# Apply GCC linker script and post-build outputs for client
set_target_linker(${CLIENT_TARGET} "${CMAKE_CURRENT_SOURCE_DIR}/../../startup/MIMXRT1064xxxxx_flexspi_nor.ld")
post_build(${CLIENT_TARGET})
