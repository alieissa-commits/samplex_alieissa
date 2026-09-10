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
#include "fsl_iomuxc.h"
#include "fsl_gpio.h"

void board_init(void)
{
    /* 1. Configure the Memory Protection Unit if supported by hardware (16 regions on real Cortex-M7 silicon) */
    if (((MPU->TYPE & MPU_TYPE_DREGION_Msk) >> MPU_TYPE_DREGION_Pos) >= 12)
    {
        BOARD_ConfigMPU();
    }

    /* 2. Configure Pin Muxing (UART1 TX/RX pins) */
    BOARD_InitPins();

    /* 3. Configure User LED Pin Muxing (GPIO_AD_B0_09 -> GPIO1_IO09) */
    CLOCK_EnableClock(kCLOCK_Iomuxc);
    IOMUXC_SetPinMux(IOMUXC_GPIO_AD_B0_09_GPIO1_IO09, 0U);
    IOMUXC_SetPinConfig(IOMUXC_GPIO_AD_B0_09_GPIO1_IO09, 0x10B0u);

    /* 4. Configure System Clocks (600 MHz AHB core clock) */
    BOARD_BootClockRUN();

    /* 5. Initialize User LED GPIO (GPIO1 Pin 9, output, initial state OFF) */
    gpio_pin_config_t led_config = {
        kGPIO_DigitalOutput,
        0,
        kGPIO_NoIntmode
    };
    GPIO_PinInit(BOARD_USER_LED_GPIO, BOARD_USER_LED_GPIO_PIN, &led_config);
    USER_LED_OFF();

    /* 6. Initialize LPUART1 Serial Console at 115200 baud */
    console_init();
}
