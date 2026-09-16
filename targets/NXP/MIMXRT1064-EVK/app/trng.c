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

#define TRNG_TIMEOUT_CYCLES   1000000UL
#define TRNG_ENTROPY_WORDS    16

/* Recommended sampling and delay parameters according to NXP Reference Manual */
#define TRNG_SAMPLE_SIZE_DEF  2500U
#define TRNG_ENTROPY_DLY_DEF  3200U

/*
 * Static entropy pool buffer caching a full 512-bit hardware entropy block
 * (16 words * 32 bits = 512 bits) read from ENT[0..15].
 */
static uint32_t s_entropy_pool[TRNG_ENTROPY_WORDS];
static size_t s_pool_index = TRNG_ENTROPY_WORDS; /* Initially empty */

/* Interrupt lock helper for thread-safe access to entropy pool */
static inline uint32_t trng_lock(void)
{
    uint32_t primask = __get_PRIMASK();
    __disable_irq();
    return primask;
}

static inline void trng_unlock(uint32_t primask)
{
    __set_PRIMASK(primask);
}

int trng_init(void)
{
    uint32_t primask = trng_lock();

    /* 1. Enable TRNG peripheral clock in CCM */
    CLOCK_EnableClock(kCLOCK_Trng);

    /* 2. Enter Program Mode to allow programming control & delay registers */
    TRNG->MCTL |= TRNG_MCTL_PRGM_MASK;

    /* 3. Reset TRNG registers to hardware defaults (and clear ERR flag) */
    TRNG->MCTL |= TRNG_MCTL_RST_DEF_MASK;

    /* 4. Configure entropy sample size and delay parameters in SDCTL */
    TRNG->SDCTL = TRNG_SDCTL_ENT_DLY(TRNG_ENTROPY_DLY_DEF) |
                  TRNG_SDCTL_SAMP_SIZE(TRNG_SAMPLE_SIZE_DEF);

    /* 5. Set Von Neumann sampling mode (0b00) and un-divided oscillator (0b00) */
    TRNG->MCTL = (TRNG->MCTL & ~(TRNG_MCTL_SAMP_MODE_MASK | TRNG_MCTL_OSC_DIV_MASK)) |
                 TRNG_MCTL_SAMP_MODE(0) | TRNG_MCTL_OSC_DIV(0);

    /* 6. Exit Program Mode to enter Run Mode.
     *    In NXP hardware, transitioning PRGM from 1 to 0 actively initiates
     *    the entropy generation state machine.
     */
    TRNG->MCTL &= ~TRNG_MCTL_PRGM_MASK;

    /* Invalidate local entropy pool */
    s_pool_index = TRNG_ENTROPY_WORDS;

    trng_unlock(primask);

    return 0;
}

int trng_get_random_u32(uint32_t *random_val)
{
    uint32_t timeout;
    uint32_t primask;

    if (!random_val)
    {
        return -1;
    }

    primask = trng_lock();
    if (s_pool_index < TRNG_ENTROPY_WORDS)
    {
        *random_val = s_entropy_pool[s_pool_index++];
        trng_unlock(primask);
        return 0;
    }
    trng_unlock(primask);

    /* If hardware reports an error, recover via documented re-initialization */
    if (TRNG->MCTL & TRNG_MCTL_ERR_MASK)
    {
        trng_init();
    }

    /* Wait for Entropy Valid (ENT_VAL) bit */
    timeout = TRNG_TIMEOUT_CYCLES;
    while (!(TRNG->MCTL & TRNG_MCTL_ENT_VAL_MASK))
    {
        if (--timeout == 0)
        {
            return -2; /* Timeout waiting for entropy */
        }
    }

    primask = trng_lock();
    /* Double-check if another thread filled the pool while waiting */
    if (s_pool_index >= TRNG_ENTROPY_WORDS)
    {
        /*
         * Read all 16 entropy registers (ENT[0] through ENT[15]).
         * In NXP hardware, reading all 16 words (specifically reading ENT[15])
         * acknowledges the entropy block, clears MCTL[ENT_VAL], and automatically
         * kicks off generation of the next 512-bit entropy block.
         */
        for (size_t i = 0; i < TRNG_ENTROPY_WORDS; i++)
        {
            s_entropy_pool[i] = TRNG->ENT[i];
        }
        s_pool_index = 0;
    }

    *random_val = s_entropy_pool[s_pool_index++];
    trng_unlock(primask);

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
