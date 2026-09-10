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

#ifndef CONSOLE_H
#define CONSOLE_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

void console_init(void);
void console_putc(char c);
void console_write(const char *str);
int __io_putchar(int ch);
int __io_getchar(void);

#ifdef __cplusplus
}
#endif

#endif /* CONSOLE_H */
