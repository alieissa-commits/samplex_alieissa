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
 *    Ali Eissa - 2026 version.
 */

#include "trng.h"
#include "fsl_device_registers.h"
#include "fsl_clock.h"
#include <string.h>

#define TRNG_TIMEOUT_CYCLES  1000000UL

int trng_init(void)
{
    /* Enable TRNG peripheral clock in CCM */
    CLOCK_EnableClock(kCLOCK_Trng);

    /* Check if TRNG is reporting error, clear if needed */
    if (TRNG->MCTL & TRNG_MCTL_ERR_MASK)
    {
        /* Clear error by resetting to defaults */
        TRNG->MCTL |= TRNG_MCTL_RST_DEF_MASK;
    }

    return 0;
}

int trng_get_random_u32(uint32_t *random_val)
{
    uint32_t timeout = TRNG_TIMEOUT_CYCLES;

    if (!random_val)
    {
        return -1;
    }

    /* Wait for Entropy Valid (ENT_VAL) bit */
    while (!(TRNG->MCTL & TRNG_MCTL_ENT_VAL_MASK))
    {
        if (--timeout == 0)
        {
            return -2; /* Timeout waiting for entropy */
        }
    }

    /* Read a 32-bit random word from the first entropy register */
    *random_val = TRNG->ENT[0];

    return 0;
}

int trng_get_random_data(void *buffer, size_t length)
{
    uint8_t *out = (uint8_t *)buffer;
    size_t offset = 0;
    uint32_t rand_word;
    int status;

    if (!buffer)
    {
        return -1;
    }

    while (offset < length)
    {
        status = trng_get_random_u32(&rand_word);
        if (status != 0)
        {
            return status;
        }

        size_t chunk = length - offset;
        if (chunk > sizeof(uint32_t))
        {
            chunk = sizeof(uint32_t);
        }

        memcpy(out + offset, &rand_word, chunk);
        offset += chunk;
    }

    return (int)length;
}
