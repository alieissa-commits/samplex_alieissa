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

#include "console.h"
#include "fsl_lpuart.h"
#include "board.h"

void console_init(void)
{
    lpuart_config_t config;

    LPUART_GetDefaultConfig(&config);
    config.baudRate_Bps = 115200U;
    config.enableTx     = true;
    config.enableRx     = true;

    uint32_t uartClkSrcFreq = BOARD_DebugConsoleSrcFreq();
    LPUART_Init(LPUART1, &config, uartClkSrcFreq);
}

void console_putc(char c)
{
    if (c == '\n')
    {
        while (!(LPUART_GetStatusFlags(LPUART1) & (uint32_t)kLPUART_TxDataRegEmptyFlag))
        {
        }
        LPUART_WriteByte(LPUART1, (uint8_t)'\r');
    }

    while (!(LPUART_GetStatusFlags(LPUART1) & (uint32_t)kLPUART_TxDataRegEmptyFlag))
    {
    }
    LPUART_WriteByte(LPUART1, (uint8_t)c);
}

void console_write(const char *str)
{
    while (*str != '\0')
    {
        console_putc(*str++);
    }
}

int __io_putchar(int ch)
{
    console_putc((char)ch);
    return ch;
}

int __io_getchar(void)
{
    while (!(LPUART_GetStatusFlags(LPUART1) & (uint32_t)kLPUART_RxDataRegFullFlag))
    {
    }
    return (int)LPUART_ReadByte(LPUART1);
}

int _write(int file, char *ptr, int len)
{
    (void)file;
    for (int i = 0; i < len; i++)
    {
        console_putc(ptr[i]);
    }
    return len;
}

int _read(int file, char *ptr, int len)
{
    (void)file;
    for (int i = 0; i < len; i++)
    {
        ptr[i] = (char)__io_getchar();
    }
    return len;
}
