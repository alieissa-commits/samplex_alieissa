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

#ifndef BOARD_INIT_H
#define BOARD_INIT_H

#include "fsl_common.h"
#include "board.h"
#include "pin_mux.h"
#include "clock_config.h"

#ifdef __cplusplus
extern "C" {
#endif

void board_init(void);

#ifdef __cplusplus
}
#endif

#endif /* BOARD_INIT_H */
