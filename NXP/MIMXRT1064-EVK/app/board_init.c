/*
 * Copyright (c) 2026 Eclipse ThreadX contributors
 *
 * This program and the accompanying materials are made available 
 * under the terms of the MIT license which is available at
 * https://opensource.org/license/mit.
 *
 * SPDX-License-Identifier: MIT
 *
 * Contributors:
 *    Ali Eissa - 2026 NXP i.MX RT1064 port.
 */

#include "board_init.h"
#include "console.h"

void board_init(void)
{
    /* 1. Configure the Memory Protection Unit if supported by hardware (16 regions on real Cortex-M7 silicon) */
    if (((MPU->TYPE & MPU_TYPE_DREGION_Msk) >> MPU_TYPE_DREGION_Pos) >= 12)
    {
        BOARD_ConfigMPU();
    }

    /* 2. Configure Pin Muxing (UART1 TX/RX pins) */
    BOARD_InitPins();

    /* 3. Configure System Clocks (600 MHz AHB core clock) */
    BOARD_BootClockRUN();

    /* 4. Initialize LPUART1 Serial Console at 115200 baud */
    console_init();
}
